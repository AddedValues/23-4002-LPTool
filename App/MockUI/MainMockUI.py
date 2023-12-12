"""
This is the main file for the MockUI-app. 
MockUI is a mockup of the UI for the final product.
See https://codegym.cc/da/groups/posts/da.232.solid-fem-grundlggende-principper-for-klassedesign-i-java for a discussion of SOLID principles.
"""

from email import header
from lib2to3.pygram import Symbols
from re import A
from typing import Any
import logging
import sys
import os
import shutil
import locale
import time
from datetime import datetime, timedelta
import asyncio
import numpy as np
import pandas as pd
# import pyxlsb
import xlwings as xw
import plotly.graph_objects as go
import GdxWrapper as gw

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
                print(f'Reading table {tableName} from sheet {sheetName} with range {rangeName}.')
                print(f'UseIndex={useIndex}, RowDim = {rowDim}, ColDim = {colDim}.')
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

        self.data = dict()  # Key is symbol name, value is dataframe.
        self.gw = gw.GdxWrapper(name='ModelData', pathFile=self.path, loggerName=logger.name)
        return

    def readSymbolAsDataFrame(self, symbolName: str, attrName: str = 'level') -> pd.DataFrame:
        """
        Reads data of a single GAMS symbol from the gdx file and returns a dataframe with the data.
        """
        # Read symbol data from gdx file
        symbolData = self.gw.getDataFrame(symbolName, attrName)
        return symbolData

    def __getitem__(self, symbolName: str) -> pd.DataFrame:
        """ Returns the dataframe with the given key. Lazy implementation."""
        # See: https://www.kdnuggets.com/2023/03/introduction-getitem-magic-method-python.html
        
        if symbolName not in self.data:
            self.data[symbolName] = self.readSymbolAsDataFrame(symbolName)
        return self.data[symbolName]


if __name__ == '__main__':
    logger = setupLogger('LpMockUI')
    readStemData = False
    readModelData = True

    if readStemData:
        # Create StemData object
        stemData = StemData()
        data = stemData.data

    if readModelData:
        # Create ModelData object
        modelData = ModelData()
        symbolNames = ['OnUGlobal', 'TimeResol', 'Qf_L', 'QTf', 'PfNet', 'FuelQty', 'QfDemandActual_L', 'EVak_L', 'FuelCost', 'TotalCostU', 'TotalTax', 'StatsU']
        for symbolName in symbolNames:
            df = modelData[symbolName]
            print(df)

    pass