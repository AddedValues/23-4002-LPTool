from typing import IO, Any
import sys
import os
import time
import datetime as dt
from   datetime import datetime, timedelta
import numpy as np
import pandas as pd
import xlwings as xw
# import plotly
# import plotly.express as px
# import plotly.graph_objects as go
# import dash
# from dash import Dash, html, dash_table, dcc, Output, Input, State
# import dash_bootstrap_components as dbc
# from dash.exceptions import PreventUpdate
import jobLib as jl
from   lpBase import LpBase

pd.options.display.max_columns = None

#region Setup job parameters

def setupJobParms(scenId: str):
    masterParms = dict()  # Key is parameter name, value is parameter value.
    defaultMasterParms = jl.JobSpec.getDefaultMasterParms()

    # Construct an arbitrary start timestamp of the planning horizon and derive hourBegin from it as to fetch historical data.
    timestampStart = dt.datetime(2024,1,25,0,0,0)
    deltaTime = timestampStart - dt.datetime(2023, 12, 31, 23, 0, 0) 
    hourBegin = deltaTime.days * 24

    # Create the master parameter dictionary.
    masterParms = {
        'Scenarios.ScenarioID'            : scenId,
        'Scenarios.LenRollHorizonOverhang': 72,
        'Scenarios.CountRollHorizon'      : 1,
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
    return masterParms


appConfig = {
    'pathRoot': 'C:\\GitHub\\23-4002-LPTool',
    'traceOps': False
    }

LpBase.setAppConfig(appConfig)
logger = LpBase.getLogger()

plantGroups = {'Ma': 'BHP', 'Ho': 'Holstebro', 'St': 'Struer'}

orderU = [  'MaNVak', 'MaVak', 'HoNVak', 'StVak', 'MaCool', 'MaCool2', 'MaAff1', 'MaAff2', 'MaBio', 'MaEk', 'MaNbk', 'MaNbKV', 'MaNEk', 'MaNhpAir', 'MaNhpPtX', 
            'HoNEk', 'HoNFlis', 'HoNhpAir', 'HoNhpArla', 'HoNhpBirn', 'HoNhpSew', 'HoGk', 'HoOk', 
            'StEk', 'StNEk', 'StNFlis', 'StNhpAir', 'StGk', 'StOk']


activePlants = ['MaNVak', 'MaVak', 'StVak', 'MaCool', 'MaCool2', 'MaAff1',
                'MaBio', 'MaEk', 'MaNbk', 'MaNhpAir',
                'HoNhpBirn', 'HoNhpSew', 'HoGk', 'HoOk', 
                'StEk', 'StGk', 'StOk']

symbolNames = [ 'u', 'upr', 'vak', 'OnUGlobal', 'TimeResol', \
                'Qf_L', 'QTf', 'PfNet', 'FuelQty', 'QfDemandActual_L', 'EVak_L', \
                'FuelCost', 'TotalCostU', 'TotalTaxUpr', 'StatsU', 'StatsTax']

scenId = 'm01s01u00r00f00'

#endregion Setup job parameters

performRun = False
if performRun:
    tbegin = time.perf_counter_ns()

    jobHandler = jl.JobHandler(description=None, pathRootDir=appConfig['pathRoot'], modelText=None)

    # Setup job specification
    # TODO - Fetch the parameters of the job specification.
    parms = setupJobParms(scenId)
    jobSpec = jl.JobSpec('name', 'desc', scenId, parms, appConfig['traceOps'])
    core: jl.CoreData = jobHandler.runJob(jobSpec)
    statsSolver = core.statsSolver
    if statsSolver['SolveStat'] == 1:
        logger.info(f'Optimization completed successfully.')    
    else:
        logger.error(f'Optimization failed with status SolveStat={statsSolver["SolveStat"]}.')
        sys.exit(1)
    tend = time.perf_counter_ns()
    print(f'Elapsed time executing model run: {(tend-tbegin)/1e9:.4f} seconds.')
else:
    core: jl.CoreData = jl.CoreData(scenId, appConfig['pathRoot'], appConfig['traceOps'])


#region Extracting data to show

# What is the reference for timestamps in the model? 
# Is it the time of the first record in the model?
# Convention: Timestamp represents the start of the time interval hence the first record is at time 0.

#%% Testing class StemData and ModelData
    
readStemData = False
readModelData = True

if readStemData:
    tbegin = time.perf_counter_ns()
    # Create StemData object
    logger.info('Reading StemData.')
    stemData = jl.StemData(os.path.join(core.targetDir, core.inFiles['input']))
    data = stemData.data
    tend0 = time.perf_counter_ns()
    if readStemData: print(f'Elapsed time reading stem data: {(tend0-tbegin)/1e9:.4f} seconds.')

if readModelData:
    modelData = jl.ModelData(scenId, pathFile=os.path.join(core.targetDir, core.outFiles['gdxout']))

    # Get time resolution for model time intervals.
    dfTimeResol = modelData['TimeResol']
    timeIncr = (dfTimeResol['value'] / 60).to_numpy()
    timeVec = np.cumsum(timeIncr) - timeIncr[0]
    
    # Pick available plants using the u symbol and the OnUGlobal symbol
    dfU = modelData['u']
    dfOnUGlobal = modelData['OnUGlobal']
    uAvail = dfOnUGlobal['u'].to_list()
    dfUpr = modelData['upr']

    # Remove columns of any plant dfUpr that are not available
    dfUpr = dfUpr[dfUpr['u'].isin(uAvail)]
    # Setup the display order of plants.
    orderU = [u for u in orderU if u in uAvail]

    # Fetch the records of Qf_L and create a pivot table
    dfQf_LRecs = modelData['Qf_L']

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
    dfQf_Lx = jl.ModelData.createPivot(dfQf_LRecs, indexName='tt', columnNames=['u'], attrName='value', fillna=True, fillTiny=True, createTimeColumn=True, timeVector=timeVec)
    
    # dfQf_Lavail nov contains a column name 'time' and a column for each plant that is available. Dimension 'tt' is used as index.
    # Pick only values of available production plants. 
    # Also, replace values of dfQf_Lavail that are less than 1E-12 with zero. The value 1E-14 is assigned within the GAMS model to ensure filled-in records.
    dfQf_L = dfQf_Lx[['time'] + uAvail]   # Reorder columns such that time is leftmost and drop columns other than plant values.

    # If any column of dfQf_Lavail ends with 'Cool', reverse the sign of the column values. Cooled heat is not delivered to the district heating system.
    for col in dfQf_L.columns:
        if 'Cool' in col:
            dfQf_L.loc[:,col] = -dfQf_L.loc[:,col] 

    # Create a column in dfQf_L that holds the timestamp composed of the now plus the time column.
    # CONVENTION: The time column holds the time interval index of the model. 
    timeOffset = datetime.fromisoformat('2024-01-15 00:00:00')
    dfQf_L['timestamp'] = [timeOffset + timedelta(hours=t) for t in dfQf_L['time']]

    # Sort columns of dfQf_L according to orderU and add the time column at the end.
    dfQf_L = dfQf_L[['time', 'timestamp'] + orderU]

    print(dfQf_L.head(20))

#endregion Extracting data to show