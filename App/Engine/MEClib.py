# -*- coding: utf-8 -*-
"""
Created on Tue Apr  4 13:00:47 2023

@author: MogensBechLaursen
"""

from asyncio import events
import sys
import os
import inspect             # Inspection of the python stack.
import logging
import locale
import string
import shutil
from typing_extensions import deprecated
import numpy as np
import pandas as pd
from dataclasses import dataclass
from datetime import datetime, timedelta
import tomllib
import xlwings as xw
import argparse 
# import GdxWrapper as gw
# import matplotlib.pyplot as plt
# from matplotlib import cm
import seaborn as sns # Importing color palettes

global CONST, MEAN
CONST: str = 'const' # Assign the packed (aggregated) value of the block to the unpacked value.
MEAN : str = 'mean'  # Assign the average of the block to the unpacked value.

MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAJ', 'JUN', 'JUL', 'AUG', 'SEP', 'OKT', 'NOV', 'DEC', 'ÅR']

global logger, pathRoot
logger: logging.Logger = None

events = dict()   # Used to store events that may be triggered by the user.

pathRoot = r'C:\GitHub\23-1002 MEC FF'

letters = string.ascii_uppercase

# // @staticmethod
def numberToLetters(n: int):
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

# // @staticmethod
def lettersToNumber(address: str):
    address = address.upper()
    n = 0
    for i, c in enumerate(address):
        n += (ord(c) - ord('A') + 1) * 26 ** (len(address) - i - 1)
    return n

    
class ExcelTable():
    # // @staticmethod
    def convertExcelAddressToIndices(addr: str) -> tuple[int,int]:
        """ Converts an absolute Excel address (using $) to numerical indices (base 1). """
        
        parts = addr.split('$')[1:]
        icolBase1 = lettersToNumber(parts[0])
        irowBase1 = int(parts[1])
        return (irowBase1, icolBase1)
    
    # // @staticmethod
    def convertIndicesToExcelAddress(irowBase1: int, icolBase1: int) -> str:
        """ Converts numerical indices (base 1) to an absolute Excel address (using $). """
        
        addr = f'${numberToLetters(icolBase1)}${irowBase1}'
        return addr

    def __init__(self, sheet: xw.Sheet, tblName: str):
        """ 
        Reads a table from sheet and stores it as a dataframe. 
        Note: The address is the upper left and lower right corners of the table including headers.
        """
        self.sheet = sheet
        self.tblName = tblName

        # Load without index as a particular column will be used as index.
        self.df = sheet.range(tblName).options(pd.DataFrame, header=True, index=False).value
        
        # Excel address is absolute (using $) and comprises upper left and lower right corner of table.
        self.address = sheet.range(tblName).address
        (upperLeft, lowerRight) = self.address.split(':')  
        self.ulAddr = ExcelTable.convertExcelAddressToIndices(upperLeft)
        self.lrAddr = ExcelTable.convertExcelAddressToIndices(lowerRight)
        return
    
    def __str__(self):
        return f'sheet={self.sheet.name}, range={self.tblName} at {self.address}'

    def getCellAddr(self, rowName: str, colName: str, lookupCol: str) -> tuple[int,int]:
        """ Returns the row and column indices (base-1) of the cell specified by rowName  and colName."""
        
        # Find the row and column indices (base-1) relative to the table's upper left corner.
        try:
            hit = self.df[lookupCol] == rowName
            if hit is None or len(hit) == 0:
                raise ValueError(f'Row name {rowName} not found in column {lookupCol} of table {self.tblName}')
            
            irowBase1 = (self.df[self.df[lookupCol] == rowName].index)[0] + 2 # Add 2 to compensate for headers and Python's base-0 indexing.
            icolBase1 = self.df.columns.get_loc(colName) + 1
            irowBase1 = irowBase1 + self.ulAddr[0] - 1     
            icolBase1 = icolBase1 + self.ulAddr[1] - 1
        except Exception as ex:
            logger.error(f'Error in getCellAddr: {ex}')
            raise ex
        return (irowBase1, icolBase1)
        
# // @staticmethod        
def pmt(rate: float, invLen: int) -> float:
    """ Calculates the annuity payment per period. """
    # rate:   interest rate
    # invlen: length of payment period.
    annuityRate = rate / (1 - (1+rate)**(-invLen))
    return annuityRate

# // @staticmethod
def whoami():
    s = inspect.stack()
    return [ s[1][3], s[2][3] ]  # function and caller names.

