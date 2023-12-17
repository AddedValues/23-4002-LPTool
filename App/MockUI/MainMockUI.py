"""
This is the main file for the MockUI-app. 
MockUI is a mockup of the UI for the final product.
See https://codegym.cc/da/groups/posts/da.232.solid-fem-grundlggende-principper-for-klassedesign-i-java for a discussion of SOLID principles.
"""

from email import header
from math import log
from re import A
from turtle import mode
from typing import IO, Any
import logging
import sys
import os
import shutil
import locale
import time
from datetime import datetime, timedelta
import asyncio
from venv import create
import numpy as np
import pandas as pd
# import pyxlsb
import xlwings as xw
import GdxWrapper as gw
from dash import Dash, html, dash_table, dcc, callback, Output, Input
import dash_bootstrap_components as dbc
import plotly.express as px
import plotly.graph_objects as go


global logger, pathRoot
logger: logging.Logger = None

def setupLogger(logfileName: str) -> logging.Logger:
    global logger
    locale.setlocale(locale.LC_TIME, 'da_DK.UTF-8')

    # Setup logger(s): Levels are: DEBUG, INFO, WARNING, ERROR, CRITICAL. See https://realpython.com/python-logging/
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

    # Check if log file already exists. If so, rename it adding a timestamp.
    # if os.path.isfile(f'{logfileName}.log'):
    #     timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
    #     shutil.copyfile(f'{logfileName}.log', os.path.join('Logs', f'{logfileName}_{timestamp}.log'))

    logfile_handler = logging.FileHandler(filename=f'{logfileName}.log', mode='w', encoding='utf-8', delay=False, errors='ignore')
    stdout_handler  = logging.StreamHandler(stream=sys.stdout)
    logfile_handler.level = logging.DEBUG
    stdout_handler.level = logging.INFO
    handlers = [logfile_handler, stdout_handler]

    logging.basicConfig(
        level=logging.DEBUG, 
        format='[%(asctime)s] {%(filename)s:%(lineno)d} %(levelname)s - %(message)s',
        datefmt='%y-%b-%d %H.%M.%S',
        handlers=handlers
    )

    logger = logging.getLogger(logfileName)  

    return logger

# %% Observer pattern sample

#region Observer pattern   
from abc import ABC, ABCMeta, abstractmethod

class IObservable(metaclass=ABCMeta):
    @staticmethod
    @abstractmethod
    def subscribe(observer):
        """ The subscribe method must be implemented by all classes that implement this interface. """
        pass

    @staticmethod
    @abstractmethod
    def unsubscribe(observer):
        """ The unsubscribe method must be implemented by all classes that implement this interface. """
        pass

    @staticmethod
    @abstractmethod
    def notify(observer):
        """ The notify method must be implemented by all classes that implement this interface. """
        pass

class Subject(IObservable):
    def __init__(self, name: str):
        self.name = name
        self.observers = set()
    def subscribe(self, observer):
        self.observers.add(observer)
        print(f'{observer} subscribed to {self}')

    def unsubscribe(self, observer):
        self.observers.remove(observer)
        print(f'{observer} unsubscribed from {self}')

    def notify(self, *args, **kwargs):
        for observer in self.observers:
            observer.notify(*args, **kwargs)

    def __str__(self):
        return f'Subject {self.name}'

class IObserver(metaclass=ABCMeta):
    @staticmethod
    @abstractmethod
    def notify(self, *args, **kwargs):
        """ The notify method must be implemented by all classes that implement this interface. """
        pass

class Observer(IObserver):
    def __init__(self, observable: IObservable, name: str):
        self.name = name
        observable.subscribe(self)

    def notify(self, observable, *args, **kwargs):
        print(f'Observer {self.name} received: {args} {kwargs}')

    def __str__(self):
        return f'Observer {self.name}'
    
subject = Subject('Subject-1')
observer1 = Observer(subject, 'Observer-1')
observer2 = Observer(subject, 'Observer-2')
subject.notify(f'hello observers', [1,2,3], {'a':1, 'b':2})
subject.unsubscribe(observer1)
subject.unsubscribe(observer2)
pass    
#endregion Observer pattern   

