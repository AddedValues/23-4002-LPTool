# -*- coding: utf-8 -*-
"""
Created on Wed Mar  1 14:15:27 2023

Fetches results data from GAMS gdx-file of model MECmain and exports to a new Excel file.
Results data: StatsMecUPerIter, StatsMecFPerIter

@author: MogensBechLaursen
"""
import sys
import os
# from typing import *
import logging
from pathlib import Path
import GdxWrapper as gw
import pandas as pd
import numpy as np
import xlwings as xw
import MEClib as mec

NAME : str = 'MECPostProc'
# Instantiate the logger 
global logger
logger = mec.init(NAME)


def createPivot(dfRecs: pd.DataFrame, indexName: str, columnNames: list[str], valueName: str,
                fillna: bool = True, createTimeColumn: bool =False) -> pd.DataFrame:
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
            
        pivot['time'] = [int(tt[1:]) for tt in pivot.index]
        pivot = pivot.sort_values(by=['time'])
    
    return pivot

#%% Testing createPivot

scenName = ''
scenName = 'Scen_m11s01u00r00f00'
pathFolder = r'C:\GitHub\23-1002 MEC FF\INVOPT\Master'
pathFolder = r'C:\GitHub\23-1002 MEC FF\INVOPT\Results'
fname = f'MECmain_{scenName}.gdx'
pathGdx = os.path.join(pathFolder, fname)
path = Path(pathGdx)
if not path.exists():
    raise FileNotFoundError(pathGdx)

g = gw.GdxWrapper(fname, pathGdx, logger)

try:
    allVarNames = g.getVarNames()
    allParmNames = g.getParmNames()
    
    perFirst = int(g.getValue('PeriodFirst'))
    perLast  = int(g.getValue('PeriodLast'))
    
    dupFlags = g.getValues('DuplicateUntilIteration', 'perA', {})
    
    periods = ['per' + str(i) for i in range(perFirst, perLast+1)]
    perReal = ['per' + str(i+1) for i,dup in enumerate(dupFlags) if i >= perFirst-1 and i < perLast and dup == 0]
    monthYears = ['mo' + str(i) for i in range(1, 12+1)] + ['moall']
    monthNames = ['JAN','FEB','MAR','APR','MAJ','JUN','JUL','AUG','SEP','OKT','NOV','DEC','ÅR']

    # Mapping from per to year
    per2year = {per:(2025 - 7 + int(per[3:])) for per in periods}
    # Mapping from moyr to months and year
    moyr2name = {monthYears[i]: monthNames[i] for i in range(len(monthYears))}
    
    iterOptim = int(g.getValue('IterOptim'))
    iter = 'iter' + str(iterOptim)
    if iterOptim <= 1:
        raise ValueError(f'ERROR: {iterOptim=} must be at least 2')
    
    dfRecs = g.getRecords('StatsMecUPeriter', 'value')
    dfIter = dfRecs[(dfRecs.iter == iter)]
    dfIter = dfIter.drop(columns=['iter'])
    dfStatsU = dfIter.replace(per2year.keys(), per2year.values())
    dfStatsU = dfStatsU.replace(moyr2name.keys(), moyr2name.values())
    dfStatsU = dfStatsU.rename(columns={'u':'Anlæg', 'topicMecU':'Emne', 'mo':'Måned_År', 'perA':'År', 'value':'Værdi'})
    dfStatsU.index = range(1,len(dfStatsU)+1)  # Convert record nos to base-1.
    
    dfRecs = g.getRecords('StatsMecFPeriter', 'value')
    dfIter = dfRecs[(dfRecs.iter == iter)]
    dfIter = dfIter.drop(columns=['iter'])
    # dfIter.to_excel(r'.\dfIterMecF.xlsx')

    dfStatsF = dict()   # Key is topicMecF, Value is dataframe.
    topicMecF = g.getSetMembers('topicMecF')
    for topic in topicMecF:
        df = dfIter[dfIter.topicMecF == topic]
        df = createPivot(df, 'f', columnNames=['perA'], valueName='value')
        df = df.sort_values(by='f', axis=0)
        df = df[perReal]  # Take only non-duplicate periods.
        df = df.rename(per2year,axis=1)
        dfStatsF[topic] = df
    
    # Export to Excel
    xlapp = xw.App(visible=True, add_book=True)
    wb = xlapp.books(1)
    sh = wb.sheets(1)
    
    # Write dfStatsU and set formats.
    sh.name = 'Plants'    
    sh = wb.sheets[sh.name]
    sh.range("B10").value = dfStatsU
    sh.range("B10:G10").font.bold = True
    sh.range("G:G").number_format = '#.##0,00'
    
    # Write dfStatsF and set formats.
    for topic, df in dfStatsF.items():
        sh = wb.sheets.add(topic, after=sh)
        sh.range("B10").value = df
        sh.range("B10").value = ""
        sh.range("B10:Z10").font.bold = True
        sh.range("B10:B100").font.bold = True
        sh.range("C11:Z100").number_format = "#.##0,00"
    
    # Save Excel book and quit Excel.
    pathExcel = os.path.join(r'C:\GitHub\23-1002 MEC FF\INVOPT\Results\Data til MEC', f'StatsMec_{scenName}.xlsx') 
    wb.save(pathExcel)  
    wb.close()
    xlapp.quit()
    logger.info(f'Results saved as file: {pathExcel}')

except Exception as ex:
    print(f'Exception caught:\n{ex=}\n')
finally:
    g = None
    mec.shutdown(logger, f'{NAME} ended.')
        