# // @staticmethod
def init(logfileName: str) -> logging.Logger:
    global logger
    locale.setlocale(locale.LC_TIME, 'da_DK.UTF-8')

    # Setup logger(s): Levels are: DEBUG, INFO, WARNING, ERROR, CRITICAL. See https://realpython.com/python-logging/
    """
    Example of logging an exception:
    a =5; b = 0;
    try:
    c = a / b
    except Exception as e:
    logging.error("Exception occurred", exc_info=True)
    
    OR simply:
    logging.exception("Exception occurred")
    """

    # Check if log file already exists. If so, rename it adding a timestamp.
    if os.path.isfile(f'{logfileName}.log'):
        timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        shutil.copyfile(f'{logfileName}.log', os.path.join('Logs', f'{logfileName}_{timestamp}.log'))

    logfile_handler = logging.FileHandler(filename=f'{logfileName}.log', mode='w', encoding='utf-8', delay=False, errors='ignore')
    stdout_handler  = logging.StreamHandler(stream=sys.stdout)
    logfile_handler.level = logging.DEBUG
    stdout_handler.level = logging.INFO
    handlers = [logfile_handler, stdout_handler]

    logging.basicConfig(
        level=logging.DEBUG, 
        format='[%(asctime)s] {%(filename)s:%(lineno)d} %(levelname)s - %(message)s',
        datefmt='%y-%b-%d %H.%M.%S',
        handlers=handlers
    )

    logger = logging.getLogger('MEC')

    return logger

# // @staticmethod
def getLogger():
    return logging.getLogger('MEC')

# // @staticmethod
def shutdown(logger: logging.Logger, message: str):
    if message is not None:
        logger.info(f'Closing log file: {message}.')

    for handler in logger.handlers:
        handler.close()
        logger.removeFilter(handler)        
    logging.shutdown()

# def eventRegister(eventName: str, func: callable)->None:
#     handlers = events.get(eventName)
#     if handlers is None:
#         handlers = []
#         events[eventName] = [func]
#     else:
#         handlers.append(func)
#         events[eventName] = handlers

#     return

# def dispatch(eventName:str, data):
#     handlers = events.get(eventName)
#     if handlers is None:
#         raise ValueError(f'Event {eventName} is not registered.')
#     else:
#         for handler in handlers:
#             handler(data)

#     return

# #begin -------------------------------- Example how to use event handler: bootstrap.py
# # from MEClib import eventRegister, dispatch
# def doSomething(anydata):
#     print(f'Event handler doSomething called with {anydata=}')
#     dispatch('doSomething', 'Hello from doSomething')
#     return

# # Register event handler
# eventRegister('doSomething', doSomething)
# # Invoke action which in turn invokes event handler.
# doSomething('Hello from bootstrap')

# #end -------------------------------- Example how to use event handler: bootstrap.py 
    

def expandScenId(scenId: str) -> str:
    """ Inserts a hyphen in-between sequences of 3 characters in scenId. Just for readability. """
    return '-'.join([scenId[i*3:i*3+3] for i in range(5)])

def deflateScenId(id: str) -> int:
    """ Converts a scenario id to a 5-digit integer. """
    if id is None or len(id.strip()) == 0:
        intId = -1
    else:
        intId = int(id[1:3]+id[4:6]+id[7:9]+id[10:12]+id[13:15])
    
    return intId

def unpackGamsSymbol(dfPacked: pd.DataFrame, blen: np.array, unpackAction: str) -> pd.DataFrame:
    """
    Copies dataframe dfPacked and unpacks it backwards into the copy.
    The unpacking may be done safely on elemPacked but will destroy its packed contents.
    Assuming dataframe index is the GAMS time set tt ranging from 1 to 8760.
    blen is an array of integers stating the no. of hours within each block.
    """

    dfUnpacked = dfPacked.copy(deep=True)
    nblock = len(blen)
    unpackAction = unpackAction.lower()
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

def make_autopct(values):
    def my_autopct(pct):
        total = sum(values)/1000
        val = int(round(pct*total/100.0))
        return '{p:1.1f}% ({v:d})'.format(p=pct,v=val)
    return my_autopct

def label_bar(ax, bars, text_format, barValues, barThreshold, heightThreshold, is_inside=True, **kwargs):
    """
    Attach a text label to each bar displaying its y value
    A bar is a patch representing (stacked) bars in a chart.
    In case of a stacked bar chart, the bars collection is enumerated bars[i]
    first in ascending x-axis order, next in ascending y-axis order.
    """

    max_y_value = max(bar.get_height() for bar in bars)
    if is_inside:
        distance = max_y_value * 0.05
    else:
        distance = max_y_value * 0.01

    for ib, bar in enumerate(bars):
        value = barValues[ib]
        if value < barThreshold or bar.get_height() < heightThreshold:
            continue
        
        text = f'{value:{text_format}}'             #--- # text = f'{bar.get_height():{text_format}}'
        text_x = bar.get_x() + bar.get_width() / 2
        if is_inside:
            text_y = bar.get_y() + bar.get_height() / 2 - distance
        else:
            text_y = bar.get_height() + distance

        # if (ib + 1) % 12 == 1:
        #     print(f'DEBUG label_bar: {ib=}, {text_x=}, {text_y=}, {text=}')
            
        ax.text(text_x, text_y, text, ha='center', va='bottom', **kwargs)

