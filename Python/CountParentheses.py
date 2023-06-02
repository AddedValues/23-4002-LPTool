# -*- coding: utf-8 -*-
"""
Created on Mon Nov  9 07:52:17 2020

@author: MogensBechLaursen
"""

import os


# def parseFile(lines : list[str], allLines: list[str], firstLine: dict[str,(int,int)]) -> list[str]:
def parseFile(fname: str, incWords: list[str]) -> list[str]:
    """ Read each line in lines and recursively includes other source files """
    
    print(f'{fname=}')
    with open(os.path.join(wkdir, fname), mode='r') as fMain:
        lines = fMain.readlines()
    
    # Read each line and search for include stmts (incWords)
    # If not found, append the line to allLines.
    # else get the lines of the file to be included and append to allLines.
    allLines = list()
    for line in lines:
        found = False
        for incWord in incWords:
            if line[:len(incWord)].lower() == incWord:
                # $Include SolveSlaveModel.gms
                # $batInclude 'SaveSlaveResults.gms' modelSlave
                incFname = line.split(' ')[1].strip().replace("'","").replace('"', '')
                print(f'{fname=}, {incFname=}')
                if fname == incFname:
                    return None
                addLines = parseFile(incFname, incWords)
                allLines.extend(addLines)
                found = True
                break
        if not found:
            allLines.append(line)

    return allLines
    

#%% Read all gms starting with the main file and parsing include stmts.

wkdir = r'C:\GitHub\21-1017-AVA\21-1017-AVA\INVOPT'
fileMain = 'Main.gms'
# fnames = [fname for fname in os.listdir(wkdir) if fname[-4:] == '.gms']
incFileExts = ['.gms', '.inc']
# fnames = [fname for fname in os.listdir(wkdir) if fname[-4:].lower() in incFileExts]

# Compose a single file from the GAMS source files (may be .gms, .inc or other)
incWords = ['$include', '$batinclude']

# firstLine = dict()  # Key is file name, Value is tuple: (first, last) line in composed file.

lines = parseFile(fileMain, incWords)

fname = 'Composed.txt'
with open(os.path.join(wkdir,fname), mode='w') as fAll:
    fAll.writelines(lines)


#%% Parse the composed single file.

infiles = [fname]

infiles = [fn for fn in os.listdir(wkdir) if fn[-4:] == '.gms']
infiles = infiles[-1:]

fout = open(os.path.join(wkdir,'countparentheses.txt'), mode='w')
nleft = dict()   # Key is input file name, Value is no. of left parentheses.
nright = dict()  # Key is input file name, Value is no. of right parentheses.

for fname in infiles:
    fpath = os.path.join(wkdir, fname)
    with open(os.path.join(wkdir, fname), mode='r') as fIn:
        lines = fIn.readlines()

    fout.write('File: {}\n'.format(fname))
    fout.write('iline, leftcount, rightcount, nleft, nright, note\n') 
    unequalFiles = dict()
    nleft[fname] = 0
    nright[fname] = 0
    iline = 0
    for line in lines:
        iline += 1
        leftcount = line.count('(')
        rightcount = line.count(')')
        if leftcount == 0 and rightcount == 0: 
            continue
        nleft[fname]  = nleft[fname] + leftcount
        nright[fname] = nright[fname] + rightcount
        if leftcount != rightcount:
            note = '<-- unequal on line: ' + line
            if nleft[fname] == nright[fname]:
                note += ', but currently matching on file level'
        
            unequalFiles[fname] = 'YES'
        else: 
            note = ' '
        
        fout.write('Line {}:\t{}\t{}\t{}\t{}\t{}\n'.format(iline, leftcount, rightcount, nleft[fname], nright[fname], note))
    
# Write stats
fout.write('\nUn-equal files:\n')
for fname in infiles:  
    if nleft[fname] != nright[fname]:
        note = '<--- Unequal on file level'
    else:
        note = ''
    fout.write('{}\t{}\t{}\t{}\n'.format(fname, nleft[fname], nright[fname], note))
  
fout.close()


#%% 
"""  

# Reading parameter BreakRun from file breakrun.txt
import os

wkdir = r"C:\Users\MogensBechLaursen\Documents\gamsdir\projdir\GitHub\SILK\20-1002 Silkeborg\INVOPT"
fpath = os.path.join(wkdir, r'BreakRun.txt')
if not os.path.exists(fpath):
  print('No such file: ' + fpath)
else:
  f = open(fpath, mode='r')
  lines = f.readlines()
  f.close()
  breakrun = list()
  for line in lines:
    line = line.strip()
    if line.startswith('*'): 
      continue
    else:
      breakrun.append(int(line))
      break
    
  print(breakrun[0])

  
  
#%%
# Copying file breakrun.txt
import os
import shutil

wkdir = r"C:\Users\MogensBechLaursen\Documents\gamsdir\projdir\GitHub\SILK\20-1002 Silkeborg\INVOPT"
fpathOld = os.path.join(wkdir, r'BreakRun.txt')
fpathNew = os.path.join(wkdir, r'BreakRunCopy.txt')
shutil.copyfile(fpathOld, fpathNew)

#%%
# Removing older files no longer needed 
import os
import shutil

wkdir = r"C:\Users\MogensBechLaursen\Documents\gamsdir\projdir\GitHub\SILK\20-1002 Silkeborg\INVOPT"
fpathOld = os.path.join(wkdir, r'BreakRun.txt')
fpathNew = os.path.join(wkdir, r'BreakRunCopy.txt')
shutil.copyfile(fpathOld, fpathNew)


os.listdir(wkdir)

"""




















