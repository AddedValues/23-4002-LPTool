# -*- coding: utf-8 -*-
"""
Created on Tue Apr  4 13:00:47 2023

@author: MogensBechLaursen
"""

import sys
import os
import inspect             # Inspection of the python stack.
import logging
import locale
import numpy as np
import pandas as pd
from dataclasses import dataclass
from datetime import datetime, timedelta
# import GdxWrapper as gw
# import matplotlib.pyplot as plt
# from matplotlib import cm
import seaborn as sns # Importing color palettes

global CONST, MEAN
CONST: str = 'const' # Assign the packed (aggregated) value of the block to the unpacked value.
MEAN : str = 'mean'  # Assign the average of the block to the unpacked value.

MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAJ', 'JUN', 'JUL', 'AUG', 'SEP', 'OKT', 'NOV', 'DEC', 'ÅR']


def whoami():
    s = inspect.stack()
    return [ s[1][3], s[2][3] ]  # function and caller names.

def init(logfileName: str) -> logging.Logger:
    
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

    logfile_handler = logging.FileHandler(filename=f'{logfileName}.log')
    stdout_handler  = logging.StreamHandler(stream=sys.stdout)
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

def shutdown(logger: logging.Logger, message: str):
    if message is not None:
        logger.info('Closing log file.')

    for handler in logger.handlers:
        handler.close()
        # logger.removeFilter(handler)        
    logging.shutdown()


def expandScenId(scenId: str) -> str:
    """ Inserts a hyphen in-between sequences of 3 characters in scenId. Just for readability. """
    return '-'.join([scenId[i*3:i*3+3] for i in range(5)])


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
                "HoOk"     : GreyColors[2],             
                "StOk"     : GreyColors[3],             
                "HoGk"     : GreyColors[5],  
                "StGk"     : GreyColors[6],  
                "Ok"       : GreyColors[2],  
                "Gk"       : GreyColors[5],  
                 
                "MaNBk"    : GreenColors[-3],           
                "MaNbioKVV": GreenColors[-4],           
                "HoNFlis"  : GreenColors[-5],           
                "StNFlis"  : GreenColors[-6],            
                "MaBio"    : GreenColors[-3],            
                "MaBioGas" : RedColors[-2],            
    
                "MaCool"   : BlueColors[3],              
                "MaCool2"  : BlueColors[5],              
                "Cool"     : BlueColors[5],              
                "MaAff1"   : BrownColors[-3],              
                "MaAff2"   : BrownColors[-4],              
                "MaNAff"   : BrownColors[-5],              
                "Aff"      : BrownColors[9],              
    
                "HoNEk"    : PinkColors[1],        
                "MaEk"     : PinkColors[2],        
                "StNEk"    : PinkColors[3],        
                "StEk"     : PinkColors[4],        
                "Ek"       : PinkColors[1],        
    
                "StNhpSea" : BlueColors[-1],             
                "HoNhpAir" : BlueColors[-3],             
                "StNhpAir" : BlueColors[-4],       
                "hpAir"    : BlueColors[-3],
                 
                "HoNhpSew" : RedPurpleColors[-3],            
                "StNhpSew" : RedPurpleColors[-4],            
                "hpSew"    : RedPurpleColors[1], 
                 
                "Ov-Arla"  : PurpleColors[-1],             
                "Ov-Birn"  : PurpleColors[-3],             
                "Ov-PtX"   : PurpleColors[-5],             
                "Ov"       : PurpleColors[-5],             
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
            'Elec'    : BlueColors[1],
            'Varme'   : PurpleColors[-5],
            'Sol'     : YellowColors[1],
            'Gratis'  : PinkColors[1],
            'FoxOV'   : PurpleColors[-4],
            'Stenkul' : GreyColors[1],
            'OV-Arla' : PurpleColors[-1],
            'OV-Arla2': PurpleColors[-1],
            'OV-Birn' : PurpleColors[-2],
            'OV-Ptx'  : PurpleColors[-3]
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
        'MaNAff'     : 'Ny affaldslinje',
        'MaNBk'      : 'Ny biokedel BHP',
        'MaNBioKVV'  : 'Ny bio-KVV BHP',
        'MaNhpPtX'   : 'OV fra PtX',
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
        'HoNhpArla'  : 'OV fra Arla 1',
        'HoNhpArla2' : 'OV fra Arla 2',
        'HoNhpBirn ' : 'OV fra Birn',
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


def getScenarioTitle(scenId: str) -> str:
    """ Converts scenario Id to a more readable format """
    
    # scenId format: mm-ss-uu-rr-ff, all letters representing af 2-digit integer left-padded by zero. 
    # title format:  Scen s.u.r.f  where left-padded zeros are omitted.
    title = 'Scen '
    nparts = 5
    for i in range(1, 5):            # Skip the mm part.
        number = int(scenId[3*i + 1 : 3*i + 3])
        title += str(number) 
        if i < nparts - 1:
            title += '.'
            
    return title
    
    
def convertExcelTime(excelTimestamp: float) -> datetime:
    seconds = (excelTimestamp - 25569) * 24 * 3600
    return datetime.utcfromtimestamp(seconds)

#----------------------------------------------------  StatsMecF  ----------------------------------------------------
def extractAllTopicsMecFYearly(topics: list[str], dfIter: pd.DataFrame, periods: list[int]) -> dict[pd.DataFrame()]:
    """ Extracts all topics from records of StatsMecF (dfIter) and returns as dict with topic as key. """
    tables = dict()
    for topic in topics:
        tables[topic] = getTopicMecFAsTableYearly(topic, dfIter, periods, aggrFunc='sum')

    return tables        


