# -*- coding: utf-8 -*-
"""
Creates blocks for time aggregation of GAMS plant models based on dynamics of elspot price and heat demand.
Created on Fri Apr  1 12:22:02 2022
@author: MogensBechLaursen
"""

import os
import string
import numpy as np
import pandas as pd
import xlwings as xw
import MEClib as mec 
import AggrLib as aggrLib
from AggrLib import BlockOptions, GetBlocksBase1

global logger
logger = mec.init(r'.\TimeAggr')
aggrLib.logger = logger


letters = string.ascii_uppercase

def NumberToLetter(n: int):
    nlevel1 = (n-1) % len(letters)
    nlevel2 = (n-1) // len(letters)
    if nlevel2 > len(letters):
        nlevel3 = nlevel2 // len(letters)
        nlevel2 -= nlevel3 * len(letters)
    else:
        nlevel3 = 0
        
    address = letters[nlevel1]
    if nlevel2 > 0:
        address = letters[nlevel2 - 1] + address
    if nlevel3 > 0:
        address = letters[nlevel3 - 1] + address
        
    return address

# %% Read data

xlApp = xw.App(visible=True, add_book=False)

pathfolder = r'C:\GitHub\23-1002 MEC FF\Python'
filename   = r'MECTidsAggregering.xlsx'
path = os.path.join(pathfolder, filename)
wb       = xlApp.books.open(path, read_only=False)

# Read aggregration control parms.
shAggr   = wb.sheets['AggrCtrl']
dfAggr   = shAggr.range('B30').options(pd.DataFrame, index=True, header=True, expand='table').value

# Read names and active state of multi-year elspot projections.
dfSheetMultiYear = shAggr.range('B6').options(pd.DataFrame, index=True, header=True, expand='table').value
multiSheetNames  = list(dfSheetMultiYear.index)

# Read table of planned outages (0/1) and other shifts to compute mandatory block boundaries.
shShifts = wb.sheets['skifteTider']
dfShifts = shShifts.range('B10').options(pd.DataFrame, index=False, header=True, expand='table').value
nShifts = len(dfShifts.columns)
shiftActive = shShifts.range('B9:' + NumberToLetter(1 + nShifts) + '9').value
shiftActive = [dfShifts.columns[int(i)] for i,b in enumerate(shiftActive) if b != 0]

# Read names and active state of single-year elspot projections.
shSingles = wb.sheets['Singles']
dfSinglesHdr = shSingles.range('B3').options(pd.DataFrame, index=True, header=True, expand='table').value
dfSingles    = shSingles.range('B10').options(pd.DataFrame, index=True, header=True, expand='table').value
for elProfile in dfSinglesHdr.columns:
    if dfSinglesHdr.loc['Active', elProfile] == 0:
        dfSingles.drop(elProfile, axis=1, inplace=True)

# Read multi-year elspot projections, one sheet for each projection
multiProjs = dict()   # Key is multi-year elspot projection, Value is dataframe of annual hourly price profiles
for name in multiSheetNames:
    if dfSheetMultiYear.loc[name, 'Active'] > 0:
        sh = wb.sheets[name]
        df = sh.range('B10').options(pd.DataFrame, index=True, header=True, expand='table').value
        df.columns = [str(int(col)) for col in df.columns]
        multiProjs[name] = df

# Read heat demand profiles and active state: Single-year hourly profiles 
shHeat = wb.sheets['Varmeprofil']
dfHeat   = shHeat.range('C10').options(pd.DataFrame, index=False, header=True, expand='table').value
nHeatProfile = len(dfHeat.columns)
heatActive = shHeat.range('C9:' + NumberToLetter(2 + nHeatProfile) + '9').value
heatActive = {dfHeat.columns[int(i)]: (b != 0) for i,b in enumerate(heatActive)}
for heatProfile, active in heatActive.items():
    if not active:
        dfHeat.drop(heatProfile, axis=1, inplace=True)


# Error checking
singleProfiles = list(dfSingles.columns)
multiProfiles = list(multiProjs.keys())

# Check for duplicates.
singleSet = set(singleProfiles)
if len(singleSet) < len(singleProfiles):
    raise ValueError('Duplicates appear in single-year elspot profiles')
multiSet = set(multiProfiles)
if len(multiSet) < len(multiProfiles):
    raise ValueError('Duplicates appear in multi-year elspot profiles')
    
#%% Compute mandatory block boundaries    

# Shifts are identical across years of the planning horizon.

shifts = dict()   # Key is name of shift driver (e.g. column names of dfShifts), Value is shift ours.
for col in shiftActive:
    outs = dfShifts[col].values
    diffs = outs[1:] - outs[:-1]
    ser = pd.Series(data=diffs, index=dfShifts.index[1:])  # Shifts are now base-0.s
    #--- shifts[col] = np.array(ser[ser != 0].index.to_numpy(dtype='int')) + 1  # Add 1 to get base-1 hours.
    shifts[col] = ser[ser != 0].index.to_numpy(dtype='int')