def ax_value_labels(ax, df, GT, deci):
    bar_no = 0
    stack_no = 0
    akkum_h = np.zeros(len(df))
    for p in ax.patches:
        b_color = 'black'
        xytext = (p.get_x() + p.get_width() / 2, p.get_height() / 2 + akkum_h[bar_no])
        if int(np.rint(p.get_height())) >= GT and deci > 0:
            ax.annotate(round(p.get_height(),deci),   xytext, ha='center',va='center',xytext=(0, 0), textcoords='offset points', color=b_color, rotation=0)
        elif int(np.rint(p.get_height())) >= GT:
            ax.annotate(int(np.rint(p.get_height())), xytext, ha='center',va='center',xytext=(0, 0), textcoords='offset points', color=b_color, rotation=0)
        akkum_h[bar_no] += p.get_height()
        bar_no +=1
        if bar_no >= len(df):
            bar_no = 0
            stack_no += 1

def getColorMap() -> dict[str]:
    """ Returns two colormaps, one for plants, another for fuels."""
    # Color palletes are added. If there are need for more colors in a category increase the number, 
    # and adjust where we can start and stop using the colors.
    # See also: https://matplotlib.org/stable/gallery/color/colormap_reference.html
    # See also: https://matplotlib.org/stable/tutorials/colors/colormaps.html
    # See also: https://xkcd.com/color/rgb/
    
    ncolor = 15
    BlueColors      = sns.color_palette("Blues",   ncolor)      # Vand- og luftbaseret VP >1 & < 7
    RedColors       = sns.color_palette("Reds",    ncolor)      # 
    GreenColors     = sns.color_palette("YlGn",    ncolor)      # Biomasse > 1
    PurpleColors    = sns.color_palette("Purples", ncolor)      # Luft-VP >3 & <13
    RedPurpleColors = sns.color_palette("RdPu",    ncolor)      # Elkedel > 4 & <11
    GreyColors      = sns.color_palette("Greys",   ncolor)      # Fossil - værdier > 2 & <9
    BrownColors     = sns.color_palette("YlOrBr",  ncolor)      # Affaldsvarme 
    YellowColors    = sns.color_palette("Wistia",  ncolor)      # Sol > 4 & <11
    PinkColors      = sns.color_palette("spring",  ncolor)      # OV > 4 & <11
    
    # Definer farvetema for produktionsenheder   (red,green,blue)
    # Overview of available palettes: https://r02b.github.io/seaborn_palettes/ 
    # Overview of available palettes: https://matplotlib.org/stable/tutorials/colors/colormaps.html
    plantColors = {
                "HoOk"     : GreyColors[-4],             
                "StOk"     : GreyColors[-6],             
                "HoGk"     : GreyColors[-8],  
                "StGk"     : GreyColors[-10],  
                "Ok"       : GreyColors[-4],  
                "Gk"       : GreyColors[-8],  
                
                "MaBio"    : GreenColors[-2],            
                "MaBioGas" : RedColors[-2],            
                "MaNBk"    : GreenColors[-4],           
                "MaNbk"    : GreenColors[-4],           
                "MaNbKV1"  : GreenColors[-6],           
                "HoNFlis"  : GreenColors[-8],           
                "StNFlis"  : GreenColors[-10],            
    
                "MaCool"   : BlueColors[3],              
                "MaCool2"  : BlueColors[5],              
                "Cool"     : BlueColors[5],              
                "MaAff1"   : BrownColors[-5],              
                "MaAff2"   : BrownColors[-6],              
                "MaNAff"   : BrownColors[-6],              
                "Aff"      : BrownColors[-6],              
    
                "HoNEk"    : PinkColors[2],        
                "MaEk"     : PinkColors[4],        
                "MaNEk"    : PinkColors[5],        
                "StEk"     : PinkColors[7],        
                "StNEk"    : PinkColors[8],        
                "Ek"       : PinkColors[3],        
    
                "StNhpSea" : BlueColors[-1],             
                "HoNhpAir" : BlueColors[-3],             
                "StNhpAir" : BlueColors[-5],       
                "MaNhpAir" : BlueColors[-7],       
                "hpAir"    : BlueColors[-3],
                
                "HoNhpSew" : RedPurpleColors[-5],            
                "StNhpSew" : RedPurpleColors[-7],            
                "hpSew"    : RedPurpleColors[-5], 
                
                "HoNhpArla"  : PurpleColors[-1],             
                "HoNhpArla2" : PurpleColors[-1],             
                "HoNhpBirn"  : PurpleColors[-3],             
                "MaNhpPtX"   : PurpleColors[-5],             
                "MaNhpPtx"   : PurpleColors[-5],             
                "Ov"         : PurpleColors[-1],             
                }
    
    # self.fuelUnits = {'BioOlie': 'L', 'FGO':'L', 'Ngas':'m3', 
    #               'Flis':'kg', 'Pellet':'kg', 'Halm':'kg', 'Affald':'kg', 'HPA':'kg', 
    #               'Elec':'MWhe', 'Varme':'MWhq', 'Sol':'MWhq', 'Gratis':'MWhq', 'FoxOV':'MWhq', 'Stenkul':'kg',
    #               'OV-Arla':'MWhq', 'OV-Arla2':'MWhq', 'OV-Birn':'MWhq', 'OV-Ptx':'MWhq'}
    fuelColors = {
            'BioOlie' : GreyColors[2],
            'FGO'     : GreyColors[2],
            'Ngas'    : GreyColors[5],
            'Flis'    : GreenColors[-5],
            'Pellet'  : GreenColors[-8],
            'Halm'    : YellowColors[3],
            'Affald'  : BrownColors[9],
            'HPA'     : GreenColors[-3],
            'Elec'    : BlueColors[5],
            'Varme'   : PurpleColors[-5],
            'Sol'     : YellowColors[1],
            'Gratis'  : PinkColors[1],
            'FoxOV'   : PurpleColors[-4],
            'Stenkul' : GreyColors[1],
            'OV-Arla' : PurpleColors[-1],
            'OV-Arla2': PurpleColors[-1],
            'OV-Birn' : PurpleColors[-2],
            'OV-Ptx'  : PurpleColors[-3],

            'fossilFuel'  : GreyColors[5],
            'biogenFuel'  : GreenColors[5],
            'elecDrive'   : BlueColors[5],
            'surplusHeat' : PurpleColors[5],
            'ambientHeat' : YellowColors[5],
            }
    
    plantColors.update(fuelColors)
    #--- print(color_map)
    
    return plantColors, fuelColors

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