#%%        
class StemData():

    def __init__(self, fileName: str = 'MecLPinput.xlsm'):
        """ Initializes the StemData object. """

        # self.path = os.path.join('C:\\GitHub\\23-4002-LPTool\\Data\\MockUI', fileName)
        self.path = os.path.join('C:\\GitHub\\23-4002-LPTool\\Master', fileName)
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
                logger.info(f'Reading table {tableName} from sheet {sheetName} with range {rangeName}.')
                # logger.info(f'UseIndex={useIndex}, RowDim = {rowDim}, ColDim = {colDim}.')
                df = wb.sheets[sheetName].range(rangeName).options(pd.DataFrame, expand='table', index=rowDim, header=colDim).value
                data[tableName] = df
            wb.close()
            
        except Exception as e:
            print(e)
            print(f'Error reading excel file {self.path}.')
        finally:
            xlapp.quit()

        return data
   
class ModelData():

    def __init__(self, fileName: str = 'MecLpMain.gdx'):
        """ Initializes the ModelData object. """
        global logger
        # self.path = os.path.join('C:\\GitHub\\23-4002-LPTool\\Data\\MockUI', fileName)
        self.path = os.path.join('C:\\GitHub\\23-4002-LPTool\\Master', fileName)
        if not os.path.exists(self.path):
            raise ValueError(f'File {self.path} does not exist.')

        self.Gsymbols = dict()  # Key is symbol name in lower case, value is GSymbolProxy instance.
        self.data = dict()      # Key is symbol name in lower case, value is dataframe of records.
        self.gw = gw.GdxWrapper(name='ModelData', pathFile=self.path, loggerName=logger.name)
        return

    def readSymbolAsDataFrame(self, symbolName: str, attrName: str = 'level') -> pd.DataFrame:
        """
        Reads data of a single GAMS symbol from the gdx file and returns a dataframe with the data.
        """
        # Read symbol data from gdx file
        gsym = gw.GSymbolProxy(symbolName, self.gw)
        symbolData = self.gw.getRecords(symbolName.lower(), attrName)
        if symbolData is None:
            return None
        
        self.Gsymbols[symbolName.lower()] = gsym
        self.data[symbolName.lower()] = symbolData

        return symbolData

    def __getitem__(self, symbolName: str) -> pd.DataFrame:
        """ Returns the dataframe with the given key. Lazy implementation."""
        # See: https://www.kdnuggets.com/2023/03/introduction-getitem-magic-method-python.html
        
        if symbolName.lower() not in self.Gsymbols:
            symbolData = self.readSymbolAsDataFrame(symbolName)
            if symbolData is None:
                logger.error(f'Symbol of name {symbolName} was not found.')
                return None
            self.data[symbolName] = symbolData

        return self.data[symbolName.lower()]
    

