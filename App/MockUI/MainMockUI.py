"""
This is the main file for the MockUI-app. 
MockUI is a mockup of the UI for the final product.
"""

from email import header
from lib2to3.pygram import Symbols
from re import A
from typing import Any
import sys
import os
import time
import asyncio
import numpy as np
import pandas as pd
# import pyxlsb
import xlwings as xw
import plotly.graph_objects as go
import GdxWrapper as gw


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

    def __init__(self, fileName: str = 'MecLPinput.gdx'):
        """ Initializes the ModelData object. """

        # self.path = os.path.join('C:\\GitHub\\23-4002-LPTool\\Data\\MockUI', fileName)
        self.path = os.path.join('C:\\GitHub\\23-4002-LPTool\\Master', fileName)
        if not os.path.exists(self.path):
            raise ValueError(f'File {self.path} does not exist.')

        self.data = dict()  # Key is symbol name, value is dataframe.
        self.gw = gw.GdxWrapper(self.path)
        return

    def readSymbolAsDataFrame(self, symbolName: str, attrName: str = 'level') -> pd.DataFrame:
        """
        Reads data of a single GAMS symbol from the gdx file and returns a dataframe with the data.
        """
        # Read symbol data from gdx file
        symbolData = self.gw.getDataFrame(symbolName, attrName)
        return symbolData

    def __getitem__(self, key: str) -> pd.DataFrame:
        """ Returns the dataframe with the given key. Lazy implementation."""
        # See: https://www.kdnuggets.com/2023/03/introduction-getitem-magic-method-python.html
        
        if key not in self.data:
            data[key] = self.readSymbol(key)
        return self.data[key]


if __name__ == '__main__':
    
    # Create StemData object
    stemData = StemData()
    data = stemData.data

    # Create ModelData object
    modelData = ModelData()
    symbolNames = ['OnUGlobal', 'TimeResol', 'Qf_L', 'QTf', 'PfNet', 'FuelQty', 'QfDemandActual_L', 'EVak_L', 'FuelCost', 'TotalCostU', 'TotalTax', 'StatsU']
    for symbolName in symbolNames:
        df = modelData[symbolName]


    pass