def getVerbosePlantNames() -> dict[str:str]:
    names = {
        # BHP anlæg (Ma = Maabjergværket)
        'MaAff1'     : 'Affaldslinje 1',
        'MaAff2'     : 'Affaldslinje 2',
        'MaBio'      : 'Bio-KVV K3',
        'MaCool'     : 'Bortkøler 1',
        'MaCool2'    : 'Bortkøler 2',
        'MaBioGas'   : 'Biogas KV MEC',
        'MaEk'       : 'Elkedel BHP',
        'MaNEk'      : 'Ny elkedel BHP',
        'MaNAff'     : 'Ny affaldslinje',
        'MaNhpAir'   : 'Luft-VP på BHP',
        'MaNBk'      : 'Ny biokedel BHP',
        'MaNbk'      : 'Ny biokedel BHP',
        'MaNbKV1'    : 'Nyt bio-KVV BHP',
        'MaNhpPtX'   : 'OV fra PtX',
        'MaNhpPtx'   : 'OV fra PtX',
        'MaVak'      : 'Akkutank 5000 m3 BHP',
        'MaNVak1'    : 'Ny akkutank 10.000 m3 BHP',
        'MaNVak2'    : 'Ny akkutank 20.000 m3 BHP',
        'FoxHp'      : 'OV fra FOX til BHP',
        # Holstebro anlæg
        'HoGk'       : 'Gaskedler Holstebro',
        'HoOk'       : 'Oliekedler Holstebro',
        'HoNhpAir'   : 'Luft-VP Holstebro',
        'HoNhpSew'   : 'Spildevands-VP Holstebro',
        'HoNEk'      : 'Ny elkedel Holstebro',
        'HoNFlis'    : 'Fliskedel Holstebro',
        'HoNhpArla'  : 'OV fra Arla 1',
        'HoNhpArla2' : 'OV fra Arla 2',
        'HoNhpBirn'  : 'OV fra Birn',
        'HoNVak'     : 'Ny akkutank Holstebro',
        # Struer anlæg
        'StGk'       : 'Gaskedler Struer',
        'StOk'       : 'Oliekedler Struer',
        'StEk'       : 'Elkedel Struer',
        'StNhpAir'   : 'Luft-VP Struer',
        'StNhpSew'   : 'Spildevands-VP Struer',
        'StNhpSea'   : 'Havvands-VP Struer',
        'StNFlis'    : 'Fliskedel Struer',
        'StNEk'      : 'Ny elkedel Struer',
        'StVak'      : 'Akkutank 300 m3 Struer',
    }
    return names

