from email.policy import default
from typing import IO, Any
import sys
import os
import logging
import shutil
import glob 
import locale
import time
import datetime as dt
from datetime import datetime, timedelta
# import asyncio
import jobLib
import numpy as np
import pandas as pd
import xlwings as xw
import GdxWrapper as gw
import gams 
import gams.transfer as gtr
# import plotly
# import plotly.express as px
# import plotly.graph_objects as go
# import dash
# from dash import Dash, html, dash_table, dcc, Output, Input, State
# import dash_bootstrap_components as dbc
# from dash.exceptions import PreventUpdate

pd.options.display.max_columns = None

rootDir = 'C:\\GitHub\\23-4002-LPTool'
appPath = 'C:\\GitHub\\23-4002-LPTool\\App'

from jobSpec import JobSpec
from jobLib import CoreData, GamsData 
from lpBase import LpBase, JobResultKind
LpBase.setAppRootPath(appPath)
logger = LpBase.initLogger('MecLpTool')


#%% Functions

# import class JobSpec from file JobSpec.py located in folder ../App/Engine
# parms = JobSpec.getDefaultMasterParms()
# jobSpec = JobSpec('name', 'desc', parms)
# print(str(jobSpec))
# pass

def time2int(time: datetime) -> int:
    """ Converts a datetime object to an integer of kind 't'nnnn. """
    return int(time.strftime('%Y%m%d%H'+'00'))

def getGamsSymbolAsRecords(gamsData: gams.GamsJob, symbolName: str, attrName: str = 'level') -> pd.DataFrame:
    """ Extracts the records of a GAMS symbol as a DataFrame. """

    pathInputFolder = r'C:\GitHub\23-4002-LPTool\Master'
    pathGdxFile = os.path.join(pathInputFolder, 'MecLpMain.gdx')

    # See: https://www.gams.com/latest/docs/API_PY_GAMSTRANSFER_ADDITIONAL_TOPICS.html#PY_GAMSTRANSFER_GDX_READ

    m = gtr.Container(pathGdxFile)
    data = m.data

    parms = {p.name: p for p in m.getParameters()}
    pp: gtr.syms.container_syms._parameter.Parameter = parms['Qf_L']
    print(pp.summary)
    df = pp.records
    print(pp.records)
    df = pp.pivot('tt', 'u', 'value')
    print(df)

    vars = {p.name: p for p in m.getVariables()}
    vv: gtr.syms.container_syms._variable.Variable = vars['Qf']
    print(vv.summary)
    df = vv.records
    print('As records\n',vv.records.head(2))
    df = vv.pivot('tt', 'u', 'level')
    print('As table\n', df.head(2))

def setupJob(jobSpec: JobSpec, rootDir, logger) -> CoreData:
    """ Sets up the model prior to execution. """

    traceOps = False
    core = CoreData(jobSpec.scenId, rootDir, traceOps, logger) 

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

def getFileName(scenId: str, fnameOrig: str, fext: str) -> str:
    """ Returns the file name of the result file for scenario scen. """
    return f'{fnameOrig}_{scenId}{fext}'

def worker(core: CoreData) -> dict[str, float]:
    """
    Executes a GAMS job using folder workDir and copies the results to folder resultDir. 
    Returns a dictionary with the state of the execution (GAMS ModelState instance).
    """
    try:
        workDir = core.targetDir
        resultDir = os.path.join(core.resultDir, core.scenId)
        logger.debug(f'worker: {workDir=}, {resultDir=}')

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
        logger.info(f'Running GAMS job for scenario {core.scenId} ...')
        fout = open(os.path.join(workDir, core.outFiles['log']), 'w') 
        gamsJob.run(opt, output=fout)                               #--- gams_job.run(opt, output=sys.stdout)
        logger.info(f'GAMS job for scenario {core.scenId} completed.')

        # Read job status from GAMS in-memory database.
        # masterIter = int(gamsJob.out_db.get_parameter("MasterIter").first_record().value)
        # iterOptim =  int(gamsJob.out_db.get_parameter("IterOptim").first_record().value)
        # logger.debug(f'{masterIter=}, {iterOptim=}')
        m = gtr.Container(gamsJob.out_db)
        statsSolver: gtr.syms.container_syms._parameter.Parameter = m.data['StatsSolver']
        # print(statsSolver.summary)
        dfRecs = statsSolver.records
        dictStatsSolver = dict(zip(dfRecs['topicSolver'], dfRecs['value']))
        # print(dictStatsSolver)
                    
        # Create resultDir if it does not exist.
        if not os.path.exists(resultDir):
            logger.debug(f'worker: Creating {resultDir=}')
            os.mkdir(resultDir)
        else:
            # Delete existing results files, if any.
            logger.debug(f'worker: Removing files from {resultDir=}')
            files = glob.glob(os.path.join(resultDir, '*.*'))
            for f in files:
                os.remove(f)    

        # Copy some input and results files to new folder based on root folder resultDir. 
        logger.info(f'Copying files from {workDir=} to {resultDir=} ...')
        resultFiles = core.outFiles.values() 
        
        for file in resultFiles:
            logger.debug(f'Copying file={os.path.relpath(file)} to {os.path.relpath(resultDir)}')
            pathIn = os.path.join(workDir, file)
            if (os.path.exists(pathIn)):
                fname, fext = os.path.splitext(file)
                pathOut = os.path.join(resultDir, getFileName(core.scenId, fname, fext))
                shutil.copy2(pathIn, pathOut)
                
        # Remove temporary folders
        folders = glob.iglob(os.path.join(workDir, '225*')) 
        for folder in folders:
            shutil.rmtree(folder) 
        
    except Exception as ex:
        logger.critical(f'\nException occurred in {__name__}.worker on {core.scenId=}\n{ex=}\n', exc_info=True)
        raise
    finally:
        if fout is not None:
            fout.close()
        
    return dictStatsSolver

