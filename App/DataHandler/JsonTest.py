
# Relative import. See: https://sparkbyexamples.com/python/import-files-from-different-folder-in-python/

import os
import sys

# Adding the app root folder to the python path.
appDir = r'C:\GitHub\23-4002-LPTool\App'
sys.path.append(appDir)

import json
import sqlite3
import pandas as pd
import numpy as np
import datetime as dt
import gams 
import AppBase.LpBase as lpbase
import AppBase.GdxWrapper as gw
import Engine
from Engine.JobResult import JobResult

#%% Transferring data from GAMS gdx-file to SQLite database

rootDir = r'C:\GitHub\23-4002-LPTool'
dataDir = r'C:\GitHub\23-4002-LPTool\App\Data'
workDir = r'C:\GitHub\23-4002-LPTool\App\WorkDir'
gdxFilePath = os.path.join('Alloc=On 6-24-18h', 'MecLpMain.gdx')

ws = gams.GamsWorkspace(workDir)
gdb = ws.add_database_from_gdx(os.path.join(dataDir, gdxFilePath), database_name='Test')
jobResult = JobResult(name='Test', description='Test', gdb=gdb)

entityList = {'OnUGlobal', 'Bbeg', 'BLen', 'Q', 'Pnet', 'FuelQty', 'StatsU'}

for entity in entityList:
    gsym, entity = jobResult.getEntity(entity, 'level')
    print(f"Entity: {gsym}, {type(entity)}")

pass

#%% SQlite snippets

# Get  database connection optionally creating a new SQlite database. 
conn = sqlite3.connect('jsontest.db')








"""
data = { 'user':{ 'William': 1, 'John': 2, 'James': 3 }}

numbers = [1, 2, 3, 4, 5]

with open('data.json', 'w') as outfile:
    json.dump(data, outfile, indent=4)
    json.dump(numbers, outfile, indent=4)


json_str = json.dumps(data, indent=4)
print (json_str)

data2 = json.loads(json_str)

pass
"""