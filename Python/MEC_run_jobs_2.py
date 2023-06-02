# -*- coding: utf-8 -*-
"""
Script that generates multiple gams jobs using multiprocessing
Used for project 23-1002 MEC FF version

"""

#%% Imports and functions.
import sys
import logging 
from random import random
from dataclasses import dataclass
from gams import GamsWorkspace
from multiprocessing import Process, active_children
import ssl
import smtplib
from email.message import EmailMessage
import glob, os, shutil
import time 
import datetime as dt
import pandas as pd
import xlwings as xw
import numpy as np
import msvcrt
import  MEClib as mec

ZERO : int = 0
ONE  : int = 1
NAME : str = 'MEC_run_jobs_2'

# Instantiate the logger 
global logger
logger = mec.init(NAME)


def readInput(caption, timeout = 5):
    start_time = time.time()
    logger.debug(caption)
    job = 0
    text = []
    while True:
        if msvcrt.kbhit():
            chr = msvcrt.getche()
            try:
                text.append(int(chr))
            except:
                text = text
                
        if (time.time() - start_time) > timeout:
            if len(text) > 0 and int(job) > 0:
                job = int(''.join(str(x) for x in text))
                ans = input(' - Terminate job (y/n)? ')
                if ans != 'y':
                    job = 0
            break
    return job

def send_email(receiver,subject,message):
    
    sender = 'OdinAvPy@gmail.com'
    msg = EmailMessage()
    msg.set_content(message)
    msg['Subject'] = subject
    msg['From'] = sender
    msg['To'] = receiver
    port = 465 # for SSL
    password = "gmjn grnx sazl cokc"
    context = ssl.create_default_context()
    
    try:
        server = smtplib.SMTP_SSL('smtp.gmail.com', port, context=context) #Set the mail server and port
        server.login(sender,password) #Login
        server.send_message(msg, from_addr=sender, to_addrs=receiver) #send the mail
        #--- logger.info("Successfully sent email")
        logger.info(f'Succesfully sent e-mail to {receiver}')
    except Exception as ex:
        logger.error("Error: unable to send email,\n{ex=}", exc_info=True)

    return                     
        

def worker(scen, workDir, resultDir):
    """process worker function"""
    
    try:
        #--- logger.debug(f'worker: {workDir=}\n        {resultDir=}')
        
        ws = GamsWorkspace( workDir )
        opt = ws.add_options()

        # Specify an alternative GAMS license file (CPLEX, Gurobi is the default on Odin)
        #--- opt.license = r'C:\GAMS\34\gamslice CPLEX 2019-12-17.txt'
        #--- opt.dformat = 2
        opt.solprint = 0
        # opt.limrow = 25
        # opt.limcol = 10
        opt.savepoint = 0
        opt.gdx  = "MECmain.gdx"    # Tell gams to produce a gdx file at end of run (equivalent to the gams command line option GDX=default)
        gams_job = ws.add_job_from_file("MECmain.gms")
        
        # Create file stream to receive output from GAMS Job
        fout = open(os.path.join(workDir, 'MECmain.log'), 'w')  #--- gams_job.run(opt, output=sys.stdout)
        gams_job.run(opt, output=fout)
                    
        # Copy results file to new folder
        resultFiles = ['MECKapacInput.xlsb', 'MECMasterOutput.xlsm', '_gams_py_gjo0.lst', 'MECmain.gdx', 'MECmain.log']
        
        for file in resultFiles:
            pathIn = os.path.join(workDir, file)
            if (os.path.exists(pathIn)):
                fname, fext = os.path.splitext(file)
                pathOut = os.path.join(resultDir, fname + '_' + scen + fext)
                shutil.copy2(pathIn, pathOut)
                
        periodGdxResults = [f for f in glob.iglob(os.path.join(workDir, 'MEC_Results_iter*.gdx'))] # Returns fully-qualified file name.
        for file in periodGdxResults:
            logger.info(f'Moving file={os.path.relpath(file)} to {os.path.relpath(resultDir)}')
            pathIn = file
            if (os.path.exists(pathIn)):
                fnames = os.path.split(file)
                fname, fext = os.path.splitext(fnames[-1])
                pathOut = os.path.join(resultDir, f'{fname}_{scen}{fext}')
                shutil.move(pathIn, pathOut)

        # Remove temporary folders
        folders = glob.iglob(os.path.join(workDir, '225*')) 
        for folder in folders:
            shutil.rmtree(folder) 
        
    except Exception as ex:
        logger.critical(f'\nException occurred in {NAME}.worker on {scen=}\n{ex=}\n', exc_info=True)
        raise
    finally:
        if fout is not None:
            fout.close()
        
    return
   
