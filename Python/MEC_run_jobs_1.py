# -*- coding: utf-8 -*-
"""
Script that generates multiple gams jobs using multiprocessing
Used for project 23-1002 MEC FF version

"""

#%% Imports and functions.
import sys
import logging 
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
#--- import numpy as np
import msvcrt

ZERO : int = 0
ONE  : int = 1

# Setup logger(s): Levels are: DEBUG, INFO, WARNING, ERROR, CRITICAL. See https://realpython.com/python-logging/

#--- logfile_handler = logging.FileHandler(filename='MEC_run_jobs_1.log', mode='a')
logfile_handler = logging.FileHandler(filename='MEC_run_jobs_1.log', mode='w')
stdout_handler  = logging.StreamHandler(stream=sys.stdout)
#--- stdout_handler.level = logging.INFO
handlers = [logfile_handler, stdout_handler]

logging.basicConfig(
    level=logging.DEBUG, 
    format='[%(asctime)s] {%(filename)s:%(lineno)d} %(levelname)s - %(message)s',
    datefmt='%y-%b-%d %H.%M.%S',
    handlers=handlers
)

log = logging.getLogger('MEC')

#--- logging.basicConfig(level=logging.DEBUG, filename='MEC_run_jobs_1.log', filemode='w',
#---                     format='%(asctime)s : %(levelname)s : %(message)s', datefmt='%y-%b-%d %H.%M.%S')

"""
Example of logging an exception:
a =5; b = 0;
try:
  c = a / b
except Exception as e:
  logging.error("Exception occurred", exc_info=True)
  
OR simply:
logging.exception("Exception occurred")
"""

def readInput(caption, timeout = 5):
    start_time = time.time()
    log.debug(caption)
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
        #--- log.info("Successfully sent email")
        log.info(f'Succesfully sent e-mail to {receiver}')
    except Exception as ex:
        log.error("Error: unable to send email,\n{ex=}", exc_info=True)

def worker(scen, workDir, resultDir):
    """process worker function"""
    
    try:
        #--- log.debug(f'worker: {workDir=}\n        {resultDir=}')
        
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
            log.info(f'Moving file={os.path.relpath(file)} to {os.path.relpath(resultDir)}')
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
        log.critical(f'\nException occurred in MEC_run_jobs_1.worker on {scen=}\n{ex=}\n', exc_info=True)
        raise
    finally:
        if fout is not None:
            fout.close()
        
    return
   
def copyInputFiles(sourceDir, targetDir):
    
    log.info(f'Copying input files to {targetDir} ...')
    if os.path.exists(targetDir):
        # Remove any file from folder targetDir.
        log.info(f'Removing files from working directory: {targetDir}')
        allFiles = glob.glob(os.path.join(targetDir, '*.*'))
        try:
            for filePath in allFiles:
                # log.debug(f'Removing file {filePath}')
                os.remove(filePath)
        except Exception as ex:
            log.warning(f'Unable to remove file: {filePath}\n{ex=}', exc_info=True)
    else:
        log.info(f'Creating working directory: {targetDir}')
        os.makedirs(targetDir)

    files = glob.iglob(os.path.join(sourceDir, '*.op*'))
    for file in files:
        if os.path.isfile(file):
            shutil.copy2(file, targetDir)

    files = glob.iglob(os.path.join(sourceDir, '*.gms'))
    for file in files:
        if os.path.isfile(file):
            shutil.copy2(file, targetDir)

    shutil.copy2(os.path.join(sourceDir, 'MEC.gpr'),                 targetDir)
    shutil.copy2(os.path.join(sourceDir, 'MECKapacInput.xlsb'),      targetDir)    
    shutil.copy2(os.path.join(sourceDir, 'GamsCmdlineOptions.txt'),  targetDir)
    shutil.copy2(os.path.join(sourceDir, 'options.inc'),             targetDir)        
    shutil.copy2(os.path.join(sourceDir, 'MECMasterOutput.xlsm'),    targetDir)          
    shutil.copy2(os.path.join(sourceDir, 'MECTidsAggregering.xlsx'), targetDir)        
    
    return