# Create union of shifts.
allShifts = list()
for col in shiftActive:
    allShifts.extend(shifts[col])

allShifts = np.sort(list(set(allShifts)))

#%%  Compute time aggregates.

options = {col: BlockOptions(col, dict(dfAggr[col])) for col in dfAggr if dfAggr.loc['active', col] > 0}

# Compute block partitioning for a single heat profile at a time.
results = dict()  # Key is tuple of (aggr-option, heatprofile, elprofile, year)
for opt in options.values():
    for heatProfile in dfHeat.columns:
        heatRaw  = dfHeat.loc[:, heatProfile].values
        heatNorm = heatRaw / np.nanmax(heatRaw)
        
        # Multi-year elspot projections. Aggregations are specific to each year.
        years = range(opt.yearBeg, opt.yearEnd + 1)
        for elProfile in multiProjs.keys():
            dfElProj = multiProjs[elProfile]
            for yr in years:
                logger.debug(f'{opt.name}, Multi.{heatProfile=}, {elProfile=}, {yr=}')
                # Normalize elspot projections by annual average
                # Timeseries price defines the block partitioning.
                priceRaw = dfElProj.loc[:, str(yr)].values
                priceMean = np.nanmean(priceRaw)
                priceNorm = priceRaw / priceMean
                # Compute time aggregration.
                dfBlocks, dfBlockSeries, dfPeaks = GetBlocksBase1(opt, primaryTs=priceNorm, secondaryTs=heatNorm, shifts=allShifts)
                results[(opt.name, heatProfile, elProfile, yr)] = dfBlocks
        
        # Single-year elspot projections. Aggregation is duplicated across years.
        for elProfile in dfSingles.columns:
            logger.debug(f'{opt.name}, Single.{heatProfile=}, {elProfile=}')
            # Normalize elspot projections by annual average
            # Timeseries price defines the block partitioning.
            priceRaw = dfSingles[elProfile].values
            priceMean = np.nanmean(priceRaw)
            priceNorm = priceRaw / priceMean
            # Comopute time aggregration.
            dfBlocks, dfBlockSeries, dfPeaks = GetBlocksBase1(opt, primaryTs=priceNorm, secondaryTs=heatNorm, shifts=allShifts)
            #--- results[(opt.name, heatProfile, elProfile, yr)] = dfBlocks
            for yr in years:
                results[(opt.name, heatProfile, elProfile, yr)] = dfBlocks


# %% Write results to Excel 

elProfiles = multiProfiles + singleProfiles 
nBlockMax = max([len(df) for df in results.values()])
indx    = ['AggrCtrl', 'HeatProfile', 'ElProfile', 'Scheme', 'Year'] + ['t'+str(i) for i in range(1, nBlockMax + 1)]
indxHdr = ['Count','AggrRate','MinBlock','MaxBlock','MeanLength']
dfResults    = pd.DataFrame(data=None, index=indx, columns=None)
dfResultsHdr = pd.DataFrame(data=None, index=indxHdr, columns=None)
series = list()
hdrs   = list()
scheme = 0   # integer designating a unique combination of aggr. control parms, heat profile and elspot projection.
for opt in options.values():
    for heatProfile in dfHeat.columns:
        for elProfile in elProfiles:
            scheme += 1
            for yr in years:
                dfBlocks = results[(opt.name, heatProfile, elProfile, yr)]
                vals = list(dfBlocks['Begin'].values)
                lens = list(dfBlocks['Count'].values)
                ser = pd.Series([opt.name, heatProfile, elProfile, 'aggr' + str(scheme), str(int(yr))] \
                                + vals + [None for i in range(nBlockMax - len(dfBlocks))])
                series.append(ser)
                serHdr = pd.Series([len(lens), len(lens)/8760, min(lens), max(lens), round(np.mean(lens),1)])
                hdrs.append(serHdr)

# Somehow, index of dfResults will be overwritten by the concat operation.
dfResultsHdr = pd.concat(hdrs, axis=1)
dfResultsHdr['indxHdr'] = indxHdr
dfResultsHdr.set_index('indxHdr', inplace=True)
dfResults = pd.concat(series, axis=1)
dfResults['indx'] = indx
dfResults.set_index('indx', inplace=True)

shResults = wb.sheets['TimeBlocks']
shResults.range('B4').value = dfResultsHdr
shResults.range('B4').value = 'Statistics'
# shResults.range('B5').options(transpose=True).value = indxHdr
shResults.range('B10').value = dfResults
shResults.range('B10').value = 'BlockBegin'
#%%
wb.save()
wb.close()
xlApp.quit()

