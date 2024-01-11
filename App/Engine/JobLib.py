
import os 
import glob
import shutil
import logging
import string
import numpy as np
import pandas as pd
import xlwings as xw

from App.MockUI.lpBase import LpBase

ZERO : int = 0
ONE  : int = 1
TWO  : int = 2

CONST: str = 'const' # Assign the packed (aggregated) value of the block to the unpacked value.
MEAN : str = 'mean'  # Assign the average of the block to the unpacked value.

MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAJ', 'JUN', 'JUL', 'AUG', 'SEP', 'OKT', 'NOV', 'DEC', 'ÅR']

LETTERS = string.ascii_uppercase


class ExcelTable():

    @staticmethod
    def numberToLetters(n: int):
        nlevel1 = (n-1) % len(LETTERS)
        nlevel2 = (n-1) // len(LETTERS)
        if nlevel2 > len(LETTERS):
            nlevel3 = nlevel2 // len(LETTERS)
            nlevel2 -= nlevel3 * len(LETTERS)
        else:
            nlevel3 = 0
            
        address = LETTERS[nlevel1]
        if nlevel2 > 0:
            address = LETTERS[nlevel2 - 1] + address
        if nlevel3 > 0:
            address = LETTERS[nlevel3 - 1] + address
            
        return address

    @staticmethod
    def lettersToNumber(address: str):
        address = address.upper()
        n = 0
        for i, c in enumerate(address):
            n += (ord(c) - ord('A') + 1) * 26 ** (len(address) - i - 1)
        return n


    def convertExcelAddressToIndices(addr: str) -> tuple[int,int]:
        """ Converts an absolute Excel address (using $) to numerical indices (base 1). """
        
        parts = addr.split('$')[1:]
        icolBase1 = ExcelTable.lettersToNumber(parts[0])
        irowBase1 = int(parts[1])
        return (irowBase1, icolBase1)
    
    @staticmethod
    def convertIndicesToExcelAddress(irowBase1: int, icolBase1: int) -> str:
        """ Converts numerical indices (base 1) to an absolute Excel address (using $). """
        
        addr = f'${ExcelTable.numberToLetters(icolBase1)}${irowBase1}'
        return addr

    def __init__(self, sheet: xw.Sheet, tblName: str, logger: logging.Logger = None):
        """ 
        Reads a table from sheet and stores it as a dataframe. 
        Note: The address is the upper left and lower right corners of the table including headers.
        """
        self.sheet = sheet
        self.tblName = tblName
        self.logger = logger if logger is not None else logging.getLogger(__name__)

        # Load without index as a particular column will be used as index.
        self.df = sheet.range(tblName).options(pd.DataFrame, header=True, index=False).value
        
        # Excel address is absolute (using $) and comprises upper left and lower right corner of table.
        self.address = sheet.range(tblName).address
        (upperLeft, lowerRight) = self.address.split(':')  
        self.ulAddr = ExcelTable.convertExcelAddressToIndices(upperLeft)
        self.lrAddr = ExcelTable.convertExcelAddressToIndices(lowerRight)
        return
    
    def __str__(self):
        return f'sheet={self.sheet.name}, range={self.tblName} at {self.address}'

    def getCellAddr(self, rowName: str, colName: str, lookupCol: str) -> tuple[int,int]:
        """ Returns the row and column indices (base-1) of the cell specified by rowName  and colName."""
        
        # Find the row and column indices (base-1) relative to the table's upper left corner.
        try:
            hit = self.df[lookupCol] == rowName
            if hit is None or len(hit) == 0:
                raise ValueError(f'Row name {rowName} not found in column {lookupCol} of table {self.tblName}')
            
            irowBase1 = (self.df[self.df[lookupCol] == rowName].index)[0] + 2 # Add 2 to compensate for headers and Python's base-0 indexing.
            icolBase1 = self.df.columns.get_loc(colName) + 1
            irowBase1 = irowBase1 + self.ulAddr[0] - 1     
            icolBase1 = icolBase1 + self.ulAddr[1] - 1
        except Exception as ex:
            self.logger.error(f'Error in getCellAddr: {ex}')
            raise ex
        return (irowBase1, icolBase1)