def getRootDir():
    """ Returns the root directory for running GAMS jobs. """
    rootDir = os.getcwd()
    if rootDir[-6:].lower() == 'python':
        rootDir = rootDir[:-6]
    return rootDir


class CoreData():
    """ This class handles operations on input files and in particular setting of parameters within the Excel input file. """

    def __init__(self, scenId: str, rootDir: str, ):
        self.scenId  = scenId
        self.rootDir = rootDir
        
        self.sourceDir = os.path.join(rootDir, 'INVOPT', 'Master')          # Path of master files (source, input data)
        self.workDir   = os.path.join(rootDir, 'INVOPT', 'WorkDir')         # Root folder of put new folders for each job    
        self.resultDir = os.path.join(rootDir, 'INVOPT', 'Results')         # Root folder to put results
        
        # Create new folder for each gams job.
        self.scenName = f'Scen_{self.scenId}'
        self.targetDir = os.path.join(self.workDir, scenName)

    def getScenIdAsNum(self, id: str):
        """ Converts textual scenario id 'MmmSssUssRrrFff' to integer """    
        numid =  int(id[1:3])
        for i in range(1, 5):
            numid = 100 * numid + int(id[3*i + 1 : 3*i + 3])
    
        return numid

    def copyInputFiles(self):
        logger.info(f'Copying input files to {self.targetDir} ...')
        if os.path.exists(self.targetDir):
            # Remove any file residing in folder targetDir.
            logger.info(f'Removing files from working directory: {self.targetDir}')
            allFiles = glob.glob(os.path.join(self.targetDir, '*.*'))
            try:
                for filePath in allFiles:
                    os.remove(filePath)
            except Exception as ex:
                logger.warning(f'Unable to remove file: {filePath}\n{ex=}', exc_info=True)
        else:
            logger.info(f'Creating working directory: {self.targetDir}')
            os.makedirs(self.targetDir)
    
        files = glob.iglob(os.path.join(self.sourceDir, '*.op*'))
        for file in files:
            if os.path.isfile(file):
                shutil.copy2(file, self.targetDir)
    
        files = glob.iglob(os.path.join(self.sourceDir, '*.gms'))
        for file in files:
            if os.path.isfile(file):
                shutil.copy2(file, self.targetDir)
    
        shutil.copy2(os.path.join(self.sourceDir, 'MEC.gpr'),                 self.targetDir)
        shutil.copy2(os.path.join(self.sourceDir, 'MECKapacInput.xlsb'),      self.targetDir)    
        shutil.copy2(os.path.join(self.sourceDir, 'GamsCmdlineOptions.txt'),  self.targetDir)
        shutil.copy2(os.path.join(self.sourceDir, 'options.inc'),             self.targetDir)        
        shutil.copy2(os.path.join(self.sourceDir, 'MECMasterOutput.xlsm'),    self.targetDir)          
        shutil.copy2(os.path.join(self.sourceDir, 'MECTidsAggregering.xlsx'), self.targetDir)        
        
        return
    
    def copyResultFiles(self, scen):
        # Copy results file to new folder
        #--- logger.info('Copying result files for {scen=} ...')
        resultFiles = ['MECKapacInput.xlsb', 'MECMasterOutput.xlsm', '_gams_py_gjo0.lst', 'MECmain.gdx']
        for file in resultFiles:
            pathIn = os.path.join(self.workDir, file)
            if (os.path.exists(pathIn)):
                fname, fext = os.path.splitext(file)
                pathOut = os.path.join(self.resultDir, fname + '_' + scen + fext)
                shutil.copy2(pathIn, pathOut)
    
        # Remove temporary folders
        folders = glob.iglob(os.path.join(self.workDir, '225*')) 
        for folder in folders:
            shutil.rmtree(folder) 
    
        return
    
    def openExcelInputFile(self):
        """ Opens input Excel file for modification."""
        # Input file resides in workDir.
        xlapp = xw.App(visible=False, add_book=False)
        self.wb = xlapp.books.open(os.path.join(self.targetDir, 'MECKapacInput.xlsb'))
        self.wb.app.calculation = 'manual'         # Saves quite some time !
        self.shMaster = self.wb.sheets['ScenMaster']   
        self.shPeriod = self.wb.sheets['ScenPeriod']   
        self.shYear   = self.wb.sheets['ScenYear']   
        self.iMasterOfz = 3                        # Column number before first master scenario.
        self.iPeriodOfz = 2                        # Column number before period scenario values.
        self.iYearOfz   = 5                        # Column number before period scenario values.

        # DO NOT use option expand='table' as empty cells will truncate the range covered by xlwings.
        logger.info(f'Reading scenarios from {self.wb.name} ...')
        self.dfM = self.shMaster.range('tblScenMasterAll').options(pd.DataFrame, header=True, index=False).value
        self.dfP = self.shPeriod.range('tblScenPeriodAll').options(pd.DataFrame, header=True, index=False).value
        self.dfY = self.shYear.range(  'tblScenYearAll'  ).options(pd.DataFrame, header=True, index=False).value
             
        # # Setting parameters common to all scenarios.
        # self.PeriodFirst   =  7  # 2025
        # self.PeriodLast    = 17  # 2035 
        # self.onTimeAggr    = -2  # Use -2 if OnDuplicate < 0.
        # self.onDuplicate   =  0  # Use -2 if OnDuplicate < 0.
        # self.lenRHOverhang = 10 if (self.onTimeAggr != 0) else 72  # Length of RH discarded after optimization of each RH.

        return self.wb

    def setParmMaster(self, fullName: str, newValue: float = None, newValues: list[float] = None, 
                      lookupCol: str = 'RecordKey', irowOfz: int = 9):
        """
        Sets the value of a master scenario parameter in Excel sheet ScenMaster by looking up the row in dataframe dfM.

        Parameters
        ----------
        sheet : Excel worksheet wrapper (xlwings)
            Sheet holding the range to be updated.
        fullName : str
            Fully qualified name of parameter as named in column lookupCol in dataframe df.
        icolBase1 : int
            Column number (base-1) in sheet.
        df : pd.DataFrame
            Dataframe holding the original values of the worksheet.
        newValue : float
            New value of the parameter (cell value).
        lookupCol : str, optional
            Name of the column in df to be used for looking up the fullName of the parameter. The default is 'RecordKey'.
        irowOfz : int, optional
            The offset for the Excel range on which df is mapped. The default is 9.
        Returns
        -------
        None.
        """

        mutualExcluding = (newValue is None) ^(newValues is None)
        if not mutualExcluding:
            raise ValueError('setParmMaster arguments newValue and newValues shall be mutually exclusive')

        try:
            df = self.dfM
            sheet = self.shMaster
            indx = df[df[lookupCol] == fullName].index
            if len(indx) == 0:
                raise ValueError(f'{fullName=} not found by setParmMaster.')
        
            irowBase1 = indx[0] + 1
            icolMas = self.iMasterOfz + self.iMaster
            cell = (irowOfz + irowBase1, icolMas)
            if newValues is None:
                logger.info(f'setParmMaster {fullName} to {newValue}') 
                sheet.range(cell).value = newValue
            else:
                logger.info(f'setParmMaster {fullName} to {newValues}') 
                sheet.range(cell).value = newValues
                
        except Exception as ex:
            logger.critical("Exception occurred in setParmMaster:\n{ex=}\n{sheet.name=}: Parm.{fullName=}, {icolBase1=}\n", exc_info=True)
            return ex
    
    def setParmPeriod(self, fullName: str, period: int, newValue: float = None, newValues: list[float] = None, 
                      lookupCol: str = 'RecordKey', irowOfz: int = 9):

        mutualExcluding = (newValue is None) ^(newValues is None)
        if not mutualExcluding:
            raise ValueError('setParmPeriod arguments newValue and newValues shall be mutually exclusive')

        try:
            df = self.dfP
            sheet = self.shPeriod
            irowBase1 = (df[df[lookupCol] == fullName].index)[0] + 1
            icolBase1= self.iPeriodOfz + period
            cell = (irowOfz + irowBase1, icolBase1)
            if newValues is None:
                logger.info(f'setParm {fullName} to {newValue}') 
                sheet.range(cell).value = newValue
            else:
                logger.info(f'setParm {fullName} to {newValues}') 
                sheet.range(cell).value = newValues
                
        except Exception as ex:
            logger.critical("Exception occurred in setParmPeriod:\n{ex=}\n{sheet.name=}: Parm.{fullName=}, {iColPeriod=}\n", exc_info=True)
            return ex

    def setParmYear(self, fullName: str, year: int, newValue: float = None, newValues: list[float] = None, 
                      lookupCol: str = 'RecordKey', irowOfz: int = 9):

        mutualExcluding = (newValue is None) ^(newValues is None)
        if not mutualExcluding:
            raise ValueError('setParm arguments newValue and newValues shall be mutually exclusive')

        try:
            df = self.dfY
            sheet = self.shYear
            irowBase1 = (df[df[lookupCol] == fullName].index)[0] + 1
            icolBase1 = self.iYearOfz + (year - 2019 + 1)
            cell = (irowOfz + irowBase1, icolBase1)
            if newValues is None:
                logger.info(f'setParmYear {fullName} to {newValue}') 
                sheet.range(cell).value = newValue
            else:
                logger.info(f'setParmYear {fullName} to {newValues}') 
                sheet.range(cell).value = newValues
                
        except Exception as ex:
            logger.critical("Exception occurred in setParmYear:\n{ex=}\n{sheet.name=}: Parm.{fullName=}, {iColYear=}\n", exc_info=True)
            return ex

    def setDefaultParms(self, iMaster: int, periodFirst: int, periodLast: int, onTimeAggr: int = +2, onDuplicate: int = 0, masterIterMax: int = 15, \
                        activeExisting: bool = True, activeNew: bool = False, activeOV: bool = False) -> None:
        """ Sets up default values of rarely changed parameters. """
        
        self.iMaster = iMaster
        self.PeriodFirst = periodFirst
        self.PeriodLast = periodLast
        self.onTimeAggr = onTimeAggr
        self.onDuplicate = onDuplicate
        self.masterIterMax = masterIterMax
        self.lenRHOverhang = 10 if (self.onTimeAggr != 0) else 72  # Length of RH discarded after optimization of each RH.


        self.shMaster.range('ActualMasterScen').value = self.iMaster      # Set master scenario.
        
        # Kørselsparametre
        self.setParmMaster('Scenarios.ScenarioID',              newValue = self.getScenIdAsNum(scenId))
        self.setParmMaster('Scenarios.PeriodFirst',             newValue = self.PeriodFirst)
        self.setParmMaster('Scenarios.PeriodLast',              newValue = self.PeriodLast)
        self.setParmMaster('Scenarios.DurationPeriod',          newValue = 8760)
        self.setParmMaster('Scenarios.LenRollHorizonOverhang',  newValue = self.lenRHOverhang)
        self.setParmMaster('Scenarios.OnDuplicatePeriods',      newValue = self.onDuplicate)
        self.setParmMaster('Scenarios.OnTimeAggr',              newValue = self.onTimeAggr)  #  -2 or +2
        self.setParmMaster('Scenarios.MasterIterMax',           newValue = self.masterIterMax)
        self.setParmMaster('Scenarios.AlfaVersion',             newValue = 5)
        
        # Eksisterende anlæg: Centrale anlæg er til rådighed som default.                         
        active = ONE if activeExisting else ZERO
        self.setParmMaster('OnUGlobalScen.MaAff1',              newValue = active)
        self.setParmMaster('OnUGlobalScen.MaAff2',              newValue = active)
        self.setParmMaster('OnUGlobalScen.MaBio',               newValue = active)
        
        # Nye anlægsmuligheder: Alle anlæg til rådighed som default
        active = ONE if activeNew else ZERO
        self.setParmMaster('OnUGlobalScen.HoNhpAir',            newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNhpSew',            newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNEk',               newValue = active)
        self.setParmMaster('OnUGlobalScen.StNEk',               newValue = active)
        self.setParmMaster('OnUGlobalScen.StNFlis',             newValue = active)
        self.setParmMaster('OnUGlobalScen.StNhpAir',            newValue = active)
        self.setParmMaster('OnUGlobalScen.StNhpSea',            newValue = active)
        self.setParmMaster('OnUGlobalScen.StNhpSew',            newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNAff',              newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNBk',               newValue = active)
        
        # Overskudsvarme: Alle OV-kilder til rådighed som default
        active = ONE if activeOV else ZERO
        self.setParmMaster('OnUGlobalScen.HoNhpArla',           newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNhpArla2',          newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNhpBirn',           newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNhpPtX',            newValue = active)
        
        # Periodeparametre
        pass
        
        # Årsparametre
        pass
        
        return
    
def reportProgress(startTime, scens: dict[str,str], printInterval, procs, core, jobsStarted, timer) -> float:  # Returns updated value of timer.
    """ Reports job progress on the logger. """
    linePrev    = ''
    linePrev2   = ''
    dElapsedSecs = time.perf_counter() - timer     # Time elapsed since last log update.
    if dElapsedSecs >= printInterval:
        elapsed = str(dt.timedelta(seconds=int(time.perf_counter() - startTime)))
        if '.' in elapsed:
            elapsed = elapsed[:elapsed.find('.')]   # Cut-off milliseconds.

        for ip in range(jobsStarted):
            scenId = procs[ip].name
            scenName = f'Scen_{scenId}'
            scenTitle = f'{mec.expandScenId(scenId)} [{scens[scenId]}]'
            procTitle = f'PID={procs[ip].pid}'

            if procs[ip].is_alive():
                try:
                    # logger.debug(f'Updating status for {procs[ip].pid} for {procs[ip].name}')
                    targetDir = os.path.join(core.workDir, scenName)
                    pathListingFile = os.path.join(targetDir, '_gams_py_gjo0.lst')
                    if not os.path.exists(pathListingFile):
                        # logger.debug(f'{pathListingFile=} was not found')
                        continue

                    linePrev = ""
                    for iline, line in enumerate(reversed(list(open(pathListingFile, 'r')))):
                        if (line[:5] == "LOOPS") and ("iter   iter" in line) and (iline >= 3):
                            actIter   = line[line.find("iter")             + 7 : line.find("iter")        + 7 + 7].replace('\n', '')
                            actPeriod = linePrev[linePrev.find("perL")     + 7 : linePrev.find("perL")    + 7 + 6].replace('\n', '')
                            actRHstep = linePrev2[linePrev2.find("rhStep") + 9 : linePrev2.find("rhStep") + 9 + 5].replace('\n', '')
                            if len(actPeriod.strip()) == 0:  
                                logger.info(f'Job {ip+1} - Status of {procTitle}: {scenTitle}: iter={actIter}, master-model, Elapsed= {elapsed}' )
                            else:
                                logger.info(f'Job {ip+1} - Status of {procTitle}: {scenTitle}: iter={actIter}, period={actPeriod}, RHstep={actRHstep}, Elapsed= {elapsed}' )
                            break
                        linePrev2 = linePrev
                        linePrev = line
                except FileNotFoundError:
                    logger.debug(f'Error opening {pathListingFile=}')
                    logger.info(f'{scenId} listing file [{pathListingFile}] not yet available.')
                    # logger.info(f'Job {i+1} - Status {scenTitle} : Starting ...')
                except Exception as ex:
                    logger.error(f'Exception caught: {ex=}', exc_info=True)
                    logger.debug(f'{line=}')
            else:
                logger.info(f'Job {ip+1} - Status of {procTitle}: {scenTitle}: Completed.') 

        timer = time.perf_counter()

    return timer                    

#%% Main procedure -----------------------------------------------------------------
   
if __name__ == '__main__':
    try:
        logger.info(f'Starting {NAME} ...')
        startTime = time.perf_counter()
        rootDir   = getRootDir()
        
        """ Scenario encoding:  mm-ss-uu-rr-ff
                mm: model version
                ss: main scenario id
                uu: sub-scenario id
                rr: roadmap id
                ff: sensitivity id
        """
        scens = { # Key is scenario-id, Value is short name.     Include letter T if a scenario is just for testing and set doTest = True.
                  'T11s99u10r00f00': 'TestScenarie',                  # Bruges til afprøvning af scripting.
                  
                #   'm11s01u00r00f00': 'Basis m/2 Aff m/20000 m3 VAK',  # Selvbærende forsyning uden OV, to aff-linjer, fra 2025, ny biokedel, MaNVak 20000 m3. Planperiode 2025 - 2031
                #   'm11s01u01r00f00': 'Basis m/2 Aff m/10000 m3 VAK',  # Selvbærende forsyning uden OV, to aff-linjer, fra 2025, ny biokedel, MaNVak 10000 m3. Planperiode 2025 - 2031
                #   'm11s01u02r00f00': 'Basis m/2 Aff u/ekstra VAK',    # Selvbærende forsyning uden OV, to aff-linjer, fra 2025, ny biokedel, MaNVak 0 m3. Planperiode 2025 - 2031

                #   'm11s02u10r00f00': 'Selvbærende forsyning: U/OV m/2 Affaldslinjer, kun ny biokedel',
                #   'm11s02u11r00f00': 'Selvbærende forsyning: U/OV m/1 Affaldslinje, kun ny biokedel',
                #   'm11s02u12r00f00': 'Selvbærende forsyning: U/OV m/0 Affaldslinjer, kun ny biokedel',

                #   'm11s02u20r00f00': 'Selvbærende forsyning: U/OV m/2 Affaldslinjer, alle nye anlæg',
                #   'm11s02u21r00f00': 'Selvbærende forsyning: U/OV m/1 Affaldslinje, alle nye anlæg',
                #   'm11s02u22r00f00': 'Selvbærende forsyning: U/OV m/0 Affaldslinjer, alle nye anlæg',

                #   'm11s02u10r00f01': 'Selvbærende forsyning: U/OV m/2 Affaldslinjer, Biomasse x 2',
                #   'm11s02u11r00f01': 'Selvbærende forsyning: U/OV m/1 Affaldslinje, Biomasse x 2',
                #   'm11s02u12r00f01': 'Selvbærende forsyning: U/OV m/0 Affaldslinjer, Biomasse x 2',

                #   'm11s02u20r00f01': 'Selvbærende forsyning: U/OV m/2 Affaldslinjer, Elpris x 2',
                #   'm11s02u21r00f01': 'Selvbærende forsyning: U/OV m/1 Affaldslinje, Elpris x 2',
                #   'm11s02u22r00f01': 'Selvbærende forsyning: U/OV m/0 Affaldslinjer, Elpris x 2',

                #   'm11s03u10r00f00': 'Overskudsvarme  forsyning: M/OV m/2 Affaldslinjer, kun ny biokedel',
                #   'm11s03u11r00f00': 'Overskudsvarme  forsyning: M/OV m/1 Affaldslinje, kun ny biokedel',
                #   'm11s03u12r00f00': 'Overskudsvarme  forsyning: M/OV m/0 Affaldslinjer, kun ny biokedel',

                #   'm11s03u20r00f00': 'Overskudsvarme  forsyning: M/OV m/2 Affaldslinjer, kun ny biokedel',
                #   'm11s03u21r00f00': 'Overskudsvarme  forsyning: M/OV m/1 Affaldslinje, kun ny biokedel',
                #   'm11s03u22r00f00': 'Overskudsvarme  forsyning: M/OV m/0 Affaldslinjer, kun ny biokedel'
                }
        
        scenList = list(scens.keys())    

        # Scenarios to run
        justCreateInputs = False        # If True, do only change the sheet values, else run GAMS jobs.
        doTest           = False        # If True, only run scenarios containing letter 'T'.
        nJob             = len(scens)   # Total number of jobs
        nJobParallel     =  2           # Number of jobs to run in parallel (available RAM and gurobi timelimit is the limiting factors)
        jobInterval      = 10           # time between check if new jobs should start
        printInterval    = 30           # seconds between status logging
        procs = []                      # List of processes to be spawned.
        
        if justCreateInputs:
            logger.warning('Validation mode - only creating input files')
        if doTest:
            logger.info(f'Test mode = {doTest}')

        
        for scenId in scenList: 
            scenName = f'Scen_{scenId}'
            # if (doTest) ^ ('T' in scenName):    # Skip scenarios if xor operation is true.
            #     logger.warning(f'Skipping {scenName=}')
            #     continue
                
            logger.info(f'Creating CoreData instance for {scenName} ...')
            core = CoreData(scenId, rootDir)
            core.copyInputFiles()
            wb = core.openExcelInputFile()

            logger.info(f'Modifying Excel input file for {scenName} ...')
            
            # Parameter setup is handled within each primary part of a scenId.
            # Thus a sensitivity or a roadmap can reuse the common setup associated with the scenario.
            
            if scenId.startswith('T'):  # Use this scenario for testing of script.
                core.setDefaultParms(iMaster=74, periodFirst=7, periodLast=13, onTimeAggr=+4, onDuplicate=0, masterIterMax=10, \
                                     activeExisting = True, activeNew = False, activeOV = False)
                # Kørselsparametre
                # Eksisterende anlæg
                # Nye anlægsmuligheder                                                 
                core.setParmMaster('OnUGlobalScen.MaNBk',  newValue = ONE)
                # Overskudsvarme
                # Periodeparametre
                # Årsparametre
                nper = core.PeriodLast - core.PeriodFirst + 1
                if 'u10' in scenId:
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues = [30.0 + round(20.0 * random(), 0) for i in range(nper)])
                elif 'u11' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues = [60.0 + round(20.0 * random(), 0) for i in range(nper)] )
                elif 'u12' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff1', newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues = [80.0 + round(20.0 * random(), 0) for i in range(nper)] )
                else:
                    raise ValueError(f'{scenId=} is not covered by code')

                # Sensitivities
                if scenId.endswith('f01'):
                    # Sensitivity against elspot price.
                    core.setParmMaster('Scenarios.MasterIterMax',     newValue=2)    # Driftsoptimering kun.
                    nper = core.PeriodLast - core.PeriodFirst + 1
                    core.setParmYear('SB22.ElspotGain', 2025, 2.0 * np.ones(nper))
            
            elif scenId.startswith('m11s01'):
                core.setDefaultParms(iMaster=74, periodFirst=7, periodLast=13, onTimeAggr=0, onDuplicate=0, masterIterMax=2, \
                                     activeExisting = True, activeNew = False, activeOV = False)
                # Kørselsparametre
                # Eksisterende anlæg
                # Nye anlægsmuligheder                                                 
                # Overskudsvarme
                # Periodeparametre
                # Årsparametre

                if 'u00' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaNVak1', newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.MaNVak2', newValue = ONE)
                elif 'u01' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaNVak1', newValue = ONE)
                    core.setParmMaster('OnUGlobalScen.MaNVak2', newValue = ZERO)
                elif 'u02' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaNVak1', newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.MaNVak2', newValue = ZERO)

                # Sensitivities
                if scenId.endswith('f01'):
                    # Sensitivity against elspot price.
                    core.setParmMaster('Scenarios.MasterIterMax',     newValue=2)    # Driftsoptimering kun.
                    nper = core.PeriodLast - core.PeriodFirst + 1
                    core.setParmYear('SB22.ElspotGain', 2025, 2.0 * np.ones(nper))

                
            elif scenId.startswith('m11s02u1'):    # Basis u/OV med N affaldslinjer og MaNbk
                core.setDefaultParms(iMaster=75, periodFirst=7, periodLast=17, onTimeAggr=+4, onDuplicate=0, masterIterMax=15, \
                                     activeExisting = True, activeNew = False, activeOV = False)
                # Kørselsparametre
                # Eksisterende anlæg
                # Nye anlægsmuligheder                                                 
                core.setParmMaster('OnUGlobalScen.MaNBk',  newValue = ONE)
                # Overskudsvarme
                # Periodeparametre
                # Årsparametre

                # Periodeparametre
                nper = core.PeriodLast - core.PeriodFirst + 1
                if 'u10' in scenId:
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues=[55, 55, 55, 55, 55, 55,   125, 125, 125, 125, 125] )
                elif 'u11' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues=[55, 55, 55, 55, 55, 55,   125, 125, 125, 125, 125] )
                elif 'u12' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff1', newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues=[55, 55, 55, 55, 55, 55,   125, 125, 125, 125, 125] )
                else:
                    raise ValueError(f'{scenId=} is not covered by code')
                
            elif scenId.startswith('m11s02u2'):     # Basis u/OV med N affaldslinjer og MaNbk og VP.
                core.setDefaultParms(iMaster=75, periodFirst=7, periodLast=17, onTimeAggr=+4, onDuplicate=0, masterIterMax=45, \
                                     activeExisting = True, activeNew = True, activeOV = False)
                # Kørselsparametre
                # Eksisterende anlæg
                # Nye anlægsmuligheder                                                 
                core.setParmMaster('OnUGlobalScen.StNhpSea', newValue = ZERO)
                core.setParmMaster('OnUGlobalScen.MaNAff',   newValue = ZERO)
                # Overskudsvarme
                # Periodeparametre
                #--- nper = core.PeriodLast - core.PeriodFirst + 1
                 #--- core.setParmPeriod('CapUMaxPer.MaNBk', period=core.PeriodFirst, newValues=25*np.ones(nper))
                
                if 'u20' in scenId:
                    pass
                elif 'u21' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                elif 'u22' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff1', newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                else:
                    raise ValueError(f'{scenId=} is not covered by code')

                
            elif scenId.startswith('m11s03u1'):    # Basis m/Arla2-OV med N affaldslinjer og MaNbk
                core.setDefaultParms(iMaster=75, periodFirst=7, periodLast=17, onTimeAggr=+4, onDuplicate=0, masterIterMax=15, \
                                     activeExisting = True, activeNew = False, activeOV = False)
                # Kørselsparametre
                # Eksisterende anlæg
                # Nye anlægsmuligheder                                                 
                core.setParmMaster('OnUGlobalScen.MaNBk',      newValue = ONE)
                # Overskudsvarme
                core.setParmMaster('OnUGlobalScen.HoNhpArla2', newValue = ONE)
                # Periodeparametre
                # Årsparametre

                # Periodeparametre underscenarier
                nper = core.PeriodLast - core.PeriodFirst + 1
                if 'u10' in scenId:
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues=[15, 15, 15, 15, 15, 15,   115, 115, 115, 115, 115] )
                elif 'u11' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues=[55, 55, 55, 55, 55, 55,   115, 115, 115, 115, 115] )
                elif 'u12' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff1', newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                    core.setParmPeriod('CapUInitPer.MaNBk', period=core.PeriodFirst, newValues=[85, 85, 85, 85, 85, 85,   115, 115, 115, 115, 115] )
                else:
                    raise ValueError(f'{scenId=} is not covered by code')
                
            elif scenId.startswith('m11s03u2'):     # Basis m/Arla2-OV med N affaldslinjer og MaNbk og VP.
                core.setDefaultParms(iMaster=75, periodFirst=7, periodLast=17, onTimeAggr=+4, onDuplicate=0, masterIterMax=15, \
                                     activeExisting = True, activeNew = True, activeOV = False)
                # Kørselsparametre
                # Eksisterende anlæg
                # Nye anlægsmuligheder                                                 
                core.setParmMaster('OnUGlobalScen.StNhpSea',   newValue = ZERO)
                core.setParmMaster('OnUGlobalScen.MaNAff',     newValue = ZERO)
                # Overskudsvarme
                core.setParmMaster('OnUGlobalScen.HoNhpArla2', newValue = ONE)
                # Periodeparametre
                #--- nper = core.PeriodLast - core.PeriodFirst + 1
                 #--- core.setParmPeriod('CapUMaxPer.MaNBk', period=core.PeriodFirst, newValues=25*np.ones(nper))
                
                if 'u20' in scenId:
                    pass
                elif 'u21' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                elif 'u22' in scenId:
                    core.setParmMaster('OnUGlobalScen.MaAff1', newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                else:
                    raise ValueError(f'{scenId=} is not covered by code')

            else:
                raise ValueError(f'No initialization code for {scenId}')

            wb.app.calculation = 'automatic'
            wb.app.calculate()
            wb.save()
            wb.app.quit()
            
            # Prepare jobs (worker functions)
            # if not justCreateInputs:
            logger.info(f'Spawning process for {scenName} job ...')
            procs.append(Process(name=scenId, target=worker, args=(core.scenName, core.targetDir, core.resultDir)))
                
        # End of ... for scenId in scenList
            
        if justCreateInputs:
            for ip, proc in enumerate(procs):
                logger.debug(f'{ip=}, {procs[ip].name=}')
                
            logger.info('End of verification run\n')
            
        else:
            # Start gams jobs
            nJob = len(procs)
            nJobParallel = min(nJob, nJobParallel)
            logger.info(f'Starting GAMS jobs: {nJobParallel=}, {nJob=}')
            for ip in range(nJobParallel):
                procs[ip].start()
                logger.info(f'Started process={procs[ip].pid} for {procs[ip].name}')
            
            jobsStarted = nJobParallel
            timer = time.perf_counter()
            jobNoToKill = 0
            while True:
                #--- jobNoToKill = readInput('Enter number of job to terminate:', jobInterval ) 
                time.sleep(jobInterval)    # Let the terminal wait.
                
                # Start additional jobs if possible when running jobs have completed. 
                count = 0
                for ip in range(jobsStarted):
                    if ip == jobNoToKill - 1:   # jobNoToKill is base-1.
                        procs[ip].terminate()
                        procs[ip].join()        
                    if procs[ip].is_alive():
                        count += 1 
                
                if count < nJobParallel and (nJob - jobsStarted) > 0:
                    logger.info(f'Starting job[{procs[jobsStarted].name}] ...')
                    procs[jobsStarted].start()        
                    jobsStarted += 1
            
                # Print progress of gams jobs by inspecting GAMS listing file in reverse.
                timer = reportProgress(startTime, scens, printInterval, procs, core, jobsStarted, timer) 

                # Terminate loop if all jobs have completed.
                if not active_children():
                    break
            
            logger.info(f'Finished all selected {nJob} scenarios in {str(dt.timedelta(seconds=int(time.perf_counter()-startTime)))}')    
            #--- send_email('mbl@AddedValues.eu', 'Automail from {NAME}', 'Job completed')
            
    except Exception as ex:
        logger.critical(f'\nException occurred in {NAME}\n{ex=}\n', exc_info=True)
    
    finally:
        if 'wb' in locals() and wb is not None:
            try: 
                wb.close()
                wb.app.quit()
            except:
                pass
            finally:
                mec.shutdown(logger, f'{NAME} ended.')
                quit()

