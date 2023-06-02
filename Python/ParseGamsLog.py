# -*- coding: utf-8 -*-
"""
Created on Thu Feb  9 08:29:02 2023

@author: MogensBechLaursen
"""

import os
import numpy as np
import pandas as pd

path = r'C:\GitHub\21-1017-AVA\21-1017-AVA\INVOPT\Gaps.txt'

with open(path, mode='r') as fIn:
    lines = fIn.readlines()
    
    
#%% Parse lines

# Lines of interest are tabulated using <blank> as spacers.
# Rule 1: Skip lines with text "Best objective"
# Rule 2: Skip until and including colon
# Rule 3: Pattern of solver progress lines are: (+ is one or more)
#         Positions after colon (1-based)  Item 
#          1 -  2   <H | blank>           # Heuristics
#          3 -  8   <int>+ | <blank>+     # Explored nodes
#          9 - 13   <int>+ | <blank>+     # Unexplored nodes
#         14 - 24   <float | <blank>+     # Objective
#         25 - 29   <int>+ | <blank>+     # Depth
#         30 - 34   <int>+ | <blank>+     # IntInf
#         35 - 45   <float>               # Incumbent
#         46 - 56   <float>               # BestBd
#         57 - 63   <percentage>          # Gap %
#         64 - 69   <float>               # It/Node
#         70 - 74   <int>                 # Time (seconds)

beg = 1 + lines[3].find(':', 0)
runs = list()  # Contains lists of tuples of gap and elapsed time (secs), a list for each solver run.
run = list()
runs.append(run)
for line in lines[2:]:
    if 'Best objective' in line:
        run = list()
        runs.append(run)
        continue

    gap = float(line[beg+56:beg+62])
    secs = float(line[beg+69:beg+74])
    run.append((gap, secs))


#%% Compute time spent below a certain value of the gap.

nRH = 42
perbeg = 8
perend = 17
nper = perend - perbeg + 1
iterbeg = 2
iterend = 12
niter = iterend - iterbeg + 1       # Iter 1 is skipped.

# The log file reflects the iteration pattern: for iter = 2 to maxIter, for per = 8 to 17

timespent = dict()   # Key is gap threshold, Value is hours spent below threshold.
timetables = dict()  # Key is gap threshold, Value is hours spent below threshold.

for threshold in [6.0, 5.0, 4.0, 3.0]:  # Threshold of gap in percent.
    timebelow = np.zeros(len(runs))  # For each run, the time spent at gap below threshold.
    for irun, run in enumerate(runs):
        # print(f'{irun=}')
        for (gap,secs) in run:
            if gap <= threshold:
                dtime = run[len(run)-1][1] - secs
                timebelow[irun] = dtime
                break
    timespent[threshold] = sum(timebelow) / 3600

    # Create table of spent time versus master iteration and period.
    df = pd.DataFrame(data=None, index=['iter'+str(i) for i in range(iterbeg, iterend+1)], 
                                 columns = ['per'+str(p) for p in range(perbeg, perend + 1)])
    for iter in range(0, niter):
        for per in range(nper):
            timesum = 0.0
            for rh in range(0, nRH):
                irun = nRH * (nper * iter + per) + rh
                timesum += timebelow[irun] 
                if per == 0 and iter < 2:
                    print(f'{iter=}, {per=}, {irun=}, {rh=}, {timesum=}, {timebelow[irun]=}')
            df.loc['iter' + str(iter+2), 'per'+str(perbeg+per)] = timesum
    timetables[threshold] = df        
            