class CoreData():
    """ This class handles operations on input files and in particular setting of parameters within the Excel input file. """

    def __init__(self, scenId: str, rootDir: str, logger: logging.Logger = None):
        self.scenId  = scenId
        self.rootDir = rootDir
        self.logger  = logger if logger is not None else LpBase.getLogger()
        
        self.inFiles = {'main.gms': 'MecLpMain.xlsb', 'gpr': 'MEC.gpr', 'bat': 'CleanUpPre.bat', \
                        'options': 'GamsCmdlineOptions.txt', 'inc': 'options.inc', 'output': None, 'timeAggr': 'MECTidsAggregering.xlsx'}
        self.outFiles = {'main.gms': 'MecLpInput.xlsb', 'gdxout': 'MecLpMain.gdx', 'stats.gdx': 'JobStats.gdx', 'listing': '_gams_py_gjo0.lst', 'log': 'MecLpMain.log' }

        self.sourceDir = os.path.join(rootDir, 'Master')          # Path of master files (source, input data)
        self.workDir   = os.path.join(rootDir, 'WorkDir')         # Root folder of put new folders for each job    
        self.resultDir = os.path.join(rootDir, 'Results')         # Root folder to put results
        
        # Create new folder for each gams job.
        self.scenName = f'Scen_{self.scenId}'
        self.targetDir = os.path.join(self.workDir, self.scenName)

        self.period1 = 2019    
    
    @property
    def firstYearOfTable(self) -> int:
        """ Returns the first year of the table. Use firstYear to get the first year of the scenario. """
        return self.getPeriodAsYear(1)
                
    @property

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
        self.logger.info(f'Copying input files to {self.targetDir} ...')
        if os.path.exists(self.targetDir):
            # Remove any file residing in folder targetDir.
            self.logger.info(f'Removing files from working directory: {self.targetDir}')
            allFiles = glob.glob(os.path.join(self.targetDir, '*.*'))
            try:
                for filePath in allFiles:
                    os.remove(filePath)
            except Exception as ex:
                self.logger.warning(f'Unable to remove file: {filePath}\n{ex=}', exc_info=True)
        else:
            self.logger.info(f'Creating working directory: {self.targetDir}')
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

            for file in self.inFiles.values():
                if file is not None:
                    shutil.copy2(os.path.join(self.sourceDir, file), self.targetDir)

            # shutil.copy2(os.path.join(self.sourceDir, 'MEC.gpr'),                 self.targetDir)
            # shutil.copy2(os.path.join(self.sourceDir, 'MecLpInput.xlsm'),         self.targetDir)    
            # shutil.copy2(os.path.join(self.sourceDir, 'CleanUpPre.bat'),          self.targetDir)    
            # shutil.copy2(os.path.join(self.sourceDir, 'GamsCmdlineOptions.txt'),  self.targetDir)
            # shutil.copy2(os.path.join(self.sourceDir, 'options.inc'),             self.targetDir)        
            # shutil.copy2(os.path.join(self.sourceDir, 'MECMasterOutput.xlsm'),    self.targetDir)          
            # shutil.copy2(os.path.join(self.sourceDir, 'MECTidsAggregering.xlsx'), self.targetDir)   

        else:
            shutil.copy2(os.path.join(self.sourceDir, self.inFiles['input']),      self.targetDir)    
        
        return
    
    def copyResultFiles(self, scen):
        # Copy results file to new folder
        #--- logger.info('Copying result files for {scen=} ...')
        # resultFiles = ['MecInput.xlsm', '_gams_py_gjo0.lst', 'MecLpMain.gdx']
        # for file in resultFiles:
        for file in self.outFiles.values():
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
        self.wb = xlapp.books.open(os.path.join(self.targetDir, self.inFiles['input']))
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
        self.logger.info(f'Reading scenarios from {self.wb.name} ...')
        self.etMaster    = ExcelTable(self.shMaster, 'tblScenMasterAll')
        self.etPeriods   = ExcelTable(self.shPeriod, 'tblScenPeriodAll')
        self.etYears     = ExcelTable(self.shYear,   'tblScenYearAll')
        self.etDataU     = ExcelTable(self.shDataU,  'tblDataU')
        self.etFuelPrice = ExcelTable(self.shDataU,  'tblFuelPriceU')
        self.etChp       = ExcelTable(self.shChp,    'tblCHP')

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
                    self.logger.info(f'setParmMaster {fullName} to {newValue}') 
                    sheet.range(cell).value = newValue
                elif opr == 'add':
                    self.logger.info(f'setParmMaster adds {newValue} to {fullName}={existValue} yielding {existValue + newValue}') 
                    sheet.range(cell).value += newValue
                elif opr == 'sub':
                    self.logger.info(f'setParmMaster subtract {newValue} from  {fullName}={existValue} yielding {existValue - newValue}') 
                    sheet.range(cell).value -= newValue
                elif opr == 'mult':
                    self.logger.info(f'setParmMaster multiplies  {newValue} onto {fullName}={existValue} yielding {existValue * newValue}') 
                    sheet.range(cell).value *= newValue
            else:
                self.logger.info(f'setParmMaster {fullName} to {newValues}') 
                sheet.range(cell).value = newValues
                
        except Exception as ex:
            self.logger.critical(f"Exception occurred in setParmMaster:\n{ex=}\n{sheet.name=}: Parm.{fullName=}, {irowBase1=}\n", exc_info=True)
            return ex

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
                self.logger.info(f'setParmYear {fullName} to {newValue}') 
                sheet.range(cell).value = newValue
            else:
                self.logger.info(f'setParmYear {fullName} to {newValues}') 
                sheet.range(cell).value = newValues
                
        except Exception as ex:
            self.logger.critical("Exception occurred in setParmYear:\n{ex=}\n{sheet.name=}: Parm.{fullName=}, {iColYear=}\n", exc_info=True)
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
            self.logger.info(f'set CHP.{plantName}:{attrName} to {newValue} at {cell=}') 
            sheet.range(cell).value = newValue
        except Exception as ex:
            self.logger.critical("Exception occurred in setParmChp: {self.shChp.name=}: {plantName=}:{attribute=}\n{ex=}\n", exc_info=True)
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
            self.logger.info(f'set DataU.{plantName}:{attrName} to {newValue} at {cell=}') 
            sheet.range(cell).value = newValue
        except Exception as ex:
            self.logger.critical("Exception occurred in setParmDataU: {self.shDataU.name=}: {plantName=}:{attribute=}\n{ex=}\n", exc_info=True)
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
            self.logger.info(f'set FuelPriceU.{plantName}:{fuelName} to {newValue} at {cell=}') 
            sheet.range(cell).value = newValue
        except Exception as ex:
            self.logger.critical("Exception occurred in setParmFuelPriceU: {self.shDataU.name=}: {plantName=}:{attribute=}\n{ex=}\n", exc_info=True)
            return ex
        
        return 

    def setDefaultParms(self, iMaster: int, onTimeAggr: int = +2, onDuplicate: int = 0, \
                        activeExisting: bool = True, activeNew: bool = False, activeOV: bool = False) -> None:
        """ Sets up default values of rarely changed parameters. """
        
        self.iMaster = iMaster
        self.onTimeAggr = onTimeAggr
        # self.onDuplicate = onDuplicate
        # self.masterIterMax = masterIterMax
        self.lenRHOverhang = 10 if (self.onTimeAggr != 0) else 72  # Length of RH discarded after optimization of each RH.

        self.shMaster.range('ActualMasterScen').value = self.iMaster      # Set master scenario.

        # Kørselsparametre
        self.setParmMaster('Scenarios.ScenarioID',              newValue = self.getScenIdAsNum(self.scenId))
        # self.setParmMaster('Scenarios.DumpPeriodsToGdx',        newValue = 2)
        self.setParmMaster('Scenarios.DurationPeriod',          newValue = 8760)
        self.setParmMaster('Scenarios.LenRollHorizonOverhang',  newValue = self.lenRHOverhang)
        self.setParmMaster('Scenarios.OnDuplicatePeriods',      newValue = self.onDuplicate)
        self.setParmMaster('Scenarios.OnTimeAggr',              newValue = self.onTimeAggr) 
        
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
        
        # Årsparametre
        pass
        
        return