def copyResultFiles(scen, workDir, resultDir):
    # Copy results file to new folder
    #--- log.info('Copying result files for {scen=} ...')
    resultFiles = ['MECKapacInput.xlsb', 'MECMasterOutput.xlsm', '_gams_py_gjo0.lst', 'MECmain.gdx']
    for file in resultFiles:
        pathIn = os.path.join(workDir, file)
        if (os.path.exists(pathIn)):
            fname, fext = os.path.splitext(file)
            pathOut = os.path.join(resultDir, fname + '_' + scen + fext)
            shutil.copy2(pathIn, pathOut)

    # Remove temporary folders
    folders = glob.iglob(os.path.join(workDir, '225*')) 
    for folder in folders:
        shutil.rmtree(folder) 

    return

def getScenIdAsNum(id: str):
    """ Converts textual scenario id 'MmmSssUssRrrFff' to integer """    
    numid =  int(id[1:3])
    for i in range(1, 5):
        numid = 100 * numid + int(id[3*i + 1 : 3*i + 3])

    return numid

def setParm(sheet, icolBase1: int, df: pd.DataFrame, fullName: str, newValue: float = None, newValues: list[float] = None, 
            lookupCol: str = 'RecordKey', irowOfz: int = 9):
    """
    Sets the value of a parameter in an Excel sheet by looking up the row in dataframe df.

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

    mutualExclusing = (newValue is None) ^(newValues is None)
    if not mutualExclusing:
        raise ValueError('setParm arguments newValue and newValues shall be mutually exclusive')

    try:
        # if True:
        # log.debug(f'{fullName=}, {lookupCol=}, {icolBase1=}')
        irowBase1 = (df[df[lookupCol] == fullName].index)[0] + 1
        cell = (irowOfz + irowBase1, icolBase1)
        # oldValue = df.iloc[irowBase1-1, icolBase1-1] 
        # log.debug(f'{sheet.name=}: Parm.{fullName=}, {cell=}, {oldValue=}, {newValue=}')
        if newValues is None:
            log.info(f'setParm {fullName} to {newValue}') 
            sheet.range(cell).value = newValue
        else:
            log.info(f'setParm {fullName} to {newValues}') 
            sheet.range(cell).value = newValues
            
    except Exception as ex:
        log.critical("Exception occurred in setParm:\n{ex=}\n{sheet.name=}: Parm.{fullName=}, {icolBase1=}\n", exc_info=True)
        #---  log.debug(f'Exception caught in setParm:\n{ex=}')
        #---  log.debug(f'{sheet.name=}: Parm.{fullName=}, {icolBase1=}')
        return ex
    
@dataclass    
class ParmHub():
    wb                          # Excel workbook
    shMaster                    # Sheet ScenMaster    
    shPeriod                    # Sheet ScenPeriod
    shYear                      # Sheet ScenYear
    
    dfM : pd.DataFrame
    dfP : pd.DataFrame
    dfY : pd.DataFrame
    
    iMaster   : int = -1        # Index of master scenario (base-1)
    iMasterOfz: int = 3         # Column number before first master scenario.
    iPeriodOfz: int = 2         # Column number before period scenario values.
    iYearOfz  : int = 5         # Column number before period scenario values.

    periodFirst   : int =  7  # 2025
    periodLast    : int = 17  # 2035 
    onTimeAggr    : int = -2  # Use -2 if OnDuplicate < 0.
    onDuplicate   : int =  0  # Use -2 if OnDuplicate < 0.
    lenRHOverhang : int = 10 if (onTimeAggr != 0) else 72  # Length of RH discarded after optimization of each RH.
    
    shMaster = wb.sheets['ScenMaster']   
    shPeriod = wb.sheets['ScenPeriod']   
    shYear   = wb.sheets['ScenYear']   

def SetDefaultParms(parmHub: ParmHub, periodFirst, periodLast, ) -> None:
    """ Sets up default values of rarely changed parameters. """
    hub = parmHub
    # Kørselsparametre
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.ScenarioID',              newValue = getScenIdAsNum(scenId))
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.PeriodFirst',             newValue = PeriodFirst)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.PeriodLast',              newValue = PeriodLast)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.DurationPeriod',          newValue = 8760)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.LenRollHorizonOverhang',  newValue = lenRHOverhang)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.OnDuplicatePeriods',      newValue = ZERO)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.OnTimeAggr',              newValue = onTimeAggr)  #  -2 or +2
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.MasterIterMax',           newValue = 15)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'Scenarios.AlfaVersion',             newValue = 5)
    # Eksisterende anlæg: Centrale anlæg er til rådighed som default.                                                   
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.MaAff1',              newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.MaAff2',              newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.MaBio',               newValue = ONE)
    # Nye anlægsmuligheder: Alle anlæg til rådighed som default
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.HoNhpAir',            newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.HoNhpSew',            newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.HoNEk',               newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.StNhpAir',            newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.StNhpSea',            newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.StNhpSew',            newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.StNFlis',             newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.MaNAff',              newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.MaNBk',               newValue = ONE)
    # Overskudsvarme: Alle OV-kilder til rådighed som default
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.HoNhpArla',           newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.HoNhpArla2',          newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.HoNhpBirn',           newValue = ONE)
    setParm(hub.shMaster, hub.iColMasB1, hub.dfM, 'OnUGlobalScen.MaNPtX',              newValue = ONE)
    
    # Periodeparametre
    pass
    
    # Årsparametre
    pass
    
    return

#%% Main procedure
   
if __name__ == '__main__':
    try:
        log.info('Starting MEC_run_jobs_1 ...')
        t1 = time.perf_counter()
        
        """ Scenario encoding:  mm-ss-uu-rr-ff
                mm: model version
                ss: main scenario id
                uu: sub-scenario id
                rr: roadmap id
                ff: sensitivity id
        """
        scens = { # Key is scenario-id, Value is short name.     Include letter T if a scenario is just for testing and set doTest = True.
                # 'T11T99T01T00T00': 'TestScenarie',               # Bruges til afprøvning af scripting.
                'm11s01u00r00f00': 'Opgave 0 - basis',      # Selvbærende forsyning uden OV, én aff-linje, fra 2025, ny biokedel, MaNVak2 20000 m3. Planperiode 2025 - 2031
                # 'm11s01u00r00f01': 'Opgave 0 - 2 x Elpris'  # Følsomhed overfor elpris
                # 'm11s02u00r00f00': 'Basis u/OV m/2 Aff',    # Selvbærende forsyning uden OV, 2 aff-linje, fra 2025, ny biokedel, MaNVak2 20000 m3. Planperiode 2025 - 2036
                # 'm11s02u01r00f00': 'Basis u/OV m/1 Aff',    # Selvbærende forsyning uden OV, 1 aff-linje, fra 2025, ny biokedel MaNhp, MaNVak2 20000 m3. Planperiode 2025 - 2036
                # 'm11s02u02r00f00': 'Basis u/OV m/0 Aff',    # Selvbærende forsyning uden OV, 0 aff-linje, fra 2025, ny biokedel MaNhp, MaNVak2 20000 m3. Planperiode 2025 - 2036
                }
        scenList = list(scens.keys())    

        # Scenarios to run
        justCreateInputs = False      # If True, do only change the sheet values, else run GAMS jobs.
        doTest           = False      # If True, only run scenarios containing letter 'T'.
        nJob             = len(scens) # Total number of jobs
        nJobParallel     =  2         # Number of jobs to run in parallel (available RAM and gurobi timelimit is the limiting factors)
        jobInterval      =  5         # time between check if new jobs should start
        printInterval    = 30         # seconds between status logging
        root_dir   = os.getcwd()
        if root_dir[-6:].lower() == 'python':
            root_dir = root_dir[:-6]
            
        source_dir = os.path.join(root_dir, 'INVOPT', 'Master')          # Path of master files (source, input data)
        work_dir   = os.path.join(root_dir, 'INVOPT', 'WorkDir')         # Root folder of put new folders for each job    
        result_dir = os.path.join(root_dir, 'INVOPT', 'Results')         # Root folder to put results
        procs = []
        
        log.info(f'Test mode = {doTest}')
        for scenId in scenList: 
            scenName = f'Scen_{scenId}'
            if (doTest) ^ ('T' in scenName):    # Skip scenarios if xor operation is true.
                log.debug(f'Skipping {scenName=}')
                continue

            # Create new folder for each gams job.
            target_dir = os.path.join(work_dir, scenName)
            
            # Copy master source files to new folder
            copyInputFiles(source_dir, target_dir)
            
            # Modify model Excel input file. 
            log.info(f'Modifying Excel input file for {scenName} ...')
            xlapp = xw.App(visible=False, add_book=False)
            wb = xlapp.books.open(os.path.join(target_dir, 'MECKapacInput.xlsb'))
            wb.app.calculation = 'manual'         # Saves quite some time !
            shMaster = wb.sheets['ScenMaster']   
            shPeriod = wb.sheets['ScenPeriod']   
            shYear   = wb.sheets['ScenYear']   
            iMasterOfz = 3                        # Column number before first master scenario.
            iPeriodOfz = 2                        # Column number before period scenario values.
            iYearOfz   = 5                        # Column number before period scenario values.

            # DO NOT use option expand='table' as empty cells will truncate the range covered by xlwings.
            log.info(f'Reading scenarios from {wb.name} ...')
            dfM = shMaster.range('tblScenMasterAll').options(pd.DataFrame, header=True, index=False).value
            dfP = shPeriod.range('tblScenPeriodAll').options(pd.DataFrame, header=True, index=False).value
            dfY = shYear.range(  'tblScenYearAll'  ).options(pd.DataFrame, header=True, index=False).value
            
            log.info(f'INFO: Setting up scenario {scenId} ...')
            
            parmHub = ParmHub(dfM, dfP, dfY, iMaster, PeriodFirst, PeriodLast, OnTimeAggr, )
            
            #---- Setting parameters common to all scenarios.
            PeriodFirst   =  7  # 2025
            PeriodLast    = 17  # 2035 
            onTimeAggr    = -2  # Use -2 if OnDuplicate < 0.
            onDuplicate   =  0  # Use -2 if OnDuplicate < 0.
            lenRHOverhang = 10 if (onTimeAggr != 0) else 72  # Length of RH discarded after optimization of each RH.

            ¤¤¤ run setup of defaults

            if 'T' in scenId:  # Use this scenario for testing of script.
                # ---- T11.T99.T01.T00.T00
                iMaster = 74 
                iColMasB1 = iMasterOfz + iMaster                        # Base-1 column no. of master scenario.
                shMaster.range('ActualMasterScen').value = iMaster      # Set master scenario.
                SetDefaultParms(dfM, dfP, dfY, iColMasB1)
                PeriodLast = PeriodFirst + 3

                # Kørselsparametre
                setParm(shMaster, iColMasB1, dfM, 'Scenarios.PeriodLast',              newValue = PeriodLast)
                # Eksisterende anlæg
                # Nye anlægsmuligheder                                                 
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpAir',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpSew',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNEk',               newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpAir',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpSea',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpSew',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNFlis',             newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNAff',              newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNBk',               newValue = ZERO)
                # Overskudsvarme
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla2',          newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNPtX',              newValue = ZERO)

                # Periodeparametre
                # setParm(shPeriod, iPeriodOfz + 0, dfP, 'Periods.DuplicateUntilIteration', newValue )
                
                # Årsparametre
                #--- setParm(shYear, iYearOfz + PeriodFirst + , dfP, 'Periods.DuplicateUntilIteration', newValue)
                
            elif scenId == 'm11s01u00r00f00':
                # ---- m11.s01.u00.r00.f00
                iMaster = 74 
                iColMasB1 = iMasterOfz + iMaster                        # Base-1 column no. of master scenario.
                shMaster.range('ActualMasterScen').value = iMaster      # Set master scenario.
                PeriodLast    = 13 # 2031
                SetDefaultParms(dfM, dfP, dfY, iColMasB1)

                # Kørselsparametre
                setParm(shMaster, iColMasB1, dfM, 'Scenarios.PeriodLast',              newValue = PeriodLast)
                # Eksisterende anlæg                                                   
                # Nye anlægsmuligheder                                                 
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpAir',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpSew',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNEk',               newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpAir',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpSea',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpSew',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNFlis',             newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNAff',              newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNBk',               newValue = ZERO)
                # Overskudsvarme
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla2',          newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNPtX',              newValue = ZERO)

                # Periodeparametre
                # setParm(shPeriod, iPeriodOfz + 0, dfP, 'Periods.DuplicateUntilIteration', newValue )
                
                # Årsparametre
                #--- setParm(shYear, iYearOfz + PeriodFirst + , dfP, 'Periods.DuplicateUntilIteration', newValue)
                
            elif scenId == 'm11s01u00r00f01':  
                # ---- m11.s01.u00.r00.f01
                iMaster = 74 
                iColMasB1 = iMasterOfz + iMaster                           # Base-1 column no. of master scenario.
                shMaster.range('ActualMasterScen').value = iMaster      # Set master scenario.
                PeriodLast    = 13 # 2031
                SetDefaultParms(dfM, dfP, dfY, iColMasB1)
                
                # Kørselsparametre
                setParm(shMaster, iColMasB1, dfM, 'Scenarios.PeriodLast',              newValue = PeriodLast)
                # Eksisterende anlæg                                                   
                # Nye anlægsmuligheder                                                 
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpAir',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpSew',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNEk',               newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpAir',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpSea',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNhpSew',            newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.StNFlis',             newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNAff',              newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNBk',               newValue = ZERO)
                # Overskudsvarme
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla2',          newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNPtX',              newValue = ZERO)

                # Periodeparametre
                # setParm(shPeriod, iPeriodOfz + 0, dfP, 'Periods.DuplicateUntilIteration', newValue )
                
                # Årsparametre
                #--- setParm(shYear, iYearOfz + PeriodFirst + , dfP, 'Periods.DuplicateUntilIteration', newValue)
                icolGain = -2  # Gain factor is located 2 columns left of first table column.
                setParm(shYear, iYearOfz + icolGain, dfY, 'SB22.ElspotOffset', 2.000)  # SB22.ElspotOffset
                
            elif scenId == 'm11s02u00r00f00':  # Selvbærende forsyning uden OV, 2 aff-linje, fra 2025, ny biokedel, MaNVak2 20000 m3. Planperiode 2025 - 2036
                # ---- m11.s02.u00.r00.f00
                iMaster = 75 
                iColMasB1 = iMasterOfz + iMaster                           # Base-1 column no. of master scenario.
                shMaster.range('ActualMasterScen').value = iMaster      # Set master scenario.
                SetDefaultParms(dfM, dfP, dfY, iColMasB1)
                
                # Kørselsparametre
                # Eksisterende anlæg                                                   
                # Nye anlægsmuligheder 
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNAff',              newValue = ZERO)
                # Overskudsvarme
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla2',          newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpBirn',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNPtX',              newValue = ZERO)

                # Periodeparametre
                iColPerB1 = PeriodFirst  # Column is base-1 and a value of 1 corresponds to per1.
                # setParm(shPeriod, iPeriodOfz + iColPerB1, dfP, 'Periods.DuplicateUntilIteration', newValue )
                # setParm(shPeriod, iPeriodOfz + iColPerB1, dfP, 'CapUInitPer.MaNBk', newValues=[110.0 for i in range(PeriodFirst, PeriodLast + 1)] )
                
                # Årsparametre
                #--- setParm(shYear, iYearOfz + PeriodFirst + , dfP, 'Periods.DuplicateUntilIteration', newValue)
                #--- icolGain = -2  # Gain factor is located 2 columns left of first table column.
                #--- setParm(shYear, iYearOfz + icolGain, dfY, 'SB22.ElspotOffset', 2.000)  # SB22.ElspotOffset

            elif scenId == 'm11s02u01r00f00':  # Selvbærende forsyning uden OV, 2 aff-linje, fra 2025, ny biokedel, MaNVak2 20000 m3. Planperiode 2025 - 2036
                # ---- m11.s02.u01.r00.f00
                iMaster = 75 
                iColMasB1 = iMasterOfz + iMaster                           # Base-1 column no. of master scenario.
                shMaster.range('ActualMasterScen').value = iMaster      # Set master scenario.
                SetDefaultParms(dfM, dfP, dfY, iColMasB1)
                
                # Kørselsparametre
                # Eksisterende anlæg                                                   
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaAff2',              newValue = ZERO)
                # Nye anlægsmuligheder                                                 
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNAff',              newValue = ZERO)
                # Overskudsvarme                                                       
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla2',          newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpBirn',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNPtX',              newValue = ZERO)

                # Periodeparametre
                # setParm(shPeriod, iPeriodOfz + 0, dfP, 'Periods.DuplicateUntilIteration', newValue )
                
                # Årsparametre
                #--- setParm(shYear, iYearOfz + PeriodFirst + , dfP, 'Periods.DuplicateUntilIteration', newValue)
                #--- icolGain = -2  # Gain factor is located 2 columns left of first table column.
                #--- setParm(shYear, iYearOfz + icolGain, dfY, 'SB22.ElspotOffset', 2.000)  # SB22.ElspotOffset

            elif scenId == 'm11s02u02r00f00':  # Selvbærende forsyning uden OV, 0 aff-linje, fra 2025, ny biokedel MaNhp, MaNVak2 20000 m3. Planperiode 2025 - 2036
                # ---- m11.s02.u02.r00.f00
                iMaster = 75 
                iColMasB1 = iMasterOfz + iMaster                           # Base-1 column no. of master scenario.
                shMaster.range('ActualMasterScen').value = iMaster      # Set master scenario.
                SetDefaultParms(dfM, dfP, dfY, iColMasB1)
                
                # Kørselsparametre
                # Eksisterende anlæg                                                   
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaAff1',              newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaAff2',              newValue = ZERO)
                # Nye anlægsmuligheder                                                 
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNAff',              newValue = ZERO)
                # Overskudsvarme                                                       
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpArla2',          newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.HoNhpBirn',           newValue = ZERO)
                setParm(shMaster, iColMasB1, dfM, 'OnUGlobalScen.MaNPtX',              newValue = ZERO)
                
                # Periodeparametre
                # setParm(shPeriod, iPeriodOfz + 0, dfP, 'Periods.DuplicateUntilIteration', newValue = )
                
                # Årsparametre
                #--- setParm(shYear, iYearOfz + PeriodFirst + , dfP, 'Periods.DuplicateUntilIteration', newValue= )
                #--- icolGain = -2  # Gain factor is located 2 columns left of first table column.
                #--- setParm(shYear, iYearOfz + icolGain, dfY, 'SB22.ElspotOffset', newValue = 2.000)  # SB22.ElspotOffset

            else:
                raise ValueError(f'No initialization code for {scenName}')

            wb.app.calculation = 'automatic'
            wb.app.calculate()
            wb.save()
            xlapp.quit()
            xlapp = None
            
            # Prepare jobs (worker functions)
            # if not justCreateInputs:
            log.info(f'Spawning process for {scenName} job ...')
            procs.append(Process(name=scenName, target=worker, args=(scenName, target_dir, result_dir)))
                
        # End of ... for scenId in scenList
            
        if justCreateInputs:
            for ip, proc in enumerate(procs):
                log.debug(f'{ip=}, {procs[ip].name=}')
                
            log.info('End of verification run\n')
            
        else:
            # Start gams jobs
            nJob = len(procs)
            nJobParallel = min(nJob, nJobParallel)
            log.info(f'Starting GAMS jobs: {nJobParallel=}, {nJob=}')
            for i in range(nJobParallel):
                procs[i].start()
            
            jobsStarted = nJobParallel
            timer = time.perf_counter()
            jobNoToKill = 0
            while True:
                #--- jobNoToKill = readInput('Enter number of job to terminate:', jobInterval ) 
                time.sleep(jobInterval)    # Let the terminal wait.
                
                # Start additional jobs if possible when running jobs have completed. 
                count = 0
                for i in range(jobsStarted):
                    if i == jobNoToKill - 1:   # jobNoToKill is base-1.
                        procs[i].terminate()
                        procs[i].join()        
                    if procs[i].is_alive():
                        count += 1 
                
                if count < nJobParallel and (nJob - jobsStarted) > 0:
                    log.info(f'Starting job[{jobsStarted}] ...')
                    procs[jobsStarted].start()        
                    jobsStarted += 1
            
                # Print progress of gams jobs by inspecting GAMS listing file in reverse.
                linePrev    = ''
                linePrev2   = ''
                dElapsedSecs = time.perf_counter() - timer     # Time elapsed since last log update.
                if dElapsedSecs >= printInterval:
                    elapsed = str(dt.timedelta(seconds=int(time.perf_counter() - t1)))
                    if '.' in elapsed:
                        elapsed = elapsed[:elapsed.find('.')]
                    #--- log.info(f'Elapsed Time: {elapsed}')

                    for i in range(jobsStarted):
                        if procs[i].is_alive():
                            #--- log.info(f'Job {i+1} - Status {scenList[i]}: running.') 

                            try:
                                scenName = procs[i].name
                                target_dir = os.path.join(work_dir, scenName)
                                listingFile = os.path.join(target_dir, '_gams_py_gjo0.lst')
                                linePrev = ""
                                for line in reversed(list(open(listingFile, 'r'))):
                                    if (line[:5] == "LOOPS") and ("iter   iter" in line):
                                        actIter   = line[line.find("iter")             + 7 : line.find("iter")        + 7 + 7].replace('\n', '')
                                        actPeriod = linePrev[linePrev.find("perL")     + 7 : linePrev.find("perL")    + 7 + 6].replace('\n', '')
                                        actRHstep = linePrev2[linePrev2.find("rhStep") + 9 : linePrev2.find("rhStep") + 9 + 5].replace('\n', '')
                                        if len(actPeriod.strip()) == 0:  
                                            log.info(f'Job {i+1} - Status {scenName}: iter={actIter}, master-model, Elapsed= {elapsed}' )
                                        else:
                                            log.info(f'Job {i+1} - Status {scenName}: iter={actIter}, period={actPeriod}, RHstep={actRHstep}, Elapsed= {elapsed}' )
                                        break
                                    linePrev2 = linePrev
                                    linePrev = line
                            except FileNotFoundError:
                                log.info(f'Listing file not yet available for {scenList[i]}')
                                # log.info(f'Job {i+1} - Status {scenName}: Starting ...')
                            except Exception as ex:
                                log.error(f'Exception caught: {ex=}', exc_info=True)
                                log.debug(f'{line=}')
                            
                        else:
                            log.info(f'Job {i+1} - Status {scenList[i]}: Completed.') 
                            
                    timer = time.perf_counter() 
                
                # Terminate if all jobs complete 
                if not active_children():
                    break
            
            log.info(f'Finished all selected {nJob} scenarios in {str(dt.timedelta(seconds=int(time.perf_counter()-t1)))}')    
            #--- send_email('mbl@AddedValues.eu', 'Automail from MEC_run_jobs_1', 'Job completed')
            
    except Exception as ex:
        log.critical(f'\nException occurred in MEC_run_jobs_1\n{ex=}\n', exc_info=True)
    
    finally:
        log.info('Closing log file.')
        for handler in log.handlers:
            handler.close()
            log.removeFilter(handler)        
        logging.shutdown()
        if xlapp is not None:
            xlapp.quit()
            xlapp = None
        
        
