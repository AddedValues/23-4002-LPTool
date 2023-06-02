# -*- coding: utf-8 -*-
"""
Created on Thu Feb  9 08:29:02 2023

@author: MogensBechLaursen
"""

import os
import numpy as np
import pandas as pd
import time

path = r'C:\GitHub\21-1017-AVA\TestRuns\MipGap sliding 8\Elapsed time.txt'

with open(path, mode='r') as fIn:
    lines = fIn.readlines()
    
    
#%% Parse lines

# The input file is created by filtering the GAMS log file searching for text "after solve:"
# The first two lines are ids of the GAMS log file.
# Lines of interest are tabulated using <blank> as spacers.
# Rule 1: All lines pertain to a solver run, one for each rolling horizon
# Rule 2: Grap the elapsed time h:mm:ss.sss after the text 'elapsed'

# First two lines are search info to be skipped.
beg = 1 + lines[2].find('elapsed', 0) + len('elapsed')
times = list()  # Contains elapsed time for each solver run since start of GAMS run

secsPrev = 122.479 # Elapsed before start of first solver run.
for line in lines[2:]:
    elapsed = line[beg:-1]
    lenhour = elapsed.find(':',0)
    secs = 3600 * int(elapsed[0:lenhour]) + 60 * int(elapsed[1+lenhour:3+lenhour]) + float(elapsed[4+lenhour:])
    times.append(secs - secsPrev)
    secsPrev = secs

#%% Compute time spent below a certain value of the gap.

nRH = 28        # No. of rolling horizons.
perbeg = 8      # Index of first period.
perend = 17     # Index of last period.
nper = perend - perbeg + 1
iterbeg = 2     # First real master iteration.
iterend = 12    # Last master iteration embraced by the input file.
niter = iterend - iterbeg + 1       # Iter 1 is skipped.

# The input file reflects the iteration pattern: for iter = 2 to maxIter, for per = 8 to 17

timespent = dict()   # Key is master iteration, Value is data frames of seconds spent by the solver.

# For each master iteration, create a table of spent solver time versus and rolling horizon.
for iter in range(0, niter):
    df = pd.DataFrame(data=None, index=['per'+str(p) for p in range(perbeg, perend+1)], 
                                 columns = ['rh'+str(r) for r in range(1, nRH + 1)])
    for per in range(nper):
        tbeg = nRH * iter * nper +  nRH * per 
        df.loc['per' + str(per+perbeg), :] = times[tbeg : tbeg + nRH]
    
    # Create a sum column and move it to the left of the dataframe.
    df['Sum'] = df.sum(axis=1)
    cols = df.columns.tolist()
    cols = cols[-1:] + cols[:-1]
    df = df[cols]
    timespent['iter'+str(iter+iterbeg)] = df
        
            
#%% Save timespent dataframes onto an Excel file.

import xlwings as xw
xlApp = xw.App(visible=True, add_book=True)
wb = xlApp.books[0]
sh = wb.sheets[0]

for iter, itername in enumerate(timespent.keys()):
    df = timespent[itername]
    irow = 10 + iter * (nper + 2)
    sh.range((irow, 1)).value = df
    sh.range((irow, 1)).value = itername
    
#%%
xlApp.quit()