class Scenario():
    """ 
    Holds data to locate and identify a scenario. 
    File  MECmain<suffix>.gdx is located in folder <rootDir>/<masterDir> and holds data for the entire master iteration.
    Files MEC_Results_<masterIter>_per<period>_Scen_<scenId>.gdx are located in folder <rootDir>/<resultsDir>/<scenId> and hold data for given period and scenario.
    """

    def __init__(self, fullPaths: dict[str:str], scenId: str, scenDesc=None):
        self.defaultScenId = 'default'.lower()
        self.fullPaths = fullPaths
        self.scenId = scenId
        self.Description = scenDesc

        self.isDefault = (scenId.lower() == self.defaultScenId)
        if self.isDefault:
            self.fileName = 'MECmain.gdx'
            self.pathGdx = os.path.join(fullPaths['MasterDir'], self.fileName)
        else:
            self.fileName = f'MECmain_Scen_{scenId}.gdx'
            self.pathGdx = os.path.join(fullPaths['ResultsDir'], scenId, self.fileName)

        # Verify existence of gdx file.
        self.doesExist = os.path.isfile(self.pathGdx)
        if not self.doesExist:
            logger.error(f'Missing file or faulty scenario specification: {self.pathGdx} is not a valid file path.')

        return

    def __str__(self):
        return f'PathGdx:{self.pathGdx}, Description: {self.Description}'
    
    def getPathToPeriodResultsFile(self, period: str, iter: str) -> str:
        # period is a string of the form 'per<period>' where <period> is a 1-based integer.
        # iter is a string of the form 'iter<iter>' where <iter> is a 1-based integer.
        # resultsFilePrefix = 'MEC_Results_<iter>_<period>_Scen_<scenId>' # Prefix of file name of results file.
        if self.isDefault:
            return os.path.join(self.fullPaths['MasterDir'], f'MEC_Results_{iter}_{period}.gdx')
        else:
            return os.path.join(self.fullPaths['ResultsDir'], self.scenId, f'MEC_Results_{iter}_{period}_Scen_{self.scenId}.gdx')

    def getVerboseId(self):
        """ Converts scenario Id to a more readable format """
    
        if self.isDefault:
            return 'Default scenario'
        else:
            # scenId format: mm-ss-uu-rr-ff, all letters representing af 2-digit integer left-padded by zero. 
            # title format:  Scen s.u.r.f  where left-padded zeros are omitted.
            title = 'Scen '
            nparts = 5
            for i in range(1, 5):            # Skip the mm part.
                number = int(self.scenId[3*i + 1 : 3*i + 3])
                title += str(number) 
                if i < nparts - 1:
                    title += '.'
                    
            return title

    # // @staticmethod
    def expandScenId(scenId: str) -> str:
        """ Inserts a hyphen in-between sequences of 3 characters in scenId. Just for readability. """
        return '-'.join([scenId[i*3:i*3+3] for i in range(5)])

    # // @staticmethod
    def deflateScenId(id: str) -> int:
        """ Converts a scenario id to a 5-digit integer. """
        if len(id.strip()) == 0:
            intId = -1
        else:
            intId = int(id[1:3]+id[4:6]+id[7:9]+id[10:12]+id[13:15])
        
        return intId


def convertExcelTime(excelTimestamp: float) -> datetime:
    seconds = (excelTimestamp - 25569) * 24 * 3600
    return datetime.utcfromtimestamp(seconds)

def verifyDir(rootDirPath: str, subDir: str = None):
    """ Verifies that a directory path exists and returns its full path otherwise returns None."""
    path = os.path.join(rootDirPath, subDir) if subDir is not None else rootDirPath
    # path = path.replace('\\', '/')
    if os.path.isdir(path):
        return path
    else:
        logger.error(f'Error in config file: "{path}" is not a valid directory path.')
        return None

def readConfigFile(configPath: str) -> dict:
        """ Read configuration file from file configPath and returns as multilevel dict. """
        # See https://docs.python.org/3/library/tomllib.html
        #--- configPath = os.path.join(os.getcwd(), 'MECcharts.ini')

        with open(configPath, 'rb') as f:
            configAsDict = tomllib.load(f)

        return configAsDict

def per2year(period: int) -> int:
    """ Converts a period number to a year number where period is 1-based."""
    return 2018 + period

# def getScenarioTitle(scen: Scenario) -> str:
#     """ Converts scenario Id to a more readable format """
    
#     # scenId format: mm-ss-uu-rr-ff, all letters representing af 2-digit integer left-padded by zero. 
#     # title format:  Scen s.u.r.f  where left-padded zeros are omitted.
#     scenId = scen.scenId
#     title = 'Scen '
#     nparts = 5
#     for i in range(1, 5):            # Skip the mm part.
#         number = int(scenId[3*i + 1 : 3*i + 3])
#         title += str(number) 
#         if i < nparts - 1:
#             title += '.'
            