def createPivot(dfRecs: pd.DataFrame, indexName: str, columnNames: list[str], valueName: str,
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
    
    if not valueName in dfRecs.columns:
        raise ValueError(f'{valueName=} not found in columns of DataFrame dfRecs')
    
    pivot = dfRecs.pivot(index=indexName, columns=columnNames, values=valueName)
    
    if fillna:
        pivot = pivot.fillna(0.0)
        
    if createTimeColumn:
        # Assuming the index of pivot has members of kind 't'nnnn where n is a digit.
        if pivot.index.name != 'tt':
            raise ValueError(f'Pivot must have index of name "tt", but "{pivot.index.name}" was found')
            
        if timeVector is None:
            pivot['time'] = [int(tt[1:]) for tt in pivot.index]
        else:
            pivot['time'] = [timeVector[int(tt[1:]) - 1] for tt in pivot.index]

        pivot = pivot.sort_values(by=['time'])
    
    return pivot


# ---------------------------------------------------------------------------------------------------------------------------------
if __name__ == '__main__':
    logger = setupLogger('LpMockUI')

    #region Reading data

    readStemData = False
    readModelData = True

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
        modelData = ModelData()
        symbolNames = ['u', 'upr', 'vak', 'OnUGlobal', 'TimeResol', \
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

    #endregion Reading data

    #region Extracting data to show

    # Pick available plants using the u symbol and the OnUGlobal symbol
    dfTimeResol = modelData['TimeResol']
    timeIncr = (dfTimeResol['level'] / 60).to_numpy()
    timeVec = np.cumsum(timeIncr)
    
    dfU = modelData['u']
    dfOnUGlobal = modelData['OnUGlobal']
    uAvail = dfOnUGlobal['u'].to_list()
    dfUpr = modelData['upr']
    # Remove columns of dfUpr that are not available
    dfUpr = dfUpr[dfUpr['u'].isin(uAvail)]

    dfQf_LRecs = modelData['Qf_L']
    dfQf_L = createPivot(dfQf_LRecs, indexName='tt', columnNames=['u'], valueName='level', createTimeColumn=True, timeVector=timeVec)
    
    # dfQf_Lavail nov contains a column name 'time' and a column for each plant that is available. Dimension 'tt' is used as index.
    # Pick only values of available production plants. 
        # Also, replace values of dfQf_Lavail that are less than 1E-12 with zero. The value 1E-14 is used by the GAMS model to ensure filled-in records.
    dfQf_Lavail = dfQf_L[uAvail + ['time']]   # Pick only columns of available plants and the time column.
    dfQf_Lavail[dfQf_Lavail < 1e-12] = 0.0

    # If any column of dfQf_Lavail ends with 'Cool', reverse the sign of the column values. Cooled heat is not delivered to the district heating system.
    for col in dfQf_Lavail.columns:
        if 'Cool' in col:
            dfQf_Lavail[col] = -dfQf_Lavail[col] 

    orderU = ['HoNVak', 'StVak', 'MaNVak', 'MaVak', 'MaAff1', 'MaAff2', 'MaBio', 'MaCool', 'MaCool2', 'MaEk', 'MaNbk', 'MaNbKV', 'MaNEk', 'MaNhpAir', 'MaNhpPtX', 
              'HoNEk', 'HoNFlis', 'HoNhpAir', 'HoNhpArla', 'HoNhpBirn', 'HoNhpSew', 'HoGk', 'HoOk', 
              'StEk', 'StNEk', 'StNFlis', 'StNhpAir', 'StGk', 'StOk']
    orderU = [u for u in orderU if u in dfQf_Lavail.columns]
    
    # Sort columns of dfQf_Lavail according to orderU and add the time column at the end.
    dfQf_Lavail = dfQf_Lavail[['time'] + orderU]

    pass
    #endregion Extracting data to show


    #region Setting up user interface

    # App layout

    # https://plotly.com/python-api-reference/

    # Drop columns containing Vak and Cool
    dfQf_Lavail = dfQf_Lavail.drop(columns=[col for col in dfQf_Lavail.columns if 'Vak' in col or 'Cool' in col])
    orderU = [u for u in orderU if u in dfQf_Lavail.columns]
    # fig = px.line(dfQf_Lavail, x="time", y=orderU, line_shape='hv')  
    # fig.show()

    # pass

    # Initialize the app
    app = Dash(__name__)
    

    # App layout
    app.layout = html.Div(
        [
            html.H4("Forsyningsselskabets varmeproduktion"),
            html.P("Anlaeg: "),
            dcc.Checklist(
                id="plants",
                options=orderU,
                value=orderU,
                inline=True,
            ),
            html.P("Gruppering: "),
            dcc.RadioItems(
                id="grouping",
                options=["Grundlast", "SR", "Ingen"],
                value="Ingen",
                inline=True,
            ),
            dcc.Graph(id="graph"),
        ]
    )

    @app.callback(
        Output("graph", "figure"),
        Input("plants", "value"),
        Input("grouping", "value"),
    )
    def generate_chart(plants, grouping):
        # df = dfQf_Lavail.copy(deep=True)
        print(f'{plants=}')
        print(f'{grouping=}')
        uSelected = [u for u in orderU if u in plants]    # Sort according to predefined order.

        df = dfQf_Lavail[['time'] + uSelected]

        # Grouping ignored for now.
        fig = px.line(dfQf_Lavail, x="time", y=uSelected, line_shape='hv')  
        return fig
        

    # Run the app
    app.run(debug=False)

    # # Create a figure with plotly express
    # fig = go.Figure()

    #endregion Setting up user interface
    pass