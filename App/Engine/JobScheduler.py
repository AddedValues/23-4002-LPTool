import os
import sys
import glob
import shutil
import logging
from gams import GamsWorkspace

from App.AppBase.LpBase import Lpbase
from App.Engine.JobSpec import JobSpec


class JobScheduler(Lpbase):
    def __init__(self, logger: logging.Logger, numWorkers: int = 1):
        super().__init__(__name__, 'JobScheduler', '0.1')
        self.logger = self.getLogger()
        self.jobs = []

    def add_job(self, jobSpec: JobSpec):
        self.jobs.append(jobSpec)

    def run(self):
        for job in self.jobs:
            job.run()   # Run the job

    def getFileName(self, scenId: str, fnameOrig: str, fext: str) -> str:
        """ Returns the file name of the result file for scenario scen. """
        return f'{fnameOrig}_{scenId}{fext}'

    
    def worker(self, scenId, workDir, resultDir, fileName: str = 'MecLpMain'):
        """
        Process worker function
        Executes a GAMS job using folder workDir and copies the results to folder resultDir. 
        """
        try:
            # logger.debug(f'worker: {workDir=}, {resultDir=}')
            
            ws = GamsWorkspace(workDir)
            opt = ws.add_options()

            # Specify an alternative GAMS license file (CPLEX)
            #--- opt.license = r'C:\GAMS\34\gamslice CPLEX 2019-12-17.txt'
            #--- opt.dformat = 2
            opt.solprint = 0
            # opt.limrow = 25
            # opt.limcol = 10
            opt.savepoint = 0
            opt.gdx  = fileName + '.gdx'    # Tell gams to produce a gdx file at end of run (equivalent to the gams command line option GDX=default)
            gamsJob = ws.add_job_from_file(fileName + '.gms')
            
            # Create file stream to receive output from GAMS Job
            fout = open(os.path.join(workDir, fileName + '.log'), 'w')  
            gamsJob.run(opt, output=fout)                               #--- gams_job.run(opt, output=sys.stdout)

            # Read job status from GAMS in-memory database.
            masterIter = int(gamsJob.out_db.get_parameter("MasterIter").first_record().value)
            iterOptim =  int(gamsJob.out_db.get_parameter("IterOptim").first_record().value)
            self.getLogger.debug(f'{masterIter=}, {iterOptim=}')
                        
            # Create resultDir if it does not exist.
            if not os.path.exists(resultDir):
                self.getLogger.debug(f'worker: Creating {resultDir=}')
                os.mkdir(resultDir)
            else:
                # Delete existing results files.
                self.getLogger.debug(f'worker: Removing files from {resultDir=}')
                files = glob.glob(os.path.join(resultDir, '*.*'))
                for f in files:
                    os.remove(f)    

            # Copy results file to new folder: Input, MasterOutput, Listing, GDX, Log   
            self.getLogger.info(f'Copying files from {workDir=} to {resultDir=} ...')
            resultFiles = ['MECKapacInput.xlsb', 'MECMasterOutput.xlsm', '_gams_py_gjo0.lst', 'MECmain.log', 'MECmain.gdx', 'JobStats.gdx']
            
            for file in resultFiles:
                self.getLogger.debug(f'Copying file={os.path.relpath(file)} to {os.path.relpath(resultDir)}')
                pathIn = os.path.join(workDir, file)
                if (os.path.exists(pathIn)):
                    fname, fext = os.path.splitext(file)
                    pathOut = os.path.join(resultDir, self.getFileName(scenId, fname, fext))
                    shutil.copy2(pathIn, pathOut)
                    
            periodGdxResults = [f for f in glob.iglob(os.path.join(workDir, 'MEC_Results_iter*.gdx'))]   # Returns fully-qualified file name.
            fileFilter = [ f'MEC_Results_iter{iterOptim}', f'MEC_Results_iter{masterIter}']
            for file in periodGdxResults:
                if any(x in file for x in fileFilter):
                    self.getLogger.debug(f'Copying file={os.path.relpath(file)} to {os.path.relpath(resultDir)}')
                    pathIn = file
                    if (os.path.exists(pathIn)):
                        fnames = os.path.split(file)
                        fname, fext = os.path.splitext(fnames[-1])
                        pathOut = os.path.join(resultDir, self.getFileName(scenId, fname, fext))
                        shutil.move(pathIn, pathOut)

            # Remove all periodGdxResults files from workDir.
            for file in periodGdxResults:
                if os.path.exists(file):
                    os.remove(file)

            # Remove temporary folders
            folders = glob.iglob(os.path.join(workDir, '225*')) 
            for folder in folders:
                shutil.rmtree(folder) 
            
        except Exception as ex:
            self.getLogger.critical(f'\nException occurred in .worker on {scenId=}\n{ex=}\n', exc_info=True)
            raise
        finally:
            if fout is not None:
                fout.close()
            
        return

