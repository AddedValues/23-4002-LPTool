# -*- coding: utf-8 -*-
"""

Unpacks variables of a time aggregated GAMS model stored in a gdx-file
and stores the unpacked variables in an Excel file, one sheet per variable.
Only the level attribute is unpacked.

Created on Sun Feb  5 10:15:34 2023

@author: MogensBechLaursen
"""
import os
from pathlib import Path
import GdxWrapper as gw
import pandas as pd
import numpy as np
import MEClib as mec

#%% Functions

def unpackGamsSymbol(dfPacked: pd.DataFrame, blen: np.array, unpackAction: str) -> pd.DataFrame:
    """
    Copies dataframe dfPacked and unpacks it backwards into the copy.
    The unpacking may be done safely on elemPacked but will destroy its packed contents.
    Assuming dataframe index is the GAMS time set tt ranging from 1 to 8760.
    blen is an array of integers stating the no. of hours within each block.
    """

    dfUnpacked = dfPacked.copy(deep=True)
    nblock = len(blen)
    ttprev = 8760
    for t in range(nblock-1, -1, -1):
        # Get row of packed elements.
        if unpackAction == CONST:
            row = dfPacked.iloc[t,:].values
        elif unpackAction == MEAN:
            row = dfPacked.iloc[t,:].values / blen[t]
        else:
            raise ValueError(f'Unrecognized {unpackAction=}')
        
        for tt in range(ttprev - blen[t], ttprev, 1):
            dfUnpacked.iloc[tt,:] = row
        ttprev -= blen[t]
    
    return dfUnpacked
    
    
#%% Main course.

global CONST, MEAN
CONST: str = 'const' # Assign the packed (aggregated) value of the block to the unpacked value.
MEAN : str = 'mean'  # Assign the average of the block to the unpacked value.

logger = mec.init('Unpack')

unpackActions = {'bOn_L': CONST, 'bOnSR_L': CONST, 'LVak_L': CONST, \
                 'Q_L': MEAN,  'Qbypass_L': MEAN, 'QRgk_L': MEAN, 'Qcool_L': MEAN, 'QT_L': MEAN, '': MEAN, '': MEAN, '': MEAN,
                 'Pnet': MEAN, 'PowInU': MEAN, 'FuelQty': MEAN}

# elements to unpack:  key is symbol name, Value is do_unpack indicator.
elements = {'Q_L': True, 'bOn_L': True}


pathWorkDir = r'C:\GitHub\23-1002 MEC FF\INVOPT\Master'
pathGdx = os.path.join(pathWorkDir, 'MECmain.gdx')

try:
    g = gw.GdxWrapper('gdxname', pathGdx, logger)
    allVarNames = g.getVarNames()
    allParmNames = g.getParmNames()
    nblock = int(g.getValue('Nblock'))
    bLen = np.array([int(b) for b in g.getValues('BLen', 'tt', fixSetKeyValues={} )][:nblock])
    
    dfElemsPacked = dict()  # Key is var name, value is DataFrame or dictionary
    dfElemsUnpacked = dict()  # Key is var name, value is DataFrame or dictionary
    for elemName in elements.keys():
        print(f'  Extracting {elemName=}')
        elemPacked = g.getDataFrame(elemName, attrName='level')
        dfElemsPacked[elemName] = elemPacked
        print('  ... and unpacking')
        df = unpackGamsSymbol(elemPacked, bLen, unpackActions[elemName])
        # Replacing the original packed dataframe.
        dfElemsUnpacked[elemName] = df
    
except Exception as ex:
    print(f'Exception caught:\n{ex=}\n')
finally:
    g = None  # Release gdx-file.
        
print('End of unpacking.')