def getTopicMecFAsTableYearly(topic: str, dfIter: pd.DataFrame, periods: list[int], aggrFunc: str ='sum') -> pd.DataFrame: 
    """ Extracts a topic as a table with fuel  name as index and calendar years as columns. """

    df = (dfIter[dfIter.topicMecF == topic]).drop(columns=['topicMecF'])
    df = pd.pivot_table(df, index='f', columns='perA', values='value', aggfunc=aggrFunc)

    # Aggregate monthly values for each period (year).
    per2year = {'per' + str(p): str(2025 + p - periods[0]) for p in periods}
    per = ['per' + str(p) for p in periods]
    df = df[per]                        # Reorder periods ascendingly
    df = df.rename(columns=per2year)    # Replace periods with calendar years

    # Replace tiny values with zero.
    df2 = df.copy(deep=True)
    for col in df2.columns:
        for i in df2.index:
            if abs(df2.loc[i,col]) < 1E-10:
                df2.loc[i,col] = 0.0
    
    return df2

#----------------------------------------------------  StatsMecU  ----------------------------------------------------
def extractAllTopicsMecUYearly(topics: list[str], dfIter: pd.DataFrame, periods: list[int]) -> dict[pd.DataFrame()]:
    """ Extracts all topics from records of StatsMecU (dfIter) and returns as dict with topic as key. """
    tables = dict()
    for topic in topics:
        if 'price' in topic.lower():  # Average prices shall be weighed by associated heat amount.
            continue
        tables[topic] = getTopicMecUAsTableYearly(topic, dfIter, periods, aggrFunc='sum')

    return tables        
    

def extractAllTopicsMecUMonthly(period: str, topics: list[str], dfIter: pd.DataFrame, periods: list[int]) -> dict[pd.DataFrame()]:
    """ Extracts all topics from records of StatsMecU (dfIter) and returns as dict with topic as key. """

    # Reduce dfIter to the desired year (period).    
    dfIter = (dfIter[dfIter.perA == period]).drop(columns=['perA'])

    tables = dict()
    for topic in topics:
        tables[topic] = getTopicMecUAsTableMonthly(topic, period, dfIter, periods)

    return tables        


def getTopicMecUAsTableYearly(topic: str, dfIter: pd.DataFrame, periods: list[int], aggrFunc: str ='sum') -> pd.DataFrame: 
    """ Extracts a topic as a table with plant name as index and calendar years as columns. """

    df = (dfIter[dfIter.topicMecU == topic]).drop(columns=['topicMecU'])
    df = pd.pivot_table(df, index='uall', columns='perA', values='value', aggfunc=aggrFunc)

    # Aggregate monthly values for each period (year).
    per2year = { 'per' + str(p): str(2025 + p - periods[0]) for p in periods}
    per = ['per' + str(p) for p in periods]
    df = df[per]                        # Reorder periods ascendingly
    df = df.rename(columns=per2year)    # Replace periods with calendar years

    # Replace tiny values with zero.
    df2 = df.copy(deep=True)
    for col in df2.columns:
        for i in df2.index:
            if abs(df2.loc[i,col]) < 1E-10:
                df2.loc[i,col] = 0.0
    
    return df2


def getTopicMecUAsTableMonthly(topic: str, period: str, dfIter: pd.DataFrame, periods: list[int]) -> pd.DataFrame: 
    """ Extracts a topic as a table with plant name as index and calendar months of period as columns. """
    
    df = dfIter
    if 'perA' in df.columns:
        df = (df[df.perA == period]).drop(columns=['perA'])
        
    df = (df[df.topicMecU == topic]).drop(columns=['topicMecU'])
    df = df.pivot(index='uall', columns='moyr', values='value')
    months = ['mo' + str(i) for i in range(1, 12 + 1)] + ['moall']
    df = df[months]                                                                  # Reorder months ascendingly.
    df = df.rename(columns={ months[i] : MONTHS[i] for i in range(len(months))} )    # Replace months with abbreviated names.
    
    # Replace tiny values with zero.
    df2 = df.copy(deep=True)
    for col in df2.columns:
        for i in df2.index:
            if abs(df2.loc[i,col]) < 1E-10:
                df2.loc[i,col] = 0.0
    
    return df2

                    
def getCleanTopic(topic: str, tables: dict[str], activePlants: list[str]) -> pd.DataFrame:
    """ Returns a table (dataframe) of topic, cleaned of inactive plants and transposed, where plants as columns.
    """
    
    if topic not in tables:
        raise ValueError(f'{topic=} does not appear in tables.')
        
    dfTopic = (tables[topic]).T
    dropColumns = [u for u in dfTopic.columns if u not in activePlants]
    dfTopic.drop(columns=dropColumns, inplace=True)
    dfTopic = dfTopic[activePlants]

    return dfTopic


@dataclass()
class Item():
    active       : bool             # If True, the item is retrieved from the gdx-file.
    gdxName      : str              # Name of GAMS symbol
    dfName       : str              # Column name of each retrieved array.
    gdxDim       : str              # Name of fixed set in GAMS symbol
    pyList       : list[str]        # Python list holding the fixed set to iterate over (None is symbol is 1-D)
    unpackAction : str         # Valid entries:None, 'const', 'mean'
    doClip       : bool = False     # If True, clip the retrieved arrays below a lower bound to zero.
    


    