#     return title
    

def getScenariosFromExcel() -> dict[str, dict]:
    """ 
    Reads scenario data from Excel file and returns a dictionary of scenarios. 
    Scenarios are sorted by priority in that a dictionary preserves the insertion order.
    """
    global logger, pathRoot

    # Read scenario data from Excel file.
    pathExcel = os.path.join(pathRoot, r'Python\MEC Scenariekørsler.xlsx')
    xlApp = xw.App(visible=False, add_book=False)
    xlApp.display_alerts = False
    wb = xlApp.books.open(pathExcel)  
    sh = wb.sheets['Scenarios']

    # The range of an Excel Table does not include the header row. Add it manually.
    rangeScens = sh.range('TableScens')
    (upperLeft,lowerRight) = rangeScens.address.split(':')  # Absolute address using Excel notation ($-prefix). e.g. $C$13:$J$128'
    (irow, icol) = ExcelTable.convertExcelAddressToIndices(upperLeft)
    upperLeft = ExcelTable.convertIndicesToExcelAddress(irow-1, icol)
    addr = upperLeft + ':' + lowerRight
    dfScens = sh.range(addr).options(pd.DataFrame, index=False, header=True).value
    wb.close()
    xlApp.quit()

    # Convert dataframe to dictionary: key = scenario id, valuie is dictionary of scenario parameters.
    scenarios = list()   # List of scenarios parms.
    for i, row in dfScens.iterrows():
        scenId = row['ScenId']
        if len(scenId.strip()) > 0 and not np.isnan(row['Priority']):
            parms = dict()
            for col in dfScens.columns:
                # //if col != 'ScenId':
                if col in ['S', 'U', 'R', 'F']:
                    parms[col] = int(row[col])  
                else:
                    parms[col] = row[col]

            # Change empty values of parms into None.
            for key in ['MasterIterMax', 'PeriodFirst', 'PeriodLast', 'OnTimeAggr', 'IgnoreMinLoad']:
                if parms[key] is None or parms[key] == '' or np.isnan(parms[key]):
                    parms[key] = np.nan

            scenarios.append(parms)  # // scenarios[scenId] = parms

    # Sort scenarios by priority, then by scenario id by providing a tuple of keys.
    scenarios.sort(key=lambda x: (x['Priority'], x['ScenId']))

    # As of python 3.7, dictionaries remember the order of insertion.
    scenarios = {scen['ScenId']: scen for scen in scenarios}
    logger.info(f'Read {len(scenarios)} scenarios from Excel file {pathExcel}.')

    return scenarios


