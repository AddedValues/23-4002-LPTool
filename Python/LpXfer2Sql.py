#%% Imports
from dataclasses import dataclass
import sys
import os
import sqlite3 as sql
import numpy as np
import pandas as pd
import xlwings as xw
import MEClib as mec

NAME : str = 'MECPostProc'
# Instantiate the logger 
global logger
logger = mec.init(NAME)

#%% Create classes

@dataclass
class ExcelTable():
    sheetName : str   # Name of the sheet in Excel
    tableName : str   # Name of the table in Excel
    rangeName : str   # Name of the range in Excel
    rowDim    : int   # Number of rows in table header
    colDim    : int   # Number of columns in table header
    df        : pd.DataFrame = None  # The table as a DataFrame


def getExcelTables(pathFolder: str) -> dict[str, ExcelTable]:
    """ Reads the tables from an Excel file into a dictionary of ExcelTable objects."""

    fname = f'MECKapacInput.xlsb'
    pathExcelBook = os.path.join(pathFolder, fname)
    if not os.path.exists(pathExcelBook):
        raise FileNotFoundError(pathExcelBook)    

    xlApp = None
    try:
        # Open the workbook 
        xlApp = xw.App(visible=False, add_book=False) 
        wb = xlApp.books.open(pathExcelBook, read_only=True)

        # Read table of named ranges from Excel using pandas 
        shNamedRanges = wb.sheets['LpSpec']
        dfNamedRanges = shNamedRanges.range('tblLpTables').options(pd.DataFrame, index=False, header=True, expand='table').value
        sheetNames = [sh.name for sh in wb.sheets]

        # Read the tables from Excel file into a dictionary of ExcelTable objects.
        tables = dict()  # Key is tableName, value is ExcelTable as dataframe
        for i in range(len(dfNamedRanges)):
            row = dfNamedRanges.iloc[i]
            sheetName = row['SheetName']
            tableName = row['TableName']
            rangeName = row['RangeName']
            rowDim = int(row['RowDim'])
            colDim = int(row['ColDim'])
            if not sheetName in sheetNames:  # TODO prefix sheetName with workbook name in brackets
                raise ValueError(f'ERROR: Sheet {sheetName} not found in Excel workbook.')
        
            rng = wb.sheets[sheetName].range(rangeName)
            # Do not use the expand option as the table is fully defined by the rangeName. Otherwise a multi-row header will be expanded to a single row.
            df = rng.options(pd.DataFrame, index=False, header=True).value
            tables[tableName] = ExcelTable(sheetName, tableName, rangeName, rowDim, colDim, df)

        wb.close()
        xlApp.quit()

    except Exception as ex:
        logger.error(f'Exception caught:\n{ex=}\n', exc_info=True)
        if 'xlApp' in locals() and xlApp is not None:
            xlApp.quit()
        raise ex
    finally:
        return tables   

if __name__ == '__main__':

    try:
        pathFolder = r'C:\GitHub\23-1002 MEC FF\INVOPT\Master'
        tables = getExcelTables(pathFolder)

        # Write the tables to a SQLite database.
        pathDb = os.path.join(pathFolder, 'MECKapacInput.db')
        if os.path.exists(pathDb):  
            os.remove(pathDb)   
        conn = sql.connect(pathDb)
        for tableName, table in tables.items():
            table.df.to_sql(tableName, conn, index=False)
        conn.close()

        # update tables in the SQLite database if needed.
        # Use the following command to update the tables in the SQLite database:
        


    except Exception as ex:
        logger.error(f'Exception caught:\n{ex=}\n', exc_info=True)

    finally:
        mec.shutdown(logger, f'{NAME} ended.')
        sys.exit(0)  # TODO Consider using sys.exit(1) if an error occurred.
