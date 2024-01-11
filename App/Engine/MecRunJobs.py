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
from multiprocessing import Process, active_children  # See: https://superfastpython.com/multiprocessing-in-python/
import ssl
import smtplib
from email.message import EmailMessage
import glob, os, shutil
import time 
import datetime as dt
import math
import pandas as pd
import xlwings as xw
import numpy as np
import msvcrt
# import GdxWrapper as gw 
import MEClib as mec


ZERO : int = 0
ONE  : int = 1
TWO  : int = 2
NAME : str = 'MECRunJobs'

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
                ans = input(f' - Terminate job {job} - (y/n)? ')
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
        
def getFileName(scenId: str, fnameOrig: str, fext: str) -> str:
    """ Returns the file name of the result file for scenario scen. """
    return f'{fnameOrig}_{scenId}{fext}'


def worker(scenId, workDir, resultDir) -> None:
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
        opt.gdx  = "MECmain.gdx"    # Tell gams to produce a gdx file at end of run (equivalent to the gams command line option GDX=default)
        gamsJob = ws.add_job_from_file("MECmain.gms")
        
        # Create file stream to receive output from GAMS Job
        fout = open(os.path.join(workDir, 'MECmain.log'), 'w')  
        gamsJob.run(opt, output=fout)                               #--- gams_job.run(opt, output=sys.stdout)

        # Read job status from GAMS in-memory database.
        masterIter = int(gamsJob.out_db.get_parameter("MasterIter").first_record().value)
        iterOptim =  int(gamsJob.out_db.get_parameter("IterOptim").first_record().value)
        logger.debug(f'{masterIter=}, {iterOptim=}')
                    
        # Create resultDir if it does not exist.
        if not os.path.exists(resultDir):
            logger.debug(f'worker: Creating {resultDir=}')
            os.mkdir(resultDir)
        else:
            # Delete existing results files.
            logger.debug(f'worker: Removing files from {resultDir=}')
            files = glob.glob(os.path.join(resultDir, '*.*'))
            for f in files:
                os.remove(f)    

        # Copy results file to new folder: Input, MasterOutput, Listing, GDX, Log   
        logger.info(f'Copying files from {workDir=} to {resultDir=} ...')
        resultFiles = ['MECKapacInput.xlsb', 'MECMasterOutput.xlsm', '_gams_py_gjo0.lst', 'MECmain.log', 'MECmain.gdx', 'JobStats.gdx']
        
        for file in resultFiles:
            logger.debug(f'Copying file={os.path.relpath(file)} to {os.path.relpath(resultDir)}')
            pathIn = os.path.join(workDir, file)
            if (os.path.exists(pathIn)):
                fname, fext = os.path.splitext(file)
                pathOut = os.path.join(resultDir, getFileName(scenId, fname, fext))
                shutil.copy2(pathIn, pathOut)
                
        periodGdxResults = [f for f in glob.iglob(os.path.join(workDir, 'MEC_Results_iter*.gdx'))]   # Returns fully-qualified file name.
        fileFilter = [ f'MEC_Results_iter{iterOptim}', f'MEC_Results_iter{masterIter}']
        for file in periodGdxResults:
            if any(x in file for x in fileFilter):
                logger.debug(f'Copying file={os.path.relpath(file)} to {os.path.relpath(resultDir)}')
                pathIn = file
                if (os.path.exists(pathIn)):
                    fnames = os.path.split(file)
                    fname, fext = os.path.splitext(fnames[-1])
                    pathOut = os.path.join(resultDir, getFileName(scenId, fname, fext))
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
        logger.critical(f'\nException occurred in {NAME}.worker on {scenId=}\n{ex=}\n', exc_info=True)
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

        self.period1 = 2019    
    
    @property
    def firstYearOfTable(self) -> int:
        """ Returns the first year of the table. Use firstYear to get the first year of the scenario. """
        return self.getPeriodAsYear(1)
                
    @property
    def firstYear(self) -> int:
        """ Returns the first year of the scenario."""
        return self.getPeriodAsYear(core.PeriodFirst)
                
    @property
    def lastYear(self) -> int:
        """ Returns the last year of the scenario."""
        return self.getPeriodAsYear(core.PeriodLast)

    def getYearAsPeriod(self, year: int) -> int:
        """ Converts year to period number. """
        return year - self.period1 + 1

    def getPeriodAsYear(self, period: int) -> int:
        """ Converts period number to year. """
        return period + self.period1 - 1

    def getScenIdAsNum(self, id: str):
        """ Converts textual scenario id 'MmmSssUssRrrFff' to integer """    
        numid =  int(id[1:3])
        for i in range(1, 5):
            numid = 100 * numid + int(id[3*i + 1 : 3*i + 3])
        return numid

    def copyInputFiles(self, copyAllFiles: bool = True):
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

        if copyAllFiles:
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
            shutil.copy2(os.path.join(self.sourceDir, 'CleanUpPre.bat'),          self.targetDir)    
            shutil.copy2(os.path.join(self.sourceDir, 'GamsCmdlineOptions.txt'),  self.targetDir)
            shutil.copy2(os.path.join(self.sourceDir, 'options.inc'),             self.targetDir)        
            shutil.copy2(os.path.join(self.sourceDir, 'MECMasterOutput.xlsm'),    self.targetDir)          
            shutil.copy2(os.path.join(self.sourceDir, 'MECTidsAggregering.xlsx'), self.targetDir)   

        else:
            shutil.copy2(os.path.join(self.sourceDir, 'MECKapacInput.xlsb'),      self.targetDir)    
        
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

    def openExcelInputFile(self, visible: bool = False):
        """ Opens input Excel file for modification."""
        # Input file resides in workDir.
        xlapp = xw.App(visible=visible, add_book=False)
        self.wb = xlapp.books.open(os.path.join(self.targetDir, 'MECKapacInput.xlsb'))
        self.wb.app.calculation = 'manual'         # Saves quite some time !
        self.shMaster   = self.wb.sheets['ScenMaster']   
        self.shPeriod   = self.wb.sheets['ScenPeriod']   
        self.shYear     = self.wb.sheets['ScenYear']   
        self.shDataU    = self.wb.sheets['DataU']
        self.shOptimKap = self.wb.sheets['OptimKap']
        self.shChp      = self.wb.sheets['CHP']
        self.iMasterOfz = 3                        # Column number before first master scenario.
        self.iPeriodOfz = 2                        # Column number before period scenario values.
        self.iYearOfz   = 5                        # Column number before period scenario values.

        # DO NOT use option expand='table' as empty cells will truncate the range read by xlwings.
        logger.info(f'Reading scenarios from {self.wb.name} ...')
        self.etMaster    = mec.ExcelTable(self.shMaster, 'tblScenMasterAll')
        self.etPeriods   = mec.ExcelTable(self.shPeriod, 'tblScenPeriodAll')
        self.etYears     = mec.ExcelTable(self.shYear,   'tblScenYearAll')
        self.etDataU     = mec.ExcelTable(self.shDataU,  'tblDataU')
        self.etFuelPrice = mec.ExcelTable(self.shDataU,  'tblFuelPriceU')
        self.etChp       = mec.ExcelTable(self.shChp,    'tblCHP')

        return self.wb
    
    @property
    def dfM(self):
        return self.etMaster.df
    @property
    def dfP(self):
        return self.etPeriods.df
    @property
    def dfY(self):
        return self.etYears.df
    @property
    def dfDataU(self):
        return self.etDataU.df
    @property
    def dfFuelPrice(self):
        return self.etFuelPrice.df
    @property
    def dfChp(self):    
        return self.etChp.df


    def readOptimKap(self, scenIdRef: str) -> pd.DataFrame:
        """ Reads a table from sheet self.shOptimKap and returns a dataframe. """
        # Find the row number of the cell containing scenIdRef.
        # The table is read until the first empty cell is encountered.
        # The table is returned as a dataframe with the first row as column names.
        
        # Search for scenIdRef in column B.
        columnB = self.shOptimKap.range('B1:B1000').value
        for irow, cell in enumerate(columnB):
            if cell.lower() == scenIdRef.lower():
                # Row index in 0-based, but xlwings use 1-based indexing in tuples.
                df = self.shOptimKap.range((irow+2,2)).expand('table').options(pd.DataFrame, header=True, index=True).value
                df = df.fillna(0.0)
                return df

        # Table was not found.
        raise ValueError(f'No table found in {self.shOptimKap.name} with scenIdRef={scenIdRef}')

    def setNamedRange(self, sheetName:str, rangeName:str, value: float | list):
        """ Sets the value of a named range in a worksheet. """
        sheet = self.wb.sheets[sheetName]
        sheet.range(rangeName).value = value
        return

    def setParmMaster(self, fullName: str, newValue: float = None, newValues: list[float] = None, opr: str = 'set',
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
        opr : str, optional (applies only to scalar value i.e. newValues is None).
            Operator to be used for updating the cell. The default is 'set' (setting the passed value).
            'add': Adds the passed value to the cell value.
            'sub': Subtracts the passed value from the cell value.
            'mult': Multiplies the cell value with the passed value.
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
        if opr not in ['set', 'add', 'sub', 'mult']:
            raise ValueError(f'opr={opr} not recognized, should be one of ["set", "add", "sub", "mult"]')
        if opr != 'set' and newValue is None:
            raise ValueError(f'opr={opr} is not implemented for array newValues')

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
                existValue = sheet.range(cell).value
                if opr == 'set':
                    logger.info(f'setParmMaster {fullName} to {newValue}') 
                    sheet.range(cell).value = newValue
                elif opr == 'add':
                    logger.info(f'setParmMaster adds {newValue} to {fullName}={existValue} yielding {existValue + newValue}') 
                    sheet.range(cell).value += newValue
                elif opr == 'sub':
                    logger.info(f'setParmMaster subtract {newValue} from  {fullName}={existValue} yielding {existValue - newValue}') 
                    sheet.range(cell).value -= newValue
                elif opr == 'mult':
                    logger.info(f'setParmMaster multiplies  {newValue} onto {fullName}={existValue} yielding {existValue * newValue}') 
                    sheet.range(cell).value *= newValue
            else:
                logger.info(f'setParmMaster {fullName} to {newValues}') 
                sheet.range(cell).value = newValues
                
        except Exception as ex:
            logger.critical(f"Exception occurred in setParmMaster:\n{ex=}\n{sheet.name=}: Parm.{fullName=}, {irowBase1=}\n", exc_info=True)
            return ex

        return
    
    def setParmPeriod(self, fullName: str, periodBegin: int = None, newValue: float = None, newValues: list[float] = None, newValuesAsDict: dict[int,float] = None, 
                        lookupCol: str = 'RecordKey', irowOfz: int = 9):

        mutualExcluding = ((newValue is None) ^(newValues is None))
        if not mutualExcluding and newValuesAsDict is None:
            raise ValueError('setParmPeriod arguments newValue and newValues shall be mutually exclusive')

        try:
            df = self.dfP
            sheet = self.shPeriod
            foundArray = df[lookupCol] == fullName
            if not foundArray.any():
                logger.critical(f'{fullName=} not found by setParmPeriod (OBS: Names are case sensitive).')
                raise ValueError(f'{fullName=} not found by setParmPeriod (OBS: Names are case sensitive).')
            
            irowBase1 = (df[foundArray].index)[0] + 1

            if periodBegin is not None:
                icolBase1= self.iPeriodOfz + periodBegin
                cell = (irowOfz + irowBase1, icolBase1)
                if newValues is None:
                    logger.info(f'setParm {fullName} to {newValue}') 
                    sheet.range(cell).value = newValue
                else:
                    # periods = [mec.per2year(per) for per in range(periodBegin, periodBegin + len(newValues))]
                    d = { mec.per2year(per+periodBegin):val for per,val in enumerate(newValues)}
                    logger.info(f'setParm {fullName} to {d}') 
                    #--- logger.info(f'setParm {fullName} to {newValues}') 
                    sheet.range(cell).value = newValues

            elif newValuesAsDict is not None:
                d = { mec.per2year(per):val for per,val in newValuesAsDict.items() }
                logger.info(f'setParm {fullName} to {d}') 
                for periodBegin, newValue in newValuesAsDict.items():
                    icolBase1= self.iPeriodOfz + periodBegin
                    cell = (irowOfz + irowBase1, icolBase1)
                    # logger.info(f'setParm {fullName} to {newValue}') 
                    sheet.range(cell).value = newValue                
                
        except Exception as ex:
            logger.critical("Exception occurred in setParmPeriod:\n{ex=}\n{sheet.name=}: Parm.{fullName=}, {iColPeriod=}\n", exc_info=True)
            raise ex

        return

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

        return

    def setParmChp(self, plantName: str, attrName: str, newValue: float = None, lookupCol: str = 'CHP', irowOfz: int = 9):

        df = self.dfChp
        if not attrName in df.columns:
            raise ValueError(f'{attrName=} not found in row header of {self.shChp.name}')
        try:
            sheet = self.shChp
            irowBase1 = (df[df[lookupCol] == plantName].index)[0] + 1
            icolBase1 = df.columns.get_loc(attrName) + 1
            cell = (irowBase1, icolBase1)
            cell = self.etChp.getCellAddr(plantName, attrName, lookupCol)
            logger.info(f'set CHP.{plantName}:{attrName} to {newValue} at {cell=}') 
            sheet.range(cell).value = newValue
        except Exception as ex:
            logger.critical("Exception occurred in setParmChp: {self.shChp.name=}: {plantName=}:{attribute=}\n{ex=}\n", exc_info=True)
            return ex
        
        return 

    def setParmDataU(self, plantName: str, attrName: str, newValue: float = None, lookupCol: str = 'PlantName'):

        df = self.etDataU.df
        if not attrName in df.columns:
            raise ValueError(f'{attrName=} not found in row header of {self.etDataU.sheet.name}')
        try:
            sheet = self.etDataU.sheet
            irowBase1 = (df[df[lookupCol] == plantName].index)[0] + 1
            icolBase1 = df.columns.get_loc(attrName) + 1
            cell = (irowBase1, icolBase1)
            cell = self.etDataU.getCellAddr(plantName, attrName, lookupCol)
            logger.info(f'set DataU.{plantName}:{attrName} to {newValue} at {cell=}') 
            sheet.range(cell).value = newValue
        except Exception as ex:
            logger.critical("Exception occurred in setParmDataU: {self.shDataU.name=}: {plantName=}:{attribute=}\n{ex=}\n", exc_info=True)
            return ex
        
        return 

    def setParmFuelPriceU(self, plantName: str, fuelName: str, newValue: float = None, lookupCol: str = 'FuelPriceU'):

        df = self.etFuelPrice.df
        if not fuelName in df.columns:
            raise ValueError(f'{fuelName=} not found in row header of {self.etFuelPrice.sheet.name}')
        try:
            sheet = self.etFuelPrice.sheet
            irowBase1 = (df[df[lookupCol] == plantName].index)[0] + 1
            icolBase1 = df.columns.get_loc(fuelName) + 1
            cell = (irowBase1, icolBase1)
            cell = self.etFuelPrice.getCellAddr(plantName, fuelName, lookupCol)
            logger.info(f'set FuelPriceU.{plantName}:{fuelName} to {newValue} at {cell=}') 
            sheet.range(cell).value = newValue
        except Exception as ex:
            logger.critical("Exception occurred in setParmFuelPriceU: {self.shDataU.name=}: {plantName=}:{attribute=}\n{ex=}\n", exc_info=True)
            return ex
        
        return 

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
        self.setParmMaster('Scenarios.ScenarioID',              newValue = self.getScenIdAsNum(self.scenId))
        self.setParmMaster('Scenarios.DumpPeriodsToGdx',        newValue = 2)
        self.setParmMaster('Scenarios.PeriodFirst',             newValue = self.PeriodFirst)
        self.setParmMaster('Scenarios.PeriodLast',              newValue = self.PeriodLast)
        self.setParmMaster('Scenarios.DurationPeriod',          newValue = 8760)
        self.setParmMaster('Scenarios.LenRollHorizonOverhang',  newValue = self.lenRHOverhang)
        self.setParmMaster('Scenarios.OnDuplicatePeriods',      newValue = self.onDuplicate)
        self.setParmMaster('Scenarios.OnTimeAggr',              newValue = self.onTimeAggr) 
        self.setParmMaster('Scenarios.MasterIterMax',           newValue = self.masterIterMax)
        self.setParmMaster('Scenarios.AlfaVersion',             newValue = 5)
        self.setParmMaster('Scenarios.DemandYear',              newValue = 2019)
        
        # Eksisterende anlæg: Centrale anlæg er til rådighed som default.                         
        active = ONE if activeExisting else ZERO
        self.setParmMaster('OnUGlobalScen.MaAff1',              newValue = active)
        self.setParmMaster('OnUGlobalScen.MaAff2',              newValue = active)
        self.setParmMaster('OnUGlobalScen.MaBio',               newValue = active)
        self.setParmMaster('OnUGlobalScen.MaBioGas',            newValue = ZERO)     # Biogas plant abandoned due to separate ownership and almost zero net heat exchange.
        
        # Nye anlægsmuligheder: Alle anlæg til rådighed som default
        active = TWO if activeNew else ZERO
        self.setParmMaster('OnUGlobalScen.HoNhpAir',            newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNhpSew',            newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNEk',               newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNFlis',             newValue = active)
        self.setParmMaster('OnUGlobalScen.StNEk',               newValue = active)
        self.setParmMaster('OnUGlobalScen.StNFlis',             newValue = active)
        self.setParmMaster('OnUGlobalScen.StNhpAir',            newValue = active)
        self.setParmMaster('OnUGlobalScen.StNhpSea',            newValue = active)
        self.setParmMaster('OnUGlobalScen.StNhpSew',            newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNAff',              newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNbk',               newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNEk',               newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNhpAir',            newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNbKV1',             newValue = active)
        
        # Overskudsvarme: Alle OV-kilder til rådighed som default
        active = TWO if activeOV else ZERO
        self.setParmMaster('OnUGlobalScen.HoNhpArla',           newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNhpArla2',          newValue = active)
        self.setParmMaster('OnUGlobalScen.HoNhpBirn',           newValue = active)
        self.setParmMaster('OnUGlobalScen.MaNhpPtX',            newValue = active)
        
        # Periodeparametre
        per2027 = self.getYearAsPeriod(2027)
        nper    = self.PeriodLast - self.PeriodFirst + 1
        self.setParmPeriod('QDemandPeakOffsetPer.netHo',     periodBegin=per2027, newValues=20 * np.ones(nper))
        self.setParmPeriod('QDemandPeakOffsetPer.netSt',     periodBegin=per2027, newValues= 2 * np.ones(nper))
        self.setParmPeriod('QDemandFactor.YearSumScaleGain', periodBegin=per2027, newValues= 1 * np.ones(nper))
        
        # Årsparametre
        pass
        
        return
    
def reportProgress(startTime, scens: dict[str,dict], printInterval, procs, core, nJobStarted, timer) -> float:  # Returns updated value of timer.
    """ Reports job progress on the logger. """
    linePrev    = ''
    linePrev2   = ''
    dElapsedSecs = time.perf_counter() - timer     # Time elapsed since last log update.
    if dElapsedSecs >= printInterval:
        elapsed = str(dt.timedelta(seconds=int(time.perf_counter() - startTime)))
        if '.' in elapsed:
            elapsed = elapsed[:elapsed.find('.')]   # Cut-off milliseconds.

        njob = len(procs)
        for ip in range(nJobStarted):
            scenId = procs[ip].name
            scenName = f'Scen_{scenId}'
            scenParms = scens[scenId]
            scenTitle = f'{mec.expandScenId(scenId)} [{scenParms["Title"]}]'
            procTitle = f'PID={str(procs[ip].pid).rjust(5)}'

            if procs[ip].is_alive():
                try:
                    # logger.debug(f'Updating status for {procs[ip].pid} for {procs[ip].name}')
                    proc: Process = procs[ip]
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
                                logger.info(f'Job {ip+1:2d}/{njob} - Status ITER={actIter[4:]}: {scenTitle}, MASTER MODEL, Elapsed={elapsed} : {procTitle}' )
                            else:
                                logger.info(f'Job {ip+1:2d}/{njob} - Status Iter/Per/Rh={actIter[4:].rjust(2)}/{actPeriod[3:].rjust(2)}/{actRHstep[1:].rjust(2)}: {scenTitle}, Elapsed={elapsed} : {procTitle}' )
                            break
                        linePrev2 = linePrev
                        linePrev = line
                except FileNotFoundError:
                    logger.debug(f'Error opening {pathListingFile=}')
                    logger.info(f'{scenId} listing file [{pathListingFile}] not yet available.')
                    # logger.info(f'Job {i+1}/{njob} - Status {scenTitle} : Starting ...')
                except Exception as ex:
                    logger.error(f'Exception caught: {ex=}', exc_info=True)
                    logger.debug(f'{line=}')
            else:
                if '_startTime' not in scenParms:
                    logger.info(f'Job {ip+1} - Status COMPLETED: {scenTitle}, {procTitle}')
                else:
                    if '_endTime' not in scenParms:
                        scenParms['_endTime']  = dt.datetime.now()

                    _elapsedTime: dt.timedelta = scenParms['_endTime'] - scenParms['_startTime']
                    scenParms['_elapsedTime'] = _elapsedTime
                    logger.info(f'Job {ip+1} - Status COMPLETED: {scenTitle}, Duration={str(_elapsedTime)[:8]}, {procTitle}')

        timer = time.perf_counter()

    return timer                    

#%% Main procedure -----------------------------------------------------------------

if __name__ == '__main__':
    try:
        logger.info(f'Starting {NAME} ...')
        startTime = time.perf_counter()
        rootDir   = getRootDir()
        scens: dict[str,dict] = mec.getScenariosFromExcel()    # // scens = mec.getScenarios()
        scenIds = list(scens.keys())

        # Scenarios to run
        justCreateInputs = False        # If True, do only change the sheet values, else run GAMS jobs.
        copyAllFiles     = True         # If False, only the data input file will be copied.
        copyAllFiles |= not justCreateInputs  # Just to be sure all files are copied if not justCreateInputs.
 
        doTest           = False        # If True, only run scenarios containing letter 'T'.
        nJob             = len(scens)   # Total number of jobs
        nJobParallel     =  2           # Number of jobs to run in parallel (available RAM and gurobi timelimit is the limiting factors)
        jobInterval      = 30           # time between check if new jobs should start
        printInterval    = 12           # seconds between status logging
        procs = []                      # List of processes to be spawned.


        # Adjust number of parallel jobs to the spread the load (relevant for large no. of parallel jobs).
        nJob = len(scens)
        nJobParallel = min(nJob, nJobParallel)
        if nJobParallel > 1:
            d1, r1  = (nJob // nJobParallel, nJob % nJobParallel)
            d2, r2  = (nJob // (nJobParallel - 1), nJob % (nJobParallel - 1))
            if (r1 > 0) and ((d2 <= d1+1 and r2 == 0) or (d2 == d1 and r2 > r1)):
                nJobParallel = max(1, nJobParallel - 1)

        logger.info(f'Setting up GAMS jobs: {nJobParallel=}, {nJob=}')

        
        if justCreateInputs:
            logger.warning('Validation mode - only creating input files')
        if doTest:
            logger.info(f'Test mode = {doTest}')
        
        for scenId, scenParms in scens.items(): 
            scenName = f'Scen_{scenId}'
            roadMapId = int(scenId[10:12])
            useOptimKap = roadMapId > 0                         # If True, use OptimKap sheet for new plant capacities.

            # A CoreData instance holds all input data handling of a scenario.
            logger.info(f'Creating CoreData instance for {scenName} ...')
            core = CoreData(scenId, rootDir)
            core.copyInputFiles(copyAllFiles)
            core.openExcelInputFile(visible=justCreateInputs)
            logger.info(f'Modifying Excel input file for {scenName} ...')
            
            # Method setDefaultParms() is used to set parameters common to a group of scenarios.
            # Parameter setup is handled within each primary part of a scenId e.g. main scenario sNN.
            # Thus a sensitivity or a roadmap can reuse the common setup associated with the scenario.
            
            if scenId.startswith('T'):  # Use this scenario for testing of script.
                core.setDefaultParms(iMaster=73, periodFirst=7, periodLast=8, onTimeAggr=+4, onDuplicate=0, masterIterMax=2, \
                                    activeExisting = True, activeNew = False, activeOV = False)
                # Kørselsparametre
                # Eksisterende anlæg
                # Nye anlægsmuligheder                                                 
                # --- core.setParmMaster('OnUGlobalScen.MaNbk',  newValue = ONE)
                # Overskudsvarme
                # Periodeparametre
                # Årsparametre
                # nper = core.PeriodLast - core.PeriodFirst + 1
                # if 'u10' in scenId:
                #     core.setParmPeriod('CapUInitPer.MaNbk', period=core.PeriodFirst, newValues = [30.0 + round(20.0 * random(), 0) for i in range(nper)])
                # elif 'u11' in scenId:
                #     core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                #     core.setParmPeriod('CapUInitPer.MaNbk', period=core.PeriodFirst, newValues = [60.0 + round(20.0 * random(), 0) for i in range(nper)] )
                # elif 'u12' in scenId:
                #     core.setParmMaster('OnUGlobalScen.MaAff1', newValue = ZERO)
                #     core.setParmMaster('OnUGlobalScen.MaAff2', newValue = ZERO)
                #     core.setParmPeriod('CapUInitPer.MaNbk', period=core.PeriodFirst, newValues = [80.0 + round(20.0 * random(), 0) for i in range(nper)] )
                # else:
                #     raise ValueError(f'{scenId=} is not covered by code')

                # Sensitivities
                if scenId.endswith('f01'):
                    # Sensitivity against elspot price.
                    core.setParmMaster('Scenarios.MasterIterMax',     newValue=2)    # Driftsoptimering kun.
                    nper = core.PeriodLast - core.PeriodFirst + 1
                    core.setParmYear('SB22.ElspotGain', 2025, 2.0 * np.ones(nper))
            
            # Plan A hhv B ---   Plan A hhv B ---   Plan A hhv B ---   Plan A hhv B ---   Plan A hhv B ---   Plan A hhv B ---   Plan A hhv B ---   Plan A hhv B ---   
            # Scen m11 s2*    
            elif scenId.startswith('m11s20'):       # Analog til As-Is uden nye anlaeg.
                masterIterMax =  2 
                periodFirst   =  9 if np.isnan(scenParms['PeriodFirst']) else int(scenParms['PeriodFirst'])
                periodLast    = 13 if np.isnan(scenParms['PeriodLast']) else int(scenParms['PeriodLast'])
                onTimeAggr    = +4 if np.isnan(scenParms['OnTimeAggr']) else int(scenParms['OnTimeAggr'])
                ignoreMinLoad =  0 if np.isnan(scenParms['IgnoreMinLoad']) else int(scenParms['IgnoreMinLoad'])  # Controls if minimum load for electric boilers and contingency boilers are active.
                onDuplicate   =  0 if np.isnan(scenParms['OnDuplicate']) else int(scenParms['OnDuplicate'])
                core.setDefaultParms(iMaster=4, periodFirst=periodFirst, periodLast=periodLast, onTimeAggr=onTimeAggr, onDuplicate=onDuplicate, masterIterMax=masterIterMax, activeExisting=True, activeNew=False, activeOV=False)
                per2027 = core.getYearAsPeriod(2027)
                nper = core.PeriodLast - core.PeriodFirst + 1
                core.setParmMaster('Scenarios.UseOptimKap', newValue = int(False))    # Angiv at nye anlaegskapaciteter skal laeses indirekte fra sheet OptimKap baseret på scenId (automatiseret i Excel).
                core.setParmMaster('OnUGlobalScen.MaNVak1', newValue = ZERO)
                core.setParmMaster('OnUGlobalScen.MaNVak2', newValue = ZERO)
                core.setParmMaster('OnUGlobalScen.StVak',   newValue = ZERO)
                core.setParmChp(   'MaBio', 'OnRgk', ZERO)    # Deaktivér røggaskøling for MaBio.
                core.setParmYear(  'SB22.MaffAvail', core.firstYear, newValues=206.0 * np.ones(nper))
                core.setParmPeriod('QDemandPeakOffsetPer.netHo', periodBegin=per2027, newValues=20 * np.ones(nper))
                core.setParmPeriod('QDemandPeakOffsetPer.netSt', periodBegin=per2027, newValues= 2 * np.ones(nper))

            elif scenId.startswith('m11s2') or scenId.startswith('m11s3'):       # Plan A hhv B med scenarie 21 - 27.
                planB = scenId.startswith('m11s3')
                if np.isnan(scenParms['MasterIterMax']):
                    masterIterMax = 2 if useOptimKap else 20  # 2 => driftsoptimering, 20 => investeringsoptimering. 
                else:
                    masterIterMax = int(scenParms['MasterIterMax'])

                periodFirst   =  9 if np.isnan(scenParms['PeriodFirst']) else int(scenParms['PeriodFirst'])
                periodLast    = 22 if np.isnan(scenParms['PeriodLast']) else int(scenParms['PeriodLast'])
                onTimeAggr    = +4 if np.isnan(scenParms['OnTimeAggr']) else int(scenParms['OnTimeAggr'])
                ignoreMinLoad =  0 if np.isnan(scenParms['IgnoreMinLoad']) else int(scenParms['IgnoreMinLoad'])  # Controls if minimum load for electric boilers and contingency boilers are active.
                onDuplicate   =  0 if np.isnan(scenParms['OnDuplicate']) else int(scenParms['OnDuplicate'])
                activeNew     = not useOptimKap
                core.setDefaultParms(iMaster=4, periodFirst=periodFirst, periodLast=periodLast, onTimeAggr=onTimeAggr, onDuplicate=onDuplicate, masterIterMax=masterIterMax, activeExisting=True, activeNew=activeNew, activeOV=False)
                refId = mec.deflateScenId(scenParms['RefScen'])
                core.setParmMaster('Scenarios.UseOptimKap',         newValue = int(useOptimKap))    # Angiv at nye anlaegskapaciteter skal laeses indirekte fra sheet OptimKap baseret på scenId (automatiseret i Excel).
                core.setParmMaster('Scenarios.ScenarioIDReference', newValue = refId)                   # Indsaet reference-scenarie for roadmaps.
                #// core.setParmMaster('Scenarios.IgnoreMinLoad',       newValue = ignoreMinLoad)       # Disable minimum load requirement for plants not serving as base load.

                # Kørselsparametre
                per2027 = core.getYearAsPeriod(2027)
                per2028 = core.getYearAsPeriod(2028)
                per2030 = core.getYearAsPeriod(2030)
                per2032 = core.getYearAsPeriod(2032)
                per2036 = core.getYearAsPeriod(2036)
                yearLast = core.getPeriodAsYear(core.PeriodLast)
                nper = core.PeriodLast - core.PeriodFirst + 1
                
                # Kørselsparametre
                core.setParmMaster('CapUIsNullable.MaNbKV1', newValue = ZERO)               # ZERO => mindstekapacitet kan ikke underskrides.
                # Eksisterende anlæg
                # Nye anlægsmuligheder: Deaktivér visse nye anlaeg.
                core.setParmMaster('OnUGlobalScen.StNhpSew', newValue = ZERO)
                core.setParmMaster('OnUGlobalScen.StNhpSea', newValue = ZERO)
                core.setParmMaster('OnUGlobalScen.MaNAff',   newValue = ZERO)
                core.setParmMaster('OnUGlobalScen.HoNhpSew', newValue = ONE)
                core.setParmMaster('OnUGlobalScen.MaNbKV1',  newValue = TWO)   # TWO => kapacitet skal optimeres.
                core.setParmMaster('CapUIsNullable.MaNbKV1', newValue = ONE)   # ONE => mindstekapacitet kan underskrides, hvis CapUMinPer er negativ.
                # Overskudsvarme
                core.setParmMaster('OnUGlobalScen.HoNhpBirn', newValue = ONE)  # ONE => låst kapacitet.
                if planB:
                    core.setParmMaster('OnUGlobalScen.MaNhpPtX',  newValue = ONE)  # ONE  => låst kapacitet.
                    core.setParmMaster('CapUIsNullable.MaNhpPtX', newValue = ZERO) # ZERO => mindstekapacitet kan ikke underskrides.
                # Periodeparametre
                if not useOptimKap:
                    onUPerMaNbKV1      = list(np.zeros(2028 - 2027)) + list(  1.0 * np.ones(yearLast - 2028 + 1))  # MaNbKv1 er aktiv fra 2028.
                    capUInitPerMaNbKV1 = list(np.zeros(2028 - 2027)) + list(+25.0 * np.ones(yearLast - 2028 + 1))
                    capUMinPerMaNbKV1  = list(np.zeros(2028 - 2027)) + list(-10.0 * np.ones(yearLast - 2028 + 1))  # Negativt fortegn => mindstekapacitet kan underskrides.
                    core.setParmPeriod('OnUNomPer.MaNbKV1',   periodBegin=per2027, newValues=onUPerMaNbKV1)
                    core.setParmPeriod('CapUInitPer.MaNbKV1', periodBegin=per2027, newValues=capUInitPerMaNbKV1)
                    core.setParmPeriod('CapUMinPer.MaNbKV1',  periodBegin=per2027, newValues=capUMinPerMaNbKV1)
                if planB:
                    if True or not useOptimKap:
                        onUPerMaNhpPtX      = list(np.zeros(2030 - 2027)) + list(  1.0 * np.ones(yearLast - 2030 + 1))  # MaNhpPtX er aktiv fra 2030.
                        capUInitPerMaNhpPtX = list(np.zeros(2030 - 2027)) + list(+30.0 * np.ones(yearLast - 2030 + 1))
                        capUMinPerMaNhpPtX  = list(np.zeros(2030 - 2027)) + list(+30.0 * np.ones(yearLast - 2030 + 1))  # Negativt fortegn => mindstekapacitet kan underskrides.
                        core.setParmPeriod('OnUNomPer.MaNhpPtX',   periodBegin=per2027, newValues=onUPerMaNhpPtX)
                        core.setParmPeriod('CapUInitPer.MaNhpPtX', periodBegin=per2027, newValues=capUInitPerMaNhpPtX)
                        core.setParmPeriod('CapUMinPer.MaNhpPtX',  periodBegin=per2027, newValues=capUMinPerMaNhpPtX)

                # Faelles for scenarie 21 - 27 er at RGK er aktiveret for MaBio, inkl. levetidsforlaengelse til 2040+.
                annuityK3 = 50.0 * mec.pmt(rate=0.040, invLen=10)   # Afskrivning på RGK og levetidsforlaengelse Mkr/aar.
                core.setParmChp(   'MaBio', 'OnRgk', ONE)    # Aktivér røggaskøling for MaBio.
                core.setParmPeriod('OnUNomPer.MaBio',      periodBegin=per2027, newValues=np.ones(nper))
                core.setParmPeriod('DeprecExistPer.MaBio', periodBegin=per2027, newValues=(annuityK3 * np.ones(yearLast - 2027 + 1)) )

                if 's21' in scenId or 's31' in scenId:         # 'm11s?1u00r00f00': 'Aff 80 kton, -levetid Aff'
                    core.setParmYear(  'SB22.MaffAvail',       core.firstYear, newValues=80.0 * np.ones(nper))
                    core.setParmMaster('OnUGlobalScen.MaAff2', newValue=ZERO)
                    core.setParmPeriod('OnUNomPer.MaAff1',     periodBegin=per2027, newValues=np.append(np.ones(2032 - 2027), np.zeros(yearLast - 2032 + 1)))

                elif 's22' in scenId or 's32' in scenId:       # 'm11s?2u00r00f00': 'Aff 80 kton, 0 fra 2028, -levetid Aff',  
                    core.setParmYear(  'SB22.MaffAvail',        core.firstYear, np.append(80.0 * np.ones(2028 - 2027), np.zeros(yearLast - 2028 + 1)) )
                    core.setParmMaster('OnUGlobalScen.MaAff2',  newValue = ZERO)
                    # OnUNomPer skal eksplicit sættes til 0 for perioder, hvor en affaldslinje pga. manglende affaldstonnage ikke er aktiv.
                    core.setParmPeriod('OnUNomPer.MaAff1',      periodBegin=per2027, newValues=np.append(np.ones(2028 - 2027), np.zeros(yearLast - 2028 + 1)))
                    core.setParmPeriod('OnUNomPer.MaAff2',      periodBegin=per2027, newValues=np.append(np.ones(2028 - 2027), np.zeros(yearLast - 2028 + 1)))

                elif 's23' in scenId or 's33' in scenId:       # 'm11s?3u00r00f00': 'Aff 80 kton, Aff2 efter Aff1 i 2032-2039',
                    raise ValueError(f'{scenId=} is not covered by code')

                elif 's24' in scenId or 's34' in scenId:       # 'm11s?4u00r00f00': 'Aff 80 kton, Aff2 efter Aff1, +levetid Aff2',
                    annuityAffSingle = 150 * mec.pmt(rate=0.040, invLen=10)     # Annuitet for levetidsforlaengelse af 1 affaldslinje.
                    core.setParmYear('SB22.MaffAvail',          core.firstYear, 80.0 * np.ones(nper))
                    core.setParmPeriod('OnUNomPer.MaAff1',      periodBegin=per2027, newValues=np.append(np.ones(2032 - 2027),  np.zeros(yearLast - 2032 + 1)))
                    core.setParmPeriod('OnUNomPer.MaAff2',      periodBegin=per2027, newValues=np.append(np.zeros(2032 - 2027), np.ones(yearLast - 2032 + 1)))
                    core.setParmPeriod('DeprecExistPer.MaAff2', periodBegin=per2027, newValues=np.append(np.zeros(2032 - 2027), annuityAffSingle * np.ones(yearLast - 2032 + 1))) 

                elif 's25' in scenId or 's35' in scenId:       # 'm11s?5u00r00f00': 'Aff 120 kton, -levetid',
                    core.setParmYear(  'SB22.MaffAvail',        core.firstYear, 120.0 * np.ones(nper))
                    core.setParmPeriod('OnUNomPer.MaAff1',      periodBegin=per2027, newValues=np.append(np.ones(2032 - 2027),  np.zeros(yearLast - 2032 + 1)))
                    core.setParmPeriod('OnUNomPer.MaAff2',      periodBegin=per2027, newValues=np.append(np.ones(2032 - 2027),  np.zeros(yearLast - 2032 + 1)))

                elif 's26' in scenId or 's36' in scenId:       # 'm11s?6u00r00f00': 'Aff 120 kton, +levetid begge Aff',
                    annuityAffBoth = 125 * mec.pmt(rate=0.040, invLen=10)     # Annuitet pr. stk. for levetidsforlaengelse af 2 x 1 affaldslinje.
                    core.setParmYear(  'SB22.MaffAvail',        core.firstYear, 120.0 * np.ones(nper))
                    core.setParmPeriod('OnUNomPer.MaAff1',      periodBegin=per2027, newValues=np.append(np.ones(2032 - 2027),  np.ones(yearLast - 2032 + 1)))
                    core.setParmPeriod('OnUNomPer.MaAff2',      periodBegin=per2027, newValues=np.append(np.ones(2032 - 2027),  np.ones(yearLast - 2032 + 1)))
                    core.setParmPeriod('DeprecExistPer.MaAff1', periodBegin=per2027, newValues=np.append(15.4 * np.ones(2032 - 2027), annuityAffBoth * np.ones(yearLast - 2032 + 1))) 
                    core.setParmPeriod('DeprecExistPer.MaAff2', periodBegin=per2027, newValues=np.append(15.4 * np.ones(2032 - 2027), annuityAffBoth * np.ones(yearLast - 2032 + 1))) 

                elif 's27' in scenId or 's37' in scenId:       #  'm11s?7u00r00f00': 'Aff 120 kton, 0 fra 2028, -levetid',
                    core.setParmYear(  'SB22.MaffAvail',       core.firstYear, np.append(120.0 * np.ones(1), np.zeros(nper-1)) )
                    # OnUNomPer skal eksplicit sættes til 0 for perioder, hvor en affaldslinje pga. manglende affaldstonnage ikke er aktiv.
                    core.setParmPeriod('OnUNomPer.MaAff1',     periodBegin=per2027, newValues=np.append(np.ones(2028 - 2027), np.zeros(yearLast - 2028 + 1)))
                    core.setParmPeriod('OnUNomPer.MaAff2',     periodBegin=per2027, newValues=np.append(np.ones(2028 - 2027), np.zeros(yearLast - 2028 + 1)))

                else:
                    raise ValueError(f'{scenId=} is not covered by code')
                
                # Faelles for alle scenarier er underscenarier u00 som er kapacitetsoptimeringer.
                if 'u00' in scenId:     # m11s??u00r00f00: 'Plan A: Aff 80 kton, -levetid Aff'
                    # Ingen ændringer.
                    pass
                    
                elif 'u01' in scenId:     # m11s??u01r00f00: 'Plan A: Aff 80 kton, -levetid Aff, MaNbKV1 tvang'
                    # MaNbKV1 er til rådighed fra 2028, men kan nulles i alle årene derfra.
                    core.setParmMaster('OnUGlobalScen.MaNbKV1',  newValue = TWO)
                    core.setParmMaster('CapUIsNullable.MaNbKV1', newValue = ZERO)
                    capUMinPerMaNbKV1  = list(np.zeros(2028 - 2027)) + list(+10.0 * np.ones(yearLast - 2028 + 1))
                    core.setParmPeriod('CapUMinPer.MaNbKV1', periodBegin=per2027, newValues=capUMinPerMaNbKV1)

                elif 'u02' in scenId:     # m11s??u02r00f00: 'Plan A: Aff 80 kton, -levetid Aff, -lokale luft-VP'
                    core.setParmMaster('OnUGlobalScen.HoNhpAir',  newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.StNhpAir',  newValue = ZERO)

                elif 'u03' in scenId:     # m11s??u03r00f00: 'Plan A: Aff 80 kton, -levetid Aff, Elspot +200'
                    core.setParmYear('SB22.ElspotOffset', core.firstYearOfTable - 4, newValue=+200)  # OBS: ElspotOffset-faktoren er placeret i kolonnen svarende til 4 år før første år i tabellen.

                elif 'u04' in scenId:     # Capex1 + 20 procent
                    core.setParmMaster('CapexScen.capex1.HoNhpAir', newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.HoNhpSew', newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.HoNFlis',  newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.HoNEk',    newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.StNhpAir', newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.StNFlis',  newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.StNEk',    newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.MaNEk',    newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.MaNbk',    newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.MaNhpAir', newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.MaNbKV1',  newValue = 1.20, opr='mult')
                    core.setParmMaster('CapexScen.capex1.MaNhpPtX', newValue = 1.20, opr='mult')

                elif 'u05' in scenId:     # Kun nye anlaeg på BHP.
                    core.setParmMaster('OnUGlobalScen.HoNEk',    newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.HoNFlis',  newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.HoNhpAir', newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.StNEk',    newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.StNFlis',  newValue = ZERO)
                    core.setParmMaster('OnUGlobalScen.StNhpAir', newValue = ZERO)

                # Eventuel håndtering af roadmaps. Roadmaps er baseret på (delvist) låste kapaciteter.
                if roadMapId > 0:
                    pass

                # Faelles for alle scenarier er følsomheder. 
                qdemandNomHo = 99.06 + 20.0
                qdemandNomSt = 46.85 +  2.0
                if 'f01' in scenId:   #  Plus 20% varmebehov
                    qpeakOfzHo = 20.0 + 0.20 * qdemandNomHo
                    qpeakOfzSt =  2.0 + 0.20 * qdemandNomSt
                    core.setParmPeriod('QDemandPeakOffsetPer.netHo', periodBegin=per2027, newValues=qpeakOfzHo * np.ones(nper))           
                    core.setParmPeriod('QDemandPeakOffsetPer.netSt', periodBegin=per2027, newValues=qpeakOfzSt * np.ones(nper))

                elif 'f02' in scenId:   #  Minus 20% varmebehov
                    qpeakOfzHo = 20.0 - 0.20 * qdemandNomHo
                    qpeakOfzSt =  2.0 - 0.20 * qdemandNomSt
                    core.setParmPeriod('QDemandPeakOffsetPer.netHo', periodBegin=per2027, newValues=qpeakOfzHo * np.ones(nper))           
                    core.setParmPeriod('QDemandPeakOffsetPer.netSt', periodBegin=per2027, newValues=qpeakOfzSt * np.ones(nper))

                elif 'f03' in scenId:   #  Koldt år 2010 baseret på DIN-profil 2010 og kalibreret til 110 % af MEC-normalår 2019. 
                    core.setParmMaster('Scenarios.DemandYear', newValue = 2010)
                    core.setParmPeriod('QDemandFactor.YearSumScaleGain', periodBegin=per2027, newValues=1.10 * np.ones(nper))

                # elif 'f43' in scenId:   #  Koldt år 2010 baseret på DIN-profil 2010 og kalibreret til 110 % af MEC-normalår 2019. 
                    # core.setParmMaster('Scenarios.DemandYear', newValue = 2010)
                    # core.setParmPeriod('QDemandFactor.YearSumScaleGain', periodBegin=per2027, newValues=1.10 * np.ones(nper))

                elif 'f04' in scenId:   #  Varmt år 2014 baseret på DIN-profil 2014 og kalibreret til 90 % af MEC-normalår 2019.
                    core.setParmMaster('Scenarios.DemandYear',           newValue = 2014)
                    core.setParmPeriod('QDemandFactor.YearSumScaleGain', periodBegin=per2027, newValues=0.90 * np.ones(nper))

                elif 'f05' in scenId:   #  N-1 udfald Bio-K3
                    core.setParmMaster('OnRevisionGlobal.MaBio', newValue= 2)      # Tallet 2 angiver at 3 ugers udetid i jan-feb er aktive for MaBio.

                elif 'f06' in scenId:   #  +50% kvotepris
                    core.setParmYear('SB22.TaxCO2Kvote', core.firstYearOfTable - 3, newValue= +1.50)      # OBS: Gain-Faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.

                elif 'f07' in scenId:   #  -50% kvotepris
                    core.setParmYear('SB22.TaxCO2Kvote', core.firstYearOfTable - 3, newValue= 0.50)      # OBS: Gain-faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.

                elif 'f08' in scenId:   #  +50% biopris
                    core.setParmYear('SB22.FlisPriceGain', core.firstYearOfTable - 3, newValue= 1.50)      # OBS: Gain-faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.
                    core.setParmYear('SB22.HalmPriceGain', core.firstYearOfTable - 3, newValue= 1.50)      # OBS: Gain-faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.

                elif 'f09' in scenId:   #  -50% biopris
                    core.setParmYear('SB22.FlisPriceGain', core.firstYearOfTable - 3, newValue= 0.50)      # OBS: Gain-faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.
                    core.setParmYear('SB22.HalmPriceGain', core.firstYearOfTable - 3, newValue= 0.50)      # OBS: Gain-faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.

                elif 'f10' in scenId:   #  +100% elpris
                    core.setParmYear('SB22.ElspotGain', core.firstYearOfTable - 3, newValue=+2.00)         # OBS: Faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.
                    
                elif 'f11' in scenId:   #  -50% elpris
                    core.setParmYear('SB22.ElspotGain', core.firstYearOfTable - 3, newValue=+0.50)         # OBS: Faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.
                    
                elif 'f12' in scenId:   #  Biomasse-afgift Flis 20 kr/GJ, halm +10 kr/GJ.
                    core.setParmYear('SB22.TaxEnergiFlis', core.firstYearOfTable - 3, newValue=+20.00)  # OBS: Faktoren er placeret i kolonnen svarende til 3 år før første år i tabellen.
                    core.setParmYear('SB22.TaxEnergiHalm', core.firstYearOfTable - 3, newValue=+10.00)  # OBS: Faktoren er placeret i kolonnen svarende til 4 år før første år i tabellen.

                elif 'f13' in scenId:   #  Laderate BHP-tanke øges 4 gange ift. nominelt 0.04 * CapQVak, svarende til ESV3-VAK (400 MWq / 2500 MWhq).
                    core.setParmDataU('MaVak',   'LoadRateVak', newValue=4.0 * 0.04)
                    core.setParmDataU('MaNVak1', 'LoadRateVak', newValue=4.0 * 0.04)
                    core.setParmDataU('MaNVak2', 'LoadRateVak', newValue=4.0 * 0.04)

                elif 'f30' in scenId:   # Plan B købspris for PtX-OV kr/MWhqo.
                    core.setParmFuelPriceU('MaNhpPtX', 'OV-PtX', 1.00 )
                elif 'f31' in scenId:   # Plan B købspris for PtX-OV kr/MWhqo.
                    core.setParmFuelPriceU('MaNhpPtX', 'OV-PtX', 25.00 )
                elif 'f32' in scenId:   # Plan B købspris for PtX-OV kr/MWhqo.
                    core.setParmFuelPriceU('MaNhpPtX', 'OV-PtX', 50.00 )
                elif 'f33' in scenId:   # Plan B købspris for PtX-OV kr/MWhqo.
                    core.setParmFuelPriceU('MaNhpPtX', 'OV-PtX', 75.00 )
                elif 'f34' in scenId:   # Plan B købspris for PtX-OV kr/MWhqo.
                    core.setParmFuelPriceU('MaNhpPtX', 'OV-PtX', 100.00 )


            else:
                raise ValueError(f'No initialization code for scenario {scenId}')

            core.wb.app.calculation = 'automatic'
            core.wb.app.calculate()
            core.wb.save()
            core.wb.app.quit()
            
            # Prepare jobs (worker functions)
            # if not justCreateInputs:
            logger.info(f'Spawning process for {scenName} job ...')
            #--- procs.append(Process(name=scenId, target=worker, args=(core.scenId, core.targetDir, core.resultDir)))
            procs.append(Process(name=scenId, target=worker, args=(core.scenName, core.targetDir, os.path.join(core.resultDir, scenId)) )) # scenId is used as subfolder name.
                
        # End of ... for scenId in scenList
            
        if justCreateInputs:
            for ip, proc in enumerate(procs):
                logger.debug(f'{ip=}, {procs[ip].name=}')
                
            logger.info('End of verification run\n')
            
        else:
            logger.info(f'Starting GAMS jobs: {nJobParallel=}, {nJob=}')
            for ip in range(nJobParallel):
                procs[ip].start()
                logger.info(f'Started process={procs[ip].pid} for {procs[ip].name}')
            
            nJobStarted = nJobParallel
            timer = time.perf_counter()
            jobNoToKill = 0
            while True:
                jobNoToKill = readInput(f'Enter number of job to terminate within {jobInterval} secs):', jobInterval ) 
                time.sleep(jobInterval)    # Let the terminal wait.
                
                # Start additional jobs if possible when running jobs have completed. 
                count = 0
                for ip in range(nJobStarted):
                    if ip == jobNoToKill - 1:   # jobNoToKill is base-1.
                        procs[ip].terminate()
                        procs[ip].join()        
                    if procs[ip].is_alive():
                        count += 1 
                
                if count < nJobParallel and (nJob - nJobStarted) > 0:
                    nJobStarted += 1
                    procs[nJobStarted-1].start()        
                    logger.info(f'Starting job[{procs[nJobStarted-1].name}] ...')
                    # // scenId = procs[nJobStarted-1].name
                    # // scenParms = scens[scenId]
                    # // scens[scenParms['_startTime'] = dt.datetime.now()
            
                # Print progress of gams jobs by inspecting GAMS listing file in reverse.
                timer = reportProgress(startTime, scens, printInterval, procs, core, nJobStarted, timer) 

                # Terminate loop if all jobs have completed.
                if not active_children():
                    break
            
            logger.info(f'Finished all selected {nJob} scenarios in {str(dt.timedelta(seconds=int(time.perf_counter()-startTime)))}')    
            #--- send_email('mbl@AddedValues.eu', 'Automail from {NAME}', 'Job completed')
            
    except Exception as ex:
        logger.critical(f'\nException occurred in {NAME}\n{ex=}\n', exc_info=True)
    
    finally:
        wb = core.wb
        try: 
            wb.close()
            wb.app.quit()
        except:
            pass
        finally:
            mec.shutdown(logger, f'{NAME} ended.')
            quit()



