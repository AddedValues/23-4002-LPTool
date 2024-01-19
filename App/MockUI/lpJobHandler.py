import os
import sys
import logging
import shutil
import glob 
import datetime as dt
from datetime import datetime, timedelta
import numpy as np
import pandas as pd
import xlwings as xw
import gams 
import gams.transfer as gtr
from lpBase import LpBase
from jobLib import JobSpec, CoreData, StemData, ModelData, GamsData

class JobHandler():
    """
    JobHandler performs the runs of the LP optimization model.
    """

    version = "0.0.1"

    def __init__(self, scenId:str, description:str, pathWorkDir: str, modelText: str) -> None:
        self.logger = LpBase.getLogger()
        self.scenId = scenId
        self.description = description
        self.wkdir = pathWorkDir
        self.modelText = modelText

        self.ws = gams.GamsWorkspace(pathWorkDir)
        self.symbols = dict()  # Key is symbol name, value is scalar, dictionary or DataFrame

        return
    

    def __str__(self) -> str:   
        return f"{super().__str__()} {self.wkdir}"
    
    @staticmethod
    def time2int(time: datetime) -> int:
        """ Converts a datetime object to an integer of kind 't'nnnn. """
        return int(time.strftime('%Y%m%d%H'+'00'))

    @staticmethod
    def getFileName(scenId: str, fnameOrig: str, fext: str) -> str:
        """ Returns the file name of the result file for scenario scen. """
        return f'{fnameOrig}_{scenId}{fext}'


    def setupJob(self, jobSpec: JobSpec, rootDir) -> CoreData:
        """ Sets up the model prior to execution. """

        traceOps = False
        core = CoreData(jobSpec.scenId, rootDir, traceOps, self.logger) 

        # Copy model files to the working directory.
        core.copyInputFiles(copyAllFiles=True)
        core.openExcelInputFile(visible=False)

        # Set master parameters of the model. Use master scenario 2 (default).
        core.setDefaultParms(iMaster=2, onTimeAggr=0, activeExisting=0, activeNew=0, activeOV=0)
        for key, value in jobSpec.masterParms.items():
            core.setParmMaster(key, value)

        # Update the Excel book and save it.
        core.wb.app.calculation = 'automatic'
        core.wb.app.calculate()
        core.wb.save()
        core.wb.app.quit()

        return core
    

    def worker(self, core: CoreData) -> dict[str, float]:
        """
        Executes a GAMS job using folder workDir and copies the results to folder resultDir. 
        Returns a dictionary with the state of the execution (GAMS ModelState instance).
        """
        try:
            workDir = core.targetDir
            resultDir = os.path.join(core.resultDir, core.scenId)
            self.logger.debug(f'worker: {workDir=}, {resultDir=}')
            ws = gams.GamsWorkspace(workDir)
            opt = ws.add_options()

            # Specify an alternative GAMS license file (CPLEX)
            #--- opt.license = r'C:\GAMS\34\gamslice CPLEX 2019-12-17.txt'
            #--- opt.dformat = 2
            opt.solprint = 0
            opt.limrow = 0
            opt.limcol = 0
            opt.savepoint = 0
            opt.gdx  = core.outFiles['gdxout']    # Tell gams to produce a gdx file at end of run (equivalent to the gams command line option GDX=default)
            gamsJob = ws.add_job_from_file(core.inFiles['main.gms'])
            
            # Create file stream to receive output from GAMS Job
            self.logger.info(f'Running GAMS job for scenario {core.scenId} ...')
            fout = open(os.path.join(workDir, core.outFiles['log']), 'w') 
            gamsJob.run(opt, output=fout)                               #--- gams_job.run(opt, output=sys.stdout)
            self.logger.info(f'GAMS job for scenario {core.scenId} completed.')

            # Read job status from GAMS in-memory database.
            # masterIter = int(gamsJob.out_db.get_parameter("MasterIter").first_record().value)
            # iterOptim =  int(gamsJob.out_db.get_parameter("IterOptim").first_record().value)
            # self.logger.debug(f'{masterIter=}, {iterOptim=}')
            m = gtr.Container(gamsJob.out_db)
            statsSolver: gtr.syms.container_syms._parameter.Parameter = m.data['StatsSolver']
            # print(statsSolver.summary)
            dfRecs = statsSolver.records
            dictStatsSolver = dict(zip(dfRecs['topicSolver'], dfRecs['value']))
            # print(dictStatsSolver)
                        
            # Create resultDir if it does not exist.
            if not os.path.exists(resultDir):
                self.logger.debug(f'worker: Creating {resultDir=}')
                os.mkdir(resultDir)
            else:
                # Delete existing results files, if any.
                self.logger.debug(f'worker: Removing files from {resultDir=}')
                files = glob.glob(os.path.join(resultDir, '*.*'))
                for f in files:
                    os.remove(f)    

            # Copy some input and results files to new folder based on root folder resultDir. 
            self.logger.info(f'Copying files from {workDir=} to {resultDir=} ...')
            resultFiles = core.outFiles.values() 
            
            for file in resultFiles:
                self.logger.debug(f'Copying file={os.path.relpath(file)} to {os.path.relpath(resultDir)}')
                pathIn = os.path.join(workDir, file)
                if (os.path.exists(pathIn)):
                    fname, fext = os.path.splitext(file)
                    pathOut = os.path.join(resultDir, JobHandler.getFileName(core.scenId, fname, fext))
                    shutil.copy2(pathIn, pathOut)
                    
            # Remove temporary folders
            folders = glob.iglob(os.path.join(workDir, '225*')) 
            for folder in folders:
                shutil.rmtree(folder) 
            
        except Exception as ex:
            self.logger.critical(f'\nException occurred in {__name__}.worker on {core.scenId=}\n{ex=}\n', exc_info=True)
            raise
        finally:
            if fout is not None:
                fout.close()
            
        return dictStatsSolver

    def runJob(self):
        masterParms = dict()  # Key is parameter name, value is parameter value.
        defaultMasterParms = JobSpec.getDefaultMasterParms()

        # Construct an arbitrary start timestamp of the planning horizon and derive hourBegin from it as to fetch historical data.
        timestampStart = dt.datetime(2024,1,25,0,0,0)
        deltaTime = timestampStart - dt.datetime(2023, 12, 31, 23, 0, 0) 
        hourBegin = deltaTime.days * 24

        # Create the master parameter dictionary.
        masterParms = {
                'Scenarios.ScenarioID'            : self.scenId,
                'Scenarios.LenRollHorizonOverhang': 72,
                'Scenarios.CountRollHorizon'      : 1,
                # 'Scenarios.OnCapacityReservation' : 0,
                'Scenarios.HourBegin'             : hourBegin,
                'Scenarios.DurationPeriod'        : 48,
                'Scenarios.TimestampStart'        : timestampStart.timestamp(),  # POSIX ISO 8601 format to be reversed by datetime.fromtimestamp().
                'Scenarios.TimeResolutionDefault' : 60,
                'Scenarios.TimeResolutionBid'     : 60,
                'Scenarios.QfInfeasMax'           : 0,
                'Scenarios.OnRampConstraints'     : 0,
                'Scenarios.ElspotYear'            : 2019,
                'Scenarios.QdemandYear'           : 2019,
                'OnNetGlobalScen.netHo'           : 1,
                'OnNetGlobalScen.netSt'           : 1,
                'OnNetGlobalScen.netMa'           : 1,
                'OnUGlobalScen.MaVak'             : 1,
                'OnUGlobalScen.HoNVak'            : 0,
                'OnUGlobalScen.MaNVak'            : 1,
                'OnUGlobalScen.StVak'             : 1,
                'OnUGlobalScen.HoGk'              : 1,
                'OnUGlobalScen.HoOk'              : 1,
                'OnUGlobalScen.StGk'              : 1,
                'OnUGlobalScen.StOk'              : 1,
                'OnUGlobalScen.StEk'              : 1,
                'OnUGlobalScen.MaAff1'            : 1,
                'OnUGlobalScen.MaAff2'            : 0,
                'OnUGlobalScen.MaBio'             : 1,
                'OnUGlobalScen.MaCool'            : 1,
                'OnUGlobalScen.MaCool2'           : 1,
                'OnUGlobalScen.MaEk'              : 1,
                'OnUGlobalScen.HoNhpAir'          : 0,
                'OnUGlobalScen.HoNhpSew'          : 1,
                'OnUGlobalScen.HoNEk'             : 0,
                'OnUGlobalScen.HoNhpArla'         : 0,
                'OnUGlobalScen.HoNhpBirn'         : 1,
                'OnUGlobalScen.StNhpAir'          : 0,
                'OnUGlobalScen.StNFlis'           : 0,
                'OnUGlobalScen.StNEk'             : 0,
                'OnUGlobalScen.MaNEk'             : 0,
                'OnUGlobalScen.MaNbk'             : 0,
                'OnUGlobalScen.MaNbKV'            : 0,
                'OnUGlobalScen.MaNhpAir'          : 1,
                'OnUGlobalScen.MaNhpPtX'          : 0
            }

        jobSpec = JobSpec(self.scenId, 'desc', self.scenId, masterParms)

        core: CoreData = self.setupJob(jobSpec, LpBase.config['pathRoot'], self.logger)

        statsSolver = self.worker(core)

        if statsSolver['SolveStat'] == 1:
            self.logger.info(f'Optimization completed successfully.')    
        else:
            self.logger.error(f'Optimization failed with status SolveStat={statsSolver["SolveStat"]}.')
            sys.exit(1)

        return