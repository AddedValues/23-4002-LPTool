# -*- coding: utf-8 -*-
"""
Created on Fri Apr 28 11:57:53 2023

@author: MogensBechLaursen
"""

# from dataclasses import dataclass

# @dataclass  
# class MyClass():
#     x : int 
#     y : int = 3   
#     z : int = self.add()
    
#     def add(self):
#         self.z = self.x + self.y

# mc = MyClass(x=5, y=28)

# print(mc)

#%%

def expandScenId(scenId: str) -> str:
    """ Inserts a hyphen in-between sequences of 3 characters in scenId. """
    return '-'.join([scenId[i*3:i*3+3] for i in range(5)])


scenId = 'm11s22u33r44f55'
scenIdExpanded = expandScenId(scenId)
print(f'{scenIdExpanded=}')



#%%
import os 
# https://pypi.org/project/file-read-backwards/
from file_read_backwards import FileReadBackwards
pathListingFile = os.path.join(r'C:\GitHub\23-1002 MEC FF\INVOPT\Results', '_gams_py_gjo0_Scen_m11s01u00r00f00.lst' )

lines = list()
iline = -1
with FileReadBackwards(pathListingFile, encoding='utf-8') as frb:
    while True:
        line = frb.readline()
        iline += 1
        if (line[:5] == "LOOPS") and ("iter   iter" in line) and (iline >= 3):
            # print(f'{iline=}, {line=}')
            lines.append((iline,line))
        if len(line) == 0 or iline > 200000:
            break

i = 1


# %%

from random import random

capacs = [30.0 + 30 * random() for i in range(7,13+1)]
print(capacs)
    

# %%
