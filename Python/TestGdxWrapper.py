# -*- coding: utf-8 -*-
"""
Created on Wed Mar  1 14:15:27 2023

@author: MogensBechLaursen
"""
import os
# from typing import *
from pathlib import Path
import GdxWrapper as gw
import pandas as pd
import numpy as np

#%% 

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

pathFolder = r'C:\GitHub\21-1017-AVA\21-1017-AVA\INVOPT'
fname = r'MECmain.gdx'
pathGdx = os.path.join(pathFolder, fname)

path = Path(pathGdx)
if not path.exists():
    raise FileNotFoundError(pathGdx)

g = gw.GdxWrapper(fname, pathGdx)

try:
    # allVarNames = g.getVarNames()
    # allParmNames = g.getParmNames()
    dfRecs = g.getRecords('UnitPars', 'value')
    unitPars = createPivot(dfRecs, indexName='u', columnNames=['ParUnits'], valueName='value')
    print(f'UnitPars:\n{unitPars.describe()}\n ')
    
    dfRecs = g.getRecords('ParAffaldT', 'level')
    parAffaldT = createPivot(dfRecs, indexName='tt', columnNames=['uAv', 'lblAffaldT'], valueName='level')
    print(f'parAffaldT:\n{parAffaldT.describe()}\n ')
    
    dfRecs = g.getRecords('EQ_dQUMax', 'marginal')
    marginals = createPivot(dfRecs, 'tt', ['u'], 'marginal', fillna=True, createTimeColumn=True)
    print(f'EQ_dQUMax:\n{marginals.describe()}\n ')
    

except Exception as ex:
    print(f'Exception caught:\n{ex=}\n')
finally:
    # g = None
    pass
        
print('End of test.')