#%% 

allPlants = [   'MaNVak', 'MaVak', 'HoNVak', 'StVak', 'MaCool', 'MaCool2', 'MaAff1', 'MaAff2', 'MaBio', 'MaEk', 'MaNbk', 'MaNbKV', 'MaNEk', 'MaNhpAir', 'MaNhpPtX', 
                'HoNEk', 'HoNFlis', 'HoNhpAir', 'HoNhpArla', 'HoNhpBirn', 'HoNhpSew', 'HoGk', 'HoOk', 
                'StEk', 'StNEk', 'StNFlis', 'StNhpAir', 'StGk', 'StOk']

activePlants = ['MaNVak', 'MaVak', 'StVak', 'MaCool', 'MaCool2', 'MaAff1',
                'MaBio', 'MaEk', 'MaNbk', 'MaNhpAir',
                'HoNhpBirn', 'HoNhpSew', 'HoGk', 'HoOk', 
                'StEk', 'StGk', 'StOk']

scenId = 'm01s01u00r00f00'

performRun = True

if performRun:
    masterParms = dict()  # Key is parameter name, value is parameter value.
    defaultMasterParms = JobSpec.getDefaultMasterParms()

    # Construct an arbitrary start timestamp of the planning horizon and derive hourBegin from it as to fetch historical data.
    timestampStart = dt.datetime(2024,1,25,0,0,0)
    deltaTime = timestampStart - dt.datetime(2023, 12, 31, 23, 0, 0) 
    hourBegin = deltaTime.days * 24

    # Create the master parameter dictionary.
    masterParms = {
            'Scenarios.ScenarioID'            : scenId,
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

    jobSpec = JobSpec(scenId, 'desc', scenId, masterParms)

    core: CoreData = setupJob(jobSpec, rootDir, logger)

    statsSolver = worker(core)

    if statsSolver['SolveStat'] == 1:
        logger.info(f'Optimization completed successfully.')    
    else:
        logger.error(f'Optimization failed with status SolveStat={statsSolver["SolveStat"]}.')
        sys.exit(1)
    pass


#%% Classes StemData and ModelData

class StemData():
    global logger

    def __init__(self, filePath: str = 'MecLPinput.xlsm'):
        """ 
        Initializes the StemData object. 
        Reads data from the excel file and stores it in a dictionary.
        A lazy implementation is not used due to the excessive load time of the Excel file.
        """

        # self.path = os.path.join('C:\\GitHub\\23-4002-LPTool\\Data\\MockUI', fileName)
        self.path = filePath #--- os.path.join('C:\\GitHub\\23-4002-LPTool\\Master', fileName)
        if not os.path.exists(self.path):
            print(f'Error: File {self.path} does not exist.')

        self.data = self.read_excel_data()

    def read_excel_data(self) -> dict[str, pd.DataFrame]:
        """
        Reads data from the excel file and returns a dictionary with the data.
        """
        # Read data from excel file
        data = dict()  # Key is table name, value is dataframe.
        xlapp = xw.App(visible=False, add_book=False)
        try:
            wb = xlapp.books.open(self.path, read_only=True)
            data['LpTables'] = wb.sheets['LPspec'].range('tblLpTables').options(pd.DataFrame, expand='table', index=False).value
            lpTables = data['LpTables']

            for i in range(len(lpTables)):
                tableName = lpTables.loc[i,'TableName']
                sheetName = lpTables.loc[i,'SheetName']
                rangeName = lpTables.loc[i,'RangeName']
                useIndex = lpTables.loc[i,'UseIndex']
                rowDim = int( lpTables.loc[i,'RowDim']) if useIndex else 0  
                colDim = int(lpTables.loc[i,'ColDim'])
                StemData._logger.info(f'Reading table {tableName} from sheet {sheetName} with range {rangeName}.')
                # logger.info(f'UseIndex={useIndex}, RowDim = {rowDim}, ColDim = {colDim}.')
                df = wb.sheets[sheetName].range(rangeName).options(pd.DataFrame, expand='table', index=rowDim, header=colDim).value
                data[tableName] = df
            wb.close()
            
        except Exception as e:
            StemData._logger.exception(f'Error reading excel file {self.path}.', exc_info=True)
        finally:
            xlapp.quit()

        return data

class ModelData(jobLib.GamsData):
    """ Accesses data of a GAMS model in lazy fashion (on-demand)."""
    global logger

    def __init__(self, scenId:str= None, db: gams.GamsDatabase = None, pathFile:str = None, logger: logging.Logger = None):
        """ Initializes the ModelData object. """

        self.scenId = scenId

        if db is None and pathFile is None:
            raise ValueError('Either db or pathFile must be given.')
        
        if db is None:
            if not os.path.exists(pathFile):
                raise ValueError(f'File "{pathFile}" does not exist.')
            self.pathFile = pathFile
            self.ws = gams.GamsWorkspace()
            self.db = self.ws.add_database_from_gdx(self.pathFile, database_name=self.scenId)
        else:
            self.db = db
            self.name = db.name

        super().__init__(self.db, keepData = True, logger=logger)

        # self.gamsData = GamsData(self.db, logger)
        # self.Gsymbols = dict()  # Key is symbol name in lower case, value is GSymbolProxy instance.
        # self.data = dict()      # Key is symbol name in lower case, value is dataframe of records.
        # self.gw = gw.GdxWrapper(name='ModelData', pathFile=self.path, loggerName=logger.name)
        return
    
        #region Abondoned code
        # def readSymbolAsDataFrame(self, symbolName: str, attrName: str = 'level') -> pd.DataFrame:
            # """
            # Reads data of a single GAMS symbol from the gdx file and returns a dataframe with the data.
            # """
            # # Read symbol data from gdx file
            # gsym = gw.GSymbolProxy(symbolName, self.gw)
            # symbolData = self.gw.getRecords(symbolName.lower(), attrName)
            # if symbolData is None:
            #     return None
            # self.Gsymbols[symbolName.lower()] = gsym
            # self.data[symbolName.lower()] = symbolData
            # return symbolData

        # def __getitem__(self, symbolName: str) -> pd.DataFrame:
        #     """ Returns the dataframe with the given key. Lazy implementation."""
        #     # See: https://www.kdnuggets.com/2023/03/introduction-getitem-magic-method-python.html
            
        #     if symbolName.lower() not in self.Gsymbols:
        #         symbolData = self.readSymbolAsDataFrame(symbolName)
        #         if symbolData is None:
        #             logger.error(f'Symbol of name {symbolName} was not found.')
        #             return None
        #         self.data[symbolName] = symbolData

        #     return self.data[symbolName.lower()]
        #endregion Abondoned code
        

    def createPivot(dfRecs: pd.DataFrame, indexName: str, columnNames: list[str], attrName: str,
                    fillna: bool = True, createTimeColumn: bool = False, timeVector: list[float] = None) -> pd.DataFrame:
        """
        Creates a pivot table from a DataFrame of records e.g. of a GAMS symbol like parameter, variable, equation.
        Each column of dfRecs holds the values of a defining dimension of the symbol.
        One column holds the attribute of the symbol e.g. value, level, marginal, lower, upper.
        
        Parameters
        ----------
        dfRecs : pd.DataFrame
            Holds the records part of which will be used to compose the pivot table
        indexName : str
            Name of the column in dfRecs that should be index of the pivot table.
        columnNames : list[str]
            List of names of columns in dfRecs to constitute the columns of the pivot table.
            If columnNames has two or more members, the columns of the pivot table will be a 
            multiindex i.e. a tuple of each dimension's member value (name).
        valueName : str
            Name of the column in dfRecs whose values will fill the body of the pivot table.
        fillna : boolean, optional
            If True (default), NaN-values will be converted to zeros.
        createTimeColumn : boolean, optional
            If True (default) and index of pivot the column of name 'tt', the numeric part of 
            the index values will be converted to integers and stored in a new column named 'time',
            and the entire pivot table sorted ascendingly by this column.

        Raises
        ------
        ValueError
            Either one of indexName, columnNames or valueName was not found in dfRecs.

        Returns
        -------
        pivot : DataFrame
            The pivot table

        """
        if indexName is not None and not indexName in dfRecs.columns:
            raise ValueError(f'{indexName=} not found in columns of DataFrame dfRecs')
        
        for col in columnNames:
            if not col in dfRecs.columns:
                raise ValueError(f'Column {col=} not found in columns of DataFrame dfRecs')
        
        if not attrName in dfRecs.columns:
            # Consider a misnomer of attrName where 'level' is used by variables and equations, and 'value' by parameters.
            if attrName == 'level' and 'value' in dfRecs.columns:
                attrName = 'value'
            elif attrName == 'value' and 'level' in dfRecs.columns:
                attrName = 'level'
            else:
                raise ValueError(f'{attrName=} not found in columns of DataFrame dfRecs')
        
        dfPivot = dfRecs.pivot(index=indexName, columns=columnNames, values=attrName)
        
        if fillna:
            dfPivot = dfPivot.fillna(0.0)
            
        if createTimeColumn:
            # Assuming the index of pivot has members of kind 't'nnnn where n is a digit.
            if dfPivot.index.name != 'tt':
                raise ValueError(f'Pivot must have index of name "tt", but "{dfPivot.index.name}" was found')
                
            if timeVector is None:
                # Assuming equidistant time steps of 1 hour.
                dfPivot['time'] = [0] + np.ones(len(dfPivot - 1)) * 60 
            else:
                dfPivot['time'] = [timeVector[int(tt[1:]) - 1] for tt in dfPivot.index]

            newOrder = ['time'] + list(dfPivot.columns[:-1])
            dfPivot = dfPivot[newOrder]
            dfPivot = dfPivot.sort_values(by=['time'])
        
        return dfPivot

#region Extracting data to show

# What is the reference for timestamps in the model? 
# Is it the time of the first record in the model?
# Convention: Timestamp represents the start of the time interval hence the first record is at time 0.

#%% Testing class StemData and ModelData
    
readStemData = False
readModelData = True

if readStemData or readModelData:
    tbegin = time.perf_counter_ns()
    if readStemData:
        # Create StemData object
        logger.info('Reading StemData.')
        stemData = StemData()
        data = stemData.data

    tend0 = time.perf_counter_ns()
    print(f'Elapsed time reading stem data: {(tend0-tbegin)/1e9:.4f} seconds.')

    if readModelData:
        # Create ModelData object
        modelData = ModelData(scenId, pathFile=os.path.join(core.targetDir, core.outFiles['gdxout']), logger=logger)
        symbolNames = [ 'u', 'upr', 'vak', 'OnUGlobal', 'TimeResol', \
                        'Qf_L', 'QTf', 'PfNet', 'FuelQty', 'QfDemandActual_L', 'EVak_L', \
                        'FuelCost', 'TotalCostU', 'TotalTaxUpr', 'StatsU', 'StatsTax']
        for symbolName in symbolNames:
            # logger.info(f'Reading symbol {symbolName}.')
            df = modelData[symbolName]
            # print(df)

    tend1 = time.perf_counter_ns()
    print(f'Elapsed time reading model data: {(tend1-tend0)/1e9:.4f} seconds.')

    # for symbolName in symbolNames:
    #     logger.info(f'Retrieving symbol {symbolName}.')
    #     df = modelData[symbolName]

    tend2 = time.perf_counter_ns()
    print(f'Elapsed time in total: {(tend2-tbegin)/1e9:.4f} seconds.')

pass

#%% Read data from gdx file 

if readModelData:
    # Pick available plants using the u symbol and the OnUGlobal symbol
    dfTimeResol = modelData['TimeResol']
    timeIncr = (dfTimeResol['value'] / 60).to_numpy()
    timeVec = np.cumsum(timeIncr) - timeIncr[0]
    
    dfU = modelData['u']
    dfOnUGlobal = modelData['OnUGlobal']
    uAvail = dfOnUGlobal['u'].to_list()
    dfUpr = modelData['upr']

    # Remove columns of dfUpr that are not available
    dfUpr = dfUpr[dfUpr['u'].isin(uAvail)]
    orderU = ['MaNVak', 'MaVak', 'HoNVak', 'StVak', 'MaCool', 'MaCool2', 'MaAff1', 'MaAff2', 'MaBio', 'MaEk', 'MaNbk', 'MaNbKV', 'MaNEk', 'MaNhpAir', 'MaNhpPtX', 
        'HoNEk', 'HoNFlis', 'HoNhpAir', 'HoNhpArla', 'HoNhpBirn', 'HoNhpSew', 'HoGk', 'HoOk', 
        'StEk', 'StNEk', 'StNFlis', 'StNhpAir', 'StGk', 'StOk']

    # Setup the display order of plants.
    orderU = [u for u in orderU if u in uAvail]
    plantGroups = {'Ma': 'BHP', 'Ho': 'Holstebro', 'St': 'Struer'}


    # Fetch the records of Qf_L and create a pivot table
    dfQf_LRecs = modelData['Qf_L']
    # print(dfQf_LRecs.head())

    #region Abandoned code working on records of Qf_L
    # df = dfQf_LRecs.copy(deep=True)
    # df['time'] = [timeVec[int(tt[1:]) - 1] for tt in df.tt]
    # # df = df.sort_values(by=['time'])
    # # print(df.head())
    # # print(timeVec)
    # # print(timeIncr)

    # # Drop any row of df where the value of the column 'u' is not in uAvail
    # df = df[df['u'].isin(uAvail)]

    # # Also, replace values of df that are equal to 1E-14 with zero. The value 1E-14 is assigned within the GAMS model to ensure filled-in records.  
    # df = df.replace(1E-14, 0.0)
    # # print(df.head(20))

    # orderU = ['MaNVak', 'MaVak', 'HoNVak', 'StVak', 'MaCool', 'MaCool2', 'MaAff1', 'MaAff2', 'MaBio', 'MaEk', 'MaNbk', 'MaNbKV', 'MaNEk', 'MaNhpAir', 'MaNhpPtX', 
    #           'HoNEk', 'HoNFlis', 'HoNhpAir', 'HoNhpArla', 'HoNhpBirn', 'HoNhpSew', 'HoGk', 'HoOk', 
    #           'StEk', 'StNEk', 'StNFlis', 'StNhpAir', 'StGk', 'StOk']
    # orderU = [u for u in orderU if u in uAvail]
    # # print(orderU)

    # plantGroups = {'Ma': 'BHP', 'Ho': 'Holstebro', 'St': 'Struer'}
    # df['plantGroup'] = [plantGroups[u[:2]] for u in df['u']]
    # # print(df.head(20))

    # # Drop any row of df where the value of the column 'u' contains Cool. Cooled heat is not delivered to the district heating system.
    # df = df[~df['u'].str.contains('Cool')]
    # print(df.head(20))  

    # # Extract unique values of the column 'u' and sort them according to the order in orderU.
    # uUnique = df['u'].unique()
    # uUnique = [u for u in orderU if u in uUnique]
    # # print(f'{uUnique=}')

    # # # Sort df according to the order in column time, next to the order of orderU.
    # # df = df.sort_values(by=['time', 'u'])
    #endregion Abandoned code working on records of Qf_L

    # print(timeVec)
    print(dfQf_LRecs.head(10))
    dfQf_Lx = ModelData.createPivot(dfQf_LRecs, indexName='tt', columnNames=['u'], attrName='value', createTimeColumn=True, timeVector=timeVec)
    
    # dfQf_Lavail nov contains a column name 'time' and a column for each plant that is available. Dimension 'tt' is used as index.
    # Pick only values of available production plants. 
    # Also, replace values of dfQf_Lavail that are less than 1E-12 with zero. The value 1E-14 is assigned within the GAMS model to ensure filled-in records.
    dfQf_L = dfQf_Lx[['time'] + uAvail]   # Pick only columns of available plants and the time column.
    # dfQf_L = dfQf_L.mask(dfQf_L.loc[:,:] < 1E-12 ,0.0, inplace=False)
    dfQf_L = dfQf_L.replace(1E-14, 0.0)


    # # If any column of dfQf_Lavail ends with 'Cool', reverse the sign of the column values. Cooled heat is not delivered to the district heating system.
    for col in dfQf_L.columns:
        if 'Cool' in col:
            dfQf_L.loc[:,col] = -dfQf_L.loc[:,col] 

    # Create a column in dfQf_L that holds the timestamp composed of the now plus the time column.
    timeOffset = datetime.fromisoformat('2024-01-08 00:00:00')
    dfQf_L['timestamp'] = [timeOffset + timedelta(hours=t) for t in dfQf_L['time']]

    # Sort columns of dfQf_L according to orderU and add the time column at the end.
    dfQf_L = dfQf_L[['time', 'timestamp'] + orderU]

    print(dfQf_L.head(20))

#endregion Extracting data to show