# // @deprecated("Use getScenariosFromExcel() instead.")
def getScenarios() -> dict[str,str]:
        
    """ Scenario encoding:  mm-ss-uu-rr-ff
            mm: model version
            ss: main scenario id
            uu: sub-scenario id
            rr: roadmap id
            ff: sensitivity id
    """
    scens = { # Key is scenario-id, Value is short name.     Include letter T if a scenario is just for testing and set doTest = True.
            #   'T11s99u10r00f00': { 'title': 'TestScenarie', 'refscen': ''},                  # Bruges til afprøvning af scripting.

            # 'm11s20u00r00f00': { 'title': 'Uden nye anlaeg', 'refscen': ''},

            # Plan A begins here ---------------------------------------------

            # 'm11s21u00r00f00': { 'title': 'Plan A: Aff 80 kton, -Levetid Aff', 'refscen': ''},
            # 'm11s21u00r01f00': { 'title': 'Plan A: Aff 80 kton, -Levetid Aff', 'refscen': 'm11s21u00r00f00'},
            # 'm11s21u01r00f00': { 'title': 'Plan A: Aff 80 kton, -Levetid Aff, MaNbKV1 tvang', 'refscen': ''},
            # 'm11s21u02r00f00': { 'title': 'Plan A: Aff 80 kton, -Levetid Aff, -lokale Luft-VP', 'refscen': ''},
            # 'm11s21u03r00f00': { 'title': 'Plan A: Aff 80 kton, -Levetid Aff, Elspot +200', 'refscen': ''},
            # 'm11s21u04r00f00': { 'title': 'Plan A: Aff 80 kton, -Levetid Aff, Invest. +20 pct', 'refscen': ''},
            # 'm11s21u05r00f00': { 'title': 'Plan A: Aff 80 kton, -Levetid Aff, kun lokale elkedler', 'refscen': ''},
            # 'm11s21u05r01f00': { 'title': 'Plan A: Aff 80 kton, -Levetid Aff, kun lokale elkedler', 'refscen': 'm11s21u05r00f00'},

            # 'm11s22u00r00f00': { 'title': 'Plan A: Aff 80 kton, 0 fra 2028, -Levetid Aff', 'refscen': ''},
            # 'm11s22u00r01f00': { 'title': 'Plan A: Aff 80 kton, 0 fra 2028, -Levetid Aff', 'refscen': 'm11s22u00r00f00'},
            # 'm11s22u01r00f00': { 'title': 'Plan A: Aff 80 kton, 0 fra 2028, -Levetid Aff, MaNbKV1 tvang', 'refscen': ''},
            # 'm11s22u02r00f00': { 'title': 'Plan A: Aff 80 kton, 0 fra 2028, -Levetid Aff, -lokale Luft-VP', 'refscen': ''},
            # 'm11s22u03r00f00': { 'title': 'Plan A: Aff 80 kton, 0 fra 2028, -Levetid Aff, Elspot +200', 'refscen': ''},
            # 'm11s22u04r00f00': { 'title': 'Plan A: Aff 80 kton, 0 fra 2028, -Levetid Aff, Invest. +20 pct', 'refscen': ''},
            # 'm11s22u05r00f00': { 'title': 'Plan A: Aff 80 kton, 0 fra 2028, -Levetid Aff, kun lokale elkedler', 'refscen': ''},
            # 'm11s22u05r01f00': { 'title': 'Plan A: Aff 80 kton, 0 fra 2028, -Levetid Aff, kun lokale elkedler', 'refscen': 'm11s22u05r00f00'},

            # 'm11s24u00r00f00': { 'title': 'Plan A: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2', 'refscen': ''},
            # 'm11s24u00r01f00': { 'title': 'Plan A: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2', 'refscen': 'm11s24u00r00f00'},
            # 'm11s24u01r00f00': { 'title': 'Plan A: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, MaNbKV1 tvang', 'refscen': ''},
            # 'm11s24u02r00f00': { 'title': 'Plan A: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, -lokale Luft-VP', 'refscen': ''},
            # 'm11s24u03r00f00': { 'title': 'Plan A: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, Elspot +200', 'refscen': ''},
            # 'm11s24u04r00f00': { 'title': 'Plan A: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, Invest. +20 pct', 'refscen': ''},
            # 'm11s24u05r00f00': { 'title': 'Plan A: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, kun lokale elkedler', 'refscen': ''},
            # 'm11s24u05r01f00': { 'title': 'Plan A: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, kun lokale elkedler', 'refscen': 'm11s24u05r00f00'},

            # 'm11s25u00r00f00': { 'title': 'Plan A: Aff 120 kton, -Levetid', 'refscen': ''},
            # 'm11s25u00r01f00': { 'title': 'Plan A: Aff 120 kton, -Levetid', 'refscen': 'm11s25u00r00f00'},
            # 'm11s25u01r00f00': { 'title': 'Plan A: Aff 120 kton, -Levetid, MaNbKV1 tvang', 'refscen': ''},
            # 'm11s25u02r00f00': { 'title': 'Plan A: Aff 120 kton, -Levetid, -lokale Luft-VP', 'refscen': ''},
            # 'm11s25u03r00f00': { 'title': 'Plan A: Aff 120 kton, -Levetid, Elspot +200', 'refscen': ''},
            # 'm11s25u04r00f00': { 'title': 'Plan A: Aff 120 kton, -Levetid, Invest. +20 pct', 'refscen': ''},
            'm11s25u05r00f00': { 'title': 'Plan A: Aff 120 kton, -Levetid, kun lokale elkedler', 'refscen': ''},
            # 'm11s25u05r01f00': { 'title': 'Plan A: Aff 120 kton, -Levetid, kun lokale elkedler', 'refscen': 'm11s25u05r00f00'},

            # 'm11s26u00r00f00': { 'title': 'Plan A: Aff 120 kton, +Levetid begge Aff', 'refscen': ''},
            # 'm11s26u00r01f00': { 'title': 'Plan A: Aff 120 kton, +Levetid begge Aff', 'refscen': 'm11s26u00r00f00'},
            # 'm11s26u01r00f00': { 'title': 'Plan A: Aff 120 kton, +Levetid begge Aff, MaNbKV1 tvang', 'refscen': ''},
            # 'm11s26u02r00f00': { 'title': 'Plan A: Aff 120 kton, +Levetid begge Aff, -lokale Luft-VP', 'refscen': ''},
            # 'm11s26u03r00f00': { 'title': 'Plan A: Aff 120 kton, +Levetid begge Aff, Elspot +200', 'refscen': ''},
            # 'm11s26u04r00f00': { 'title': 'Plan A: Aff 120 kton, +Levetid begge Aff, Invest. +20 pct', 'refscen': ''},
            'm11s26u05r00f00': { 'title': 'Plan A: Aff 120 kton, +Levetid begge Aff, kun lokale elkedler', 'refscen': ''},
            # 'm11s26u05r01f00': { 'title': 'Plan A: Aff 120 kton, +Levetid begge Aff, kun lokale elkedler', 'refscen': 'm11s26u05r00f00'},

            # 'm11s27u00r00f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, -Levetid', 'refscen': ''},
            # 'm11s27u00r01f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, -Levetid', 'refscen': 'm11s27u00r00f00'},
            # 'm11s27u01r00f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, -Levetid, MaNbKV1 tvang', 'refscen': ''},
            # 'm11s27u02r00f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, -Levetid, -lokale Luft-VP', 'refscen': ''},
            # 'm11s27u03r00f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, -Levetid, Elspot +200', 'refscen': ''},
            # 'm11s27u04r00f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, -Levetid, Invest. +20 pct', 'refscen': ''},
            'm11s27u05r00f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, -Levetid, kun lokale elkedler', 'refscen': ''},
            # 'm11s27u05r01f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, -Levetid, kun lokale elkedler',  'refscen': 'm11s27u05r01f00'},
            # 'm11s27u05r02f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, elkedel subst. luft-VP på BHP',  'refscen': 'm11s27u05r02f00'},
            # 'm11s27u05r03f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, Luft-VP = 20, Biokedel = 20',    'refscen': 'm11s27u05r03f00'},
            # 'm11s27u05r04f00': { 'title': 'Plan A: Aff 120 kton, 0 fra 2028, Bio-KVV subst. biokedel på BHP', 'refscen': 'm11s27u05r04f00'},

            # Plan A ends here ---------------------------------------------

            # Plan B begins here ---------------------------------------------

            # 'm11s31u00r00f30': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s31u00r00f31': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s31u00r00f32': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s31u00r00f33': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s31u00r00f34': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s32u00r00f30': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s32u00r00f31': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s32u00r00f32': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s32u00r00f33': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s32u00r00f34': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s34u00r00f30': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s34u00r00f31': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s34u00r00f32': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s34u00r00f33': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s34u00r00f34': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s35u00r00f30': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s35u00r00f31': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s35u00r00f32': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s35u00r00f33': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s35u00r00f34': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s36u00r00f30': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s36u00r00f31': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s36u00r00f32': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s36u00r00f33': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s36u00r00f34': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s37u00r00f30': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s37u00r00f31': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s37u00r00f32': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s37u00r00f33': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s37u00r00f34': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=100', 'refscen': ''},

            # Centrale anlaeg u05 ---------------------------------------------
            
            # 'm11s31u05r00f30': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s31u05r00f31': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s31u05r00f32': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s31u05r00f33': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s31u05r00f34': { 'title': 'Plan B: Aff 80 kton, -Levetid Aff, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s32u05r00f30': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s32u05r00f31': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s32u05r00f32': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s32u05r00f33': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s32u05r00f34': { 'title': 'Plan B: Aff 80 kton, 0 fra 2028, -Levetid Aff, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s34u05r00f30': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s34u05r00f31': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s34u05r00f32': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s34u05r00f33': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s34u05r00f34': { 'title': 'Plan B: Aff 80 kton, Aff2 efter Aff1, +Levetid Aff2, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s35u05r00f30': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s35u05r00f31': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s35u05r00f32': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s35u05r00f33': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s35u05r00f34': { 'title': 'Plan B: Aff 120 kton, -Levetid, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s36u05r00f30': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s36u05r00f31': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s36u05r00f32': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s36u05r00f33': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s36u05r00f34': { 'title': 'Plan B: Aff 120 kton, +Levetid begge Aff, PtX 30 MW, OVpris=100', 'refscen': ''},

            # 'm11s37u05r00f30': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=1', 'refscen': ''},
            # 'm11s37u05r00f31': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=25', 'refscen': ''},
            # 'm11s37u05r00f32': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=50', 'refscen': ''},
            # 'm11s37u05r00f33': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=75', 'refscen': ''},
            # 'm11s37u05r00f34': { 'title': 'Plan B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=100', 'refscen': ''},

            # Plan B ends here ---------------------------------------------

            # 'm11s37u05r02f30': { 'title': 'Plan A+B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=1',   'refscen': 'm11s27u05r01f00'},
            # 'm11s37u05r02f31': { 'title': 'Plan A+B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=25',  'refscen': 'm11s27u05r01f00'},
            # 'm11s37u05r02f32': { 'title': 'Plan A+B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=50',  'refscen': 'm11s27u05r01f00'},
            # 'm11s37u05r02f33': { 'title': 'Plan A+B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=75',  'refscen': 'm11s27u05r01f00'},
            # 'm11s37u05r02f34': { 'title': 'Plan A+B: Aff 120 kton, 0 fra 2028, -Levetid, PtX 30 MW, OVpris=100', 'refscen': 'm11s27u05r01f00'},

            }

    return scens

