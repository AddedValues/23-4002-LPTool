# -*- coding: utf-8 -*-

import GdxWrapper as gw
import pandas as pd
from datetime import datetime, timedelta
import numpy as np
import matplotlib.pyplot as plt
import openpyxl
import xlwings as xw
from openpyxl.utils import get_column_letter
from matplotlib import cm
import os
#import plotly.express as px
import seaborn as sns #Importing color palettes
import locale
locale.setlocale(locale.LC_TIME, 'da_DK.UTF-8')
from itertools import repeat

def make_autopct(values):
    def my_autopct(pct):
        total = sum(values)/1000
        val = int(round(pct*total/100.0))
        return '{p:1.1f}% ({v:d})'.format(p=pct,v=val)
    return my_autopct

def label_bar(ax, bars, text_format, is_inside=True, **kwargs):
    """
    Attach a text label to each bar displaying its y value
    """
    max_y_value = max(bar.get_height() for bar in bars)
    if is_inside:
        distance = max_y_value * 0.05
    else:
        distance = max_y_value * 0.01

    for bar in bars:
        text = text_format.format(bar.get_height())
        text_x = bar.get_x() + bar.get_width() / 2
        if is_inside:
            text_y = bar.get_height() - distance
        else:
            text_y = bar.get_height() + distance

        ax.text(text_x, text_y, text, ha='center', va='bottom', **kwargs)

def ax_value_labels(ax,df,GT,deci):
    bar_no = 0
    stack_no = 0
    akku_h = np.zeros(len(df))
    for p in ax.patches:
        b_color = 'black'
        if df.columns[stack_no] == 'Br (elkedel)':
            b_color = 'white'
        if int(np.rint(p.get_height())) >= GT and deci > 0:
            ax.annotate(round(p.get_height(),deci), (p.get_x()+p.get_width()/2., p.get_height()/2.+akku_h[bar_no]), ha='center',va='center',xytext=(0, 0),textcoords='offset points',color=b_color,rotation=0)
        elif int(np.rint(p.get_height())) >= GT:
            ax.annotate(int(np.rint(p.get_height())), (p.get_x()+p.get_width()/2., p.get_height()/2.+akku_h[bar_no]), ha='center',va='center',xytext=(0, 0),textcoords='offset points',color=b_color,rotation=0)
        akku_h[bar_no] += p.get_height()
        bar_no +=1
        if bar_no >= len(df):
            bar_no = 0
            stack_no += 1

#Color palletes are added. If there are need for more colors in a category increase the number, 
#and adjust where we can start and stop using the colors
BlueColors = sns.color_palette("Blues",18)          # Vandbaseret-VP >1 & < 7
RedColors  = sns.color_palette("Reds",15)            # Affaldsvarme >3 & <8
GreenColors = sns.color_palette("YlGn",18)        # Biomasse > 1
PurpleColors  = sns.color_palette("Purples",15)     # Luft-VP >3 & <13
RedPurpleColors = sns.color_palette("RdPu",15)           # Elkedel > 4 & <11
GreyColors  = sns.color_palette("Greys",15)         # Fossil - værdier > 2 & <9
BrownColors  = sns.color_palette("YlOrBr",15)      # Geotermi -værdier < 5 
YellowColors = sns.color_palette("Wistia",15)      # Sol > 4 & <11
PinkColors = sns.color_palette("pink",15)      # OV > 4 & <11



#% definer farvetema for produktionsenheder   (red,green,blue)
color_map = {"GeEFgo"   : GreyColors[3],
             "ByEFgo"   : GreyColors[4],
             "AaEFgo"   : GreyColors[5],
             "VeEFgo"   : GreyColors[6],
             "JjEFgo"   : GreyColors[7], 
             "OdEFgo"   : GreyColors[8],
             "HoEFgo"   : GreyColors[9], 
             "MaEFgo"   : GreyColors[10],
             "Fgo"      : GreyColors[6], 
             "Ov"       : PinkColors[5],   
             "LiEAv"    : RedColors[9],
             "SkEAv"    : RedColors[7], 
             "LiEBKVV"  : GreenColors[14], 
             "StBKVV"   : GreenColors[12], 
             "StESSV3"  : GreenColors[10],
             "LiFk1"    : GreenColors[8],
             "LiFk2"    : GreenColors[6], 
             "StFk1"    : GreenColors[4], 
             "StEk1"    : RedPurpleColors[5],
             "LiEk1"    : RedPurpleColors[6],
             "MoEk1"    : RedPurpleColors[7],
             "OdEk1"    : RedPurpleColors[8],
             "HoEk1"    : RedPurpleColors[9],
             "Ek"       : RedPurpleColors[7],
             "LiVp1"    : PurpleColors[6],
             "OdVp1"    : PurpleColors[8],
             "HoVp1"    : PurpleColors[10],
             "RiVp1"    : BlueColors[14],
             "AaVp2"    : BlueColors[12],
             "ChVp1"    : BlueColors[10],
             "AaVp1"    : BlueColors[8],
             "StVp1"    : BlueColors[6],
             "StVp2"    : BlueColors[4],
             "VeGeo1"   : BrownColors[3],
             "VeGeo2"   : BrownColors[4],
             "AaGeo1"   : BrownColors[5], 
             "AbGeo1"   : BrownColors[6],
             "ChGeo1"   : BrownColors[7],
             "ByGeo1"   : BrownColors[8],
             "JjGeo1"   : BrownColors[9],
             "HhGeo1"   : BrownColors[10],
             "GeGeo1"   : BrownColors[11],
             "Geo"      : BrownColors[6], 
             }

#print(color_map)
xtick_lab = ['2018','2019','2020','2021','2022','2023','2024','2025','2026','2027','2028','2029','2030','2031','2032','2033','2034','2035','2036','2037','2038','2039','2040','2041','2042','2043','2044','2045','2046','2047','2048','2049','2050']

#my_path = os.path.dirname(os.path.abspath("__file__")) # Figures out the absolute path for you in case your working directory moves around.
my_path = os.path.dirname(__file__)

res_dir = r"C:\AddedValues Dropbox\GAMS\AVA\INVOPT_2023_03_24_c99cb1/Results/" 
per = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33]
index_df = ['2018','2019','2020','2021','2022','2023','2024','2025','2026','2027','2028','2029','2030','2031','2032','2033','2034','2035','2036','2037','2038','2039','2040','2041','2042','2043','2044','2045','2046','2047','2048','2049','2050','2051','2052','2053','2054','2055','2056','2057','2058','2059','2060','2061']

group_geo = 1 #gruppering af ens anlæg i plots
group_fgo = 1 #gruppering af ens anlæg i plots
group_ek  = 1 #gruppering af ens anlæg i plots

#%% Udvælgelse af scen 

scen = {#'14101010000': "Scen 1.1.0.0, ingen bio",
        #'14101020000': "Scen 1.2.0.0, bio u/KV",
        #'14101020100': "Scen 1.2.1.0, bio u/KV",
        #'14101050000': "Scen 1.5.0.0, bio ok",
        '14102010000': "Scen 2.1.0.0, ingen bio, FW elpris",
        '14102020000': "Scen 2.2.0.0, bio u/KV, FW elpris",
        '14102050000': "Scen 2.5.0.0, bio ok, FW elpris",
        #'14103010000': "Scen 3.1.0.0, TN25 lav",
        #'14104010000': "Scen 4.1.0.0, stor VAK",
        '14104020000': "Scen 4.2.0.0, lille sæson",
        '14104030000': "Scen 4.3.0.0, mellem sæson",
        #'14105010000': "Scen 5.1.0.0, nul geo",
        #'14106010000': "Scen 6.1.0.0, nul CC",
        #'14106020000': "Scen 6.2.0.0, CC affald",
        #'14107010000': "Scen 7.1.0.0, red. VPA",
        '14108010000': "Scen 8.1.0.0, Eksl. ST site", 
        #'14108010100': "Scen 8.1.1.0, Eksl. ST site", 
        #'14108010200': "Scen 8.1.2.0, Eksl. ST site, 100 MW luft-VP", 
        #'14108030000': "Scen 8.3.0.0, SSV3 2035",      
} # Scenarios to run
start_y = 8
years_plot = 21

years = [index_df[start_y-1]]
for i in range(25):
    years.append(index_df[start_y+i])
    
df_scens = pd.DataFrame()
for scenario in scen:
    srs_dir = res_dir+"AVAMasterOutput_"+scenario+".xlsm"
    df = pd.read_excel(srs_dir, index_col=0, sheet_name = 'Overview', skiprows = 46,  nrows= 49, usecols = 'E:AE', header=None, names=['Unit']+years)
    df = df.T
    df['VarTot'] = pd.read_excel(srs_dir, index_col=0, sheet_name = 'Overview', skiprows = 10,  nrows= 1, usecols = 'E:AE', header=None, names=['VarTot']+years).T
    df['VarTot'] = -df['VarTot'] 
    df_scens[scen[scenario]] = df.T.sum()/1e6
df_scens = df_scens.loc[index_df[start_y-1]:index_df[start_y-1+years_plot-1]]

ax = df_scens.plot(figsize=(9, 5.5))
ax.legend(loc='center',bbox_to_anchor=(1.25,0.5))
ax.set_ylabel('Totale var. omkst. + faste udgifter på nye anlæg (Mkr)')
#plt.yticks(np.arange(45, 75, 2.0))
ax.set_xlabel('Årstal')
ax.grid()
fig_name = 'var_omkst_sammenligning.svg'
plt.savefig(os.path.join(my_path, fig_name),facecolor="none",bbox_inches='tight')

with pd.ExcelWriter(os.path.join(my_path, "scenarie_summary.xlsx")) as writer:  
    df_scens.T.to_excel(writer, sheet_name='results') 

#% co2
df_scens_co2 = pd.DataFrame()
for scenario in scen:
    srs_dir = res_dir+"AVAMasterOutput_"+scenario+".xlsm"
    df = pd.read_excel(srs_dir, index_col=0, sheet_name = 'Overview', skiprows = 403,  nrows= 33, usecols = 'E:AE', header=None, names=['Unit']+years)
    df = df.T
    df_scens_co2[scen[scenario]] = df.T.sum()/1e3
df_scens_co2 = df_scens_co2.loc[index_df[start_y-1]:index_df[start_y-1+years_plot-1]]

ax = df_scens_co2.plot(figsize=(9, 5.5))
ax.legend(loc='center',bbox_to_anchor=(1.4,0.5))
ax.set_ylabel('Regulatorisk CO2 udledning (kton)')
#plt.yticks(np.arange(45, 75, 2.0))
ax.set_xlabel('Årstal')
ax.grid()
#ax.set_ylim([40, 70]) 
#ax.set_xlim(["2024", "2033"]) 
fig_name = 'Co2_sammenligning.svg'
plt.savefig(os.path.join(my_path, fig_name),facecolor="none",bbox_inches='tight')

with pd.ExcelWriter(os.path.join(my_path, "scenarie_summary_co2_kton.xlsx")) as writer:  
    df_scens_co2.T.to_excel(writer, sheet_name='results') 

#% Varmeproduktion total henover planperiode
Od_med = 0 #1 hvis Odder er med fra 2030 og frem
DmdGainHo = np.array([1.12, 1.12, 1.12 ,1.12 ,1.12 ,1.12 ,1.15 ,1.13, 1.14, 1.14, 1.14, 1.14, 1.15, 1.13, 1.12, 1.12, 1.12, 1.13, 1.13, 1.13, 1.14, 1.14, 1.14, 1.15, 1.15, 1.15])
DmdGainRi = np.array([1.12, 1.13, 1.15, 1.16, 1.17, 1.18, 1.19, 1.18, 1.19, 1.18, 1.18,	1.18, 1.18, 1.18, 1.18, 1.18, 1.18, 1.18, 1.18, 1.18, 1.17, 1.17, 1.17, 1.17, 1.16,	1.16])
DmdGainLi = np.array([1.37, 1.46, 1.56, 1.65, 1.74, 1.84, 1.92, 1.96, 2.01, 2.07, 2.12,	2.17, 2.23, 2.26, 2.30, 2.36, 2.41, 2.47, 2.52, 2.58, 2.63, 2.69, 2.74, 2.80, 2.85,	2.85])
DmdGainVe = np.array([1.11, 1.12, 1.11, 1.12, 1.12, 1.12, 1.12, 1.12, 1.12, 1.11, 1.11,	1.11, 1.11, 1.11, 1.11, 1.11, 1.11, 1.11, 1.10, 1.10, 1.10, 1.09, 1.09, 1.09, 1.09,	1.09])
DmdGainCh = np.array([1.40, 1.41, 1.42, 1.42, 1.43, 1.44, 1.44, 1.44, 1.44, 1.44, 1.42,	1.42, 1.42, 1.43, 1.43, 1.43, 1.43, 1.42, 1.42, 1.42, 1.43, 1.43, 1.43, 1.43, 1.43,	1.43])
DmdGainAa = np.array([1.02, 1.01, 1.01, 1.01, 1.01, 1.01, 1.00, 0.99, 0.99, 0.99, 0.99,	0.99, 0.99, 0.99, 0.99, 0.99, 0.96, 0.94, 0.94, 0.94, 0.93, 0.93, 0.92, 0.92, 0.92,	0.92])
DmdGainTi = np.array([1.23, 1.26, 1.29, 1.32, 1.35, 1.38, 1.39, 1.41, 1.42, 1.44, 1.45,	1.46, 1.48, 1.49, 1.50, 1.52, 1.53, 1.55, 1.56, 1.57, 1.59, 1.60, 1.62, 1.63, 1.64,	1.64])
DmdGainAb = np.array([0.90, 0.90, 0.91, 0.91, 0.92, 0.92, 0.92, 0.92, 0.92, 0.91, 0.91,	0.91, 0.91, 0.90, 0.90, 0.89, 0.88, 0.88, 0.87, 0.87, 0.87, 0.87, 0.87, 0.87, 0.86,	0.86])
DmdGainGe = np.array([1.08, 1.07, 1.08, 1.08, 1.08,	1.07, 1.08,	1.08, 1.07, 1.07, 1.07,	1.07, 1.07, 1.08, 1.08, 1.09, 1.09, 1.09, 1.10, 1.10, 1.10, 1.10, 1.10, 1.10, 1.10,	1.10])
DmdGainHh = np.array([1.08, 1.09, 1.10, 1.10, 1.11,	1.10, 1.10,	1.09, 1.09, 1.08, 1.07,	1.07, 1.07, 1.06, 1.06, 1.06, 1.05, 1.05, 1.05, 1.04, 1.03, 1.03, 1.02, 1.02, 1.00,	1.00])
DmdGainKo = np.array([1.17, 1.18, 1.19, 1.19, 1.20,	1.20, 1.21,	1.21, 1.20, 1.20, 1.20,	1.19, 1.19, 1.19, 1.19, 1.19, 1.20, 1.20, 1.19, 1.19, 1.19, 1.19, 1.19, 1.19, 1.18,	1.18])
DmdGainSk = np.array([1.08, 1.09, 1.10, 1.12, 1.13,	1.13, 1.16,	1.15, 1.15, 1.16, 1.16,	1.16, 1.16, 1.14, 1.13, 1.14, 1.14, 1.14, 1.14, 1.15, 1.15, 1.15, 1.16, 1.16, 1.16,	1.16])
DmdGainJj = np.array([1.10, 1.12, 1.13, 1.15, 1.17,	1.18, 1.20,	1.21, 1.23, 1.25, 1.26,	1.28, 1.29, 1.31, 1.32, 1.34, 1.35, 1.37, 1.39, 1.40, 1.42, 1.43, 1.45, 1.46, 1.48,	1.48])
DmdGainMa = np.array([1.36, 1.40, 1.43, 1.47, 1.51,	1.58, 1.64,	1.71, 1.78, 1.85, 1.92,	1.99, 2.06, 2.12, 2.19, 2.27, 2.34, 2.41, 2.49, 2.56, 2.63, 2.71, 2.78, 2.86, 2.93,	2.93])
DmdGainOd = np.array([1.16, 1.18, 1.20, 1.21, 1.23,	1.23*Od_med, 1.23*Od_med, 1.23*Od_med, 1.23*Od_med, 1.22*Od_med, 1.22*Od_med, 1.20*Od_med, 1.20*Od_med, 1.20*Od_med, 1.20*Od_med, 1.20*Od_med, 1.19*Od_med, 1.19*Od_med, 1.18*Od_med, 1.18*Od_med,	1.17*Od_med, 1.17*Od_med, 1.16*Od_med, 1.16*Od_med, 1.14*Od_med, 1.14*Od_med])
DmdGainLa = np.array([0.85, 0.84, 0.84,	0.84, 0.84, 0.83, 0.83, 0.83, 0.82, 0.82, 0.82,	0.82, 0.82, 0.81, 0.81, 0.81, 0.80, 0.79, 0.78, 0.78, 0.78, 0.78, 0.77, 0.77, 0.77, 0.77])
DmdGainBy = np.array([1.09, 1.11, 1.12, 1.14, 1.16, 1.17, 1.19, 1.20, 1.22, 1.24, 1.25,	1.27, 1.29, 1.30, 1.32,	1.34, 1.35, 1.37, 1.39, 1.40, 1.42, 1.44, 1.45, 1.47, 1.48, 1.48])

DmdHo = 48283 * DmdGainHo 
DmdRi= 356685 * DmdGainRi
DmdLi = 55282 * DmdGainLi
DmdVe = 306121 * DmdGainVe
DmdCh = 276731 * DmdGainCh
DmdAa = 167081 * DmdGainAa
DmdTi = 134071 * DmdGainTi
DmdAb = 217289 * DmdGainAb
DmdGe = 189641 * DmdGainGe
DmdHh = 191066 * DmdGainHh
DmdKo = 168868 * DmdGainKo
DmdSk = 226205 * DmdGainSk * 0       #Skanderborg forbrug sættes til 0, da skanderborg ikke skal være dimensionerende for produktionsanlæg i Kredsløb        
DmdJj = 246858 * DmdGainJj
DmdMa = 30500 * DmdGainMa
DmdOd = 118050 * DmdGainOd
DmdLa = 246739 * DmdGainLa
DmdBy = 179893 * DmdGainBy

df_scens = pd.DataFrame()
for scenario in scen:
    srs_dir = res_dir+"AVAMasterOutput_"+scenario+".xlsm"
    df = pd.read_excel(srs_dir, index_col=0, sheet_name = 'Overview', skiprows = 163,  nrows= 50, usecols = 'E:AE', header=None, names=['Unit']+years)
    df = df.T
#    df_heatvent = pd.read_excel(srs_dir, index_col=0, sheet_name = 'Overview', skiprows = 226,  nrows= 4, usecols = 'E:V', header=None, names=['Unit',index_df[start_y-1],index_df[start_y],index_df[start_y+1],index_df[start_y+2],index_df[start_y+3],index_df[start_y+4],index_df[start_y+5],index_df[start_y+6],index_df[start_y+7],index_df[start_y+8],index_df[start_y+9],index_df[start_y+10],index_df[start_y+11],index_df[start_y+12],index_df[start_y+13],index_df[start_y+14],index_df[start_y+15]])
#    df_heatvent = df_heatvent.T
#    df['dQCoolSvTot'] = df_heatvent['BrESv'] + df_heatvent['BESv'] + df_heatvent['GESv']
#    df = df[ ['WEAv','HeatSinkCool','GESv','BESv','BrESv','WEFk','GEFk','BEHk','BEPk','NoEHk','NoNHk','WNVP1','WNVP2','WNVP3','DEGk','SEGk','AEGk','BEGk','BEGm','AEEk'] + [ col for col in df.columns if col != 'WEAv' and col != 'HeatSinkCool' and col != 'GESv' and col != 'BESv' and col != 'BrESv' and col != 'WEFk' and col != 'GEFk' and col != 'BEHk' and col != 'BEPk' and col != 'NoEHk' and col != 'NoNHk' and col != 'WNVP1' and col != 'WNVP2' and col != 'WNVP3' and col != 'DEGk' and col != 'SEGk' and col != 'AEGk' and col != 'BEGk' and col != 'BEGm' and col != 'AEEk'  ] ]
    df['Ov'] = 60988-7320
    if group_geo == 1 and group_fgo == 1 and group_ek == 1:
        df['Geo'] = df['VeGeo1'] + df['VeGeo2'] + df['AaGeo1'] + df['AbGeo1'] + df['ChGeo1'] + df['ByGeo1'] + df['JjGeo1'] + df['HhGeo1'] + df['GeGeo1']
        df['Fgo'] = df['GeEFgo'] + df['AaEFgo'] + df['JjEFgo'] + df['ByEFgo'] + df['VeEFgo'] + df['HoEFgo'] + df['OdEFgo'] + df['MaEFgo']
        df['Ek'] = df['StEk1'] + df['LiEk1'] + df['MoEk1'] + df['OdEk1'] + df['HoEk1'] 
        df = df[ ['LiEAv','SkEAv','Ov','Geo','StESSV3','LiEBKVV','StBKVV','LiFk1','LiFk2','StFk1','RiVp1','AaVp2','ChVp1','AaVp1','StVp1','StVp2','OdVp1','HoVp1','LiVp1','Ek','Fgo'] ]# + [ col for col in df.columns if col != 'WEAv' and col != 'HeatSinkCool' and col != 'GESv' and col != 'BESv' and col != 'BrESv' and col != 'WEFk' and col != 'GEFk' and col != 'BEHk' and col != 'BEPk' and col != 'NoEHk' and col != 'NoNHk' and col != 'WNVP1' and col != 'WNVP2' and col != 'WNVP3' and col != 'DEGk' and col != 'SEGk' and col != 'AEGk' and col != 'BEGk' and col != 'BEGm' and col != 'AEEk'  ] ]
    else:
        df = df[ ['LiEAv','SkEAv','Ov','VeGeo1', 'AaGeo1', 'AbGeo1','VeGeo2', 'ChGeo1', 'ByGeo1','JjGeo1','HhGeo1','GeGeo1','StESSV3','LiEBKVV','StBKVV','LiFk1','LiFk2','StFk1','RiVp1','AaVp2','ChVp1','AaVp1','StVp1','StVp2','OdVp1','HoVp1','LiVp1','StEk1','LiEk1','MoEk1','OdEk1','GeEFgo','AaEFgo','JjEFgo','ByEFgo','VeEFgo','HoEFgo','OdEFgo'] ]# + [ col for col in df.columns if col != 'WEAv' and col != 'HeatSinkCool' and col != 'GESv' and col != 'BESv' and col != 'BrESv' and col != 'WEFk' and col != 'GEFk' and col != 'BEHk' and col != 'BEPk' and col != 'NoEHk' and col != 'NoNHk' and col != 'WNVP1' and col != 'WNVP2' and col != 'WNVP3' and col != 'DEGk' and col != 'SEGk' and col != 'AEGk' and col != 'BEGk' and col != 'BEGm' and col != 'AEEk'  ] ]
    df_temp = df/1000
    df_temp = df_temp.loc[:, (df_temp > 0.01).any(axis=0)]
    df = df.loc[index_df[start_y-1]:index_df[start_y-1+years_plot-1]]
    if scenario == '14107010000':
        DmdGainMa = np.array([1.36, 1.40, 1.43, 1.47, 1.51,	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        DmdGainHo = np.array([1.12, 1.12, 1.12 ,1.12 ,1.12,	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    else:
        DmdGainMa = np.array([1.36, 1.40, 1.43, 1.47, 1.51,	1.58, 1.64,	1.71, 1.78, 1.85, 1.92,	1.99, 2.06, 2.12, 2.19, 2.27, 2.34, 2.41, 2.49, 2.56, 2.63, 2.71, 2.78, 2.86, 2.93,	2.93])
        DmdGainHo = np.array([1.12, 1.12, 1.12 ,1.12 ,1.12 ,1.12 ,1.15 ,1.13, 1.14, 1.14, 1.14, 1.14, 1.15, 1.13, 1.12, 1.12, 1.12, 1.13, 1.13, 1.13, 1.14, 1.14, 1.14, 1.15, 1.15, 1.15])
    DmdHo = 48283 * DmdGainHo
    DmdMa = 30500 * DmdGainMa
    DmdTotal = DmdHo + DmdRi + DmdLi + DmdVe + DmdCh + DmdAa + DmdTi + DmdAb + DmdGe + DmdHh + DmdKo + DmdSk + DmdJj + DmdMa + DmdOd + DmdLa + DmdBy
    df['Leveret varme'] = DmdTotal[start_y-8:start_y-8+years_plot]/1000
    df_temp = df_temp.loc[index_df[start_y-1]:index_df[start_y-1+years_plot-1]]
    
    color_df = []
    for col in df_temp:
        color_df.append(color_map[col]) 
    df_temp = df_temp.rename(columns = {'LiEAv':'Lisbjerg (affald KVV)'})
    df_temp = df_temp.rename(columns = {'SkEAv':'Skanderborg (affald KVV)'})
    df_temp = df_temp.rename(columns = {'Ov':'Overskudsvarme'})    
    df_temp = df_temp.rename(columns = {'Geo':'Geotermi'})
    df_temp = df_temp.rename(columns = {'VeGeo1':'Skejby (geotermi)'})
    df_temp = df_temp.rename(columns = {'VeGeo2':'Nehrus (geotermi)'})
    df_temp = df_temp.rename(columns = {'AaGeo1':'Aarhus (geotermi)'})
    df_temp = df_temp.rename(columns = {'AbGeo1':'Hasle (geotermi)'})
    df_temp = df_temp.rename(columns = {'ChGeo1':'Brokvarter (geotermi)'})
    df_temp = df_temp.rename(columns = {'ByGeo1':'Bygholm (geotermi)'})
    df_temp = df_temp.rename(columns = {'JjGeo1':'Jens J. (geotermi)'})
    df_temp = df_temp.rename(columns = {'HhGeo1':'Kridthøj (geotermi)'})
    df_temp = df_temp.rename(columns = {'GeGeo1':'Brabrand (geotermi)'})
    df_temp = df_temp.rename(columns = {'LiEBKVV':'Lisbjerg (bio KVV)'})
    df_temp = df_temp.rename(columns = {'StBKVV':'Studstrup (ny bio KVV)'})
    df_temp = df_temp.rename(columns = {'StESSV3':'Studstrup (bio KVV)'})
    df_temp = df_temp.rename(columns = {'StFk1':'Studstrup (ny fliskedel)'})
    df_temp = df_temp.rename(columns = {'LiFk1':'Lisbjerg (ny HPA-kedel)'})
    df_temp = df_temp.rename(columns = {'LiFk2':'Lisbjerg (ny fliskedel)'})
    df_temp = df_temp.rename(columns = {'RiVp1':'Egå (ny spilde-VP)'})
    df_temp = df_temp.rename(columns = {'AaVp2':'Aarhus (ny spilde-VP)'})
    df_temp = df_temp.rename(columns = {'ChVp1':'Maskinhuset (ny hav-VP)'})
    df_temp = df_temp.rename(columns = {'AaVp1':'Aarhus (ny hav-VP)'})
    df_temp = df_temp.rename(columns = {'StVp1':'Studstrup (ny hav-VP1)'})
    df_temp = df_temp.rename(columns = {'StVp2':'Studstrup (ny hav-VP2)'})
    df_temp = df_temp.rename(columns = {'LiVp1':'Lisbjerg (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'OdVp1':'Odder (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'HoVp1':'Hornslet (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'Ek':'Elkedler'})
    df_temp = df_temp.rename(columns = {'StEk1':'Studstrup (elkedel)'})
    df_temp = df_temp.rename(columns = {'LiEk1':'Lisbjerg (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'MoEk1':'Motorvej (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'OdEk1':'Odder (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'HoEk1':'Hornslet (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'Fgo':'Oliekedler'})
    df_temp = df_temp.rename(columns = {'JjEFgo':'Jens Juuls Vej (oliekedel)'})
    df_temp = df_temp.rename(columns = {'AaEFgo':'Aarhusværket (oliekedel)'})
    df_temp = df_temp.rename(columns = {'GeEFgo':'Gellerup (oliekedel)'})
    df_temp = df_temp.rename(columns = {'OdEFgo':'Odder (oliekedel)'})
    df_temp = df_temp.rename(columns = {'HoEFgo':'Hornslet (oliekedel)'})
    df_temp = df_temp.rename(columns = {'ByEFgo':'Bygholm (oliekedel)'})
    df_temp = df_temp.rename(columns = {'VeEFgo':'Tværmarksvej (oliekedel)'})
    df_temp = df_temp.rename(columns = {'MaEFgo':'Malling (oliekedel)'})
    
    ax = df_temp.plot(kind="bar",stacked=True,color=color_df,figsize=(12,7),width=0.75) #figsize=(5.4,5.0)
    df['Leveret varme'].plot(color="black",style='--',linewidth=1)
    ax_value_labels(ax,df_temp,20,0)
    ax.set_ylabel('Produceret varme (GWhq/år)',fontsize=12)
    #ax.legend(loc='center',bbox_to_anchor=(1.18,0.5))
    handles, labels = ax.get_legend_handles_labels()
    ax.legend(reversed(handles), reversed(labels),loc='center',bbox_to_anchor=(1.13,0.5))
    ax.set_ylim([0, 3600])
    ax.set_title([scen[scenario]])
    fig_name = 'Varmeprod_total_'+scenario+'.svg'
    plt.savefig(os.path.join(my_path, fig_name),facecolor="none",bbox_inches='tight')

#% kapacitetsudvikling henover planperiode
df_scens = pd.DataFrame()
for scenario in scen:
    srs_dir = res_dir+"AVAMasterOutput_"+scenario+".xlsm"
    df = pd.read_excel(srs_dir, index_col=0, sheet_name = 'Overview', skiprows = 13,  nrows= 29, usecols = 'E:AE', header=None,  names=['Unit']+years)
    df = df.T
    df = df.drop(columns=['StEk1'])
    df = df.loc[index_df[start_y-1]:index_df[start_y-1+years_plot-1]]
    df_temp = df
    df_temp = df_temp[ ['VeGeo1','AaGeo1','AbGeo1','VeGeo2','ChGeo1','ByGeo1','JjGeo1','HhGeo1','GeGeo1','LiFk1','StBKVV','LiFk2','StFk1','RiVp1','AaVp2','ChVp1','AaVp1','StVp1','StVp2','LiVp1','OdVp1','HoVp1','LiEk1','MoEk1','OdEk1','HoEk1'] ]

    df_temp = df_temp.loc[:, (df_temp > 0.1).any(axis=0)]

    if not df_temp.empty:
        color_df = []
        for col in df_temp:
            color_df.append(color_map[col]) 
    df_temp = df_temp.rename(columns = {'LiEAv':'Lisbjerg (affald KVV)'})
    df_temp = df_temp.rename(columns = {'SkEAv':'Skanderborg (affald KVV)'})
    df_temp = df_temp.rename(columns = {'Ov':'Overskudsvarme'})
    df_temp = df_temp.rename(columns = {'VeGeo1':'Skejby (geotermi)'})
    df_temp = df_temp.rename(columns = {'VeGeo2':'Nehrus (geotermi)'})
    df_temp = df_temp.rename(columns = {'AaGeo1':'Aarhus (geotermi)'})
    df_temp = df_temp.rename(columns = {'AbGeo1':'Hasle (geotermi)'})
    df_temp = df_temp.rename(columns = {'ChGeo1':'Brokvarter (geotermi)'})
    df_temp = df_temp.rename(columns = {'ByGeo1':'Bygholm (geotermi)'})
    df_temp = df_temp.rename(columns = {'JjGeo1':'Jens J. (geotermi)'})
    df_temp = df_temp.rename(columns = {'HhGeo1':'Kridthøj (geotermi)'})
    df_temp = df_temp.rename(columns = {'GeGeo1':'Brabrand (geotermi)'})
    df_temp = df_temp.rename(columns = {'LiEBKVV':'Lisbjerg (bio KVV)'})
    df_temp = df_temp.rename(columns = {'StBKVV':'Studstrup (ny bio KVV)'})
    df_temp = df_temp.rename(columns = {'StESSV3':'Studstrup (bio KVV)'})
    df_temp = df_temp.rename(columns = {'StFk1':'Studstrup (ny fliskedel)'})
    df_temp = df_temp.rename(columns = {'LiFk1':'Lisbjerg (ny HPA-kedel)'})
    df_temp = df_temp.rename(columns = {'LiFk2':'Lisbjerg (ny fliskedel)'})
    df_temp = df_temp.rename(columns = {'RiVp1':'Egå (ny spilde-VP)'})
    df_temp = df_temp.rename(columns = {'AaVp2':'Aarhus (ny spilde-VP)'})
    df_temp = df_temp.rename(columns = {'ChVp1':'Maskinhuset (ny hav-VP)'})
    df_temp = df_temp.rename(columns = {'AaVp1':'Aarhus (ny hav-VP)'})
    df_temp = df_temp.rename(columns = {'StVp1':'Studstrup (ny hav-VP1)'})
    df_temp = df_temp.rename(columns = {'StVp2':'Studstrup (ny hav-VP2)'})
    df_temp = df_temp.rename(columns = {'LiVp1':'Lisbjerg (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'OdVp1':'Odder (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'HoVp1':'Hornslet (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'StEk1':'Studstrup (elkedel)'})
    df_temp = df_temp.rename(columns = {'LiEk1':'Lisbjerg (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'MoEk1':'Motorvej (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'OdEk1':'Odder (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'HoEk1':'Hornslet (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'JjEFgo':'Jens Juuls Vej (oliekedel)'})
    df_temp = df_temp.rename(columns = {'AaEFgo':'Aarhusværket (oliekedel)'})
    df_temp = df_temp.rename(columns = {'GeEFgo':'Gellerup (oliekedel)'})
    df_temp = df_temp.rename(columns = {'OdEFgo':'Odder (oliekedel)'})
    df_temp = df_temp.rename(columns = {'HoEFgo':'Hornslet (oliekedel)'})
    df_temp = df_temp.rename(columns = {'ByEFgo':'Bygholm (oliekedel)'})
    df_temp = df_temp.rename(columns = {'VeEFgo':'Tværmarksvej (oliekedel)'})
    df_temp = df_temp.rename(columns = {'MaEFgo':'Malling (oliekedel)'})
    
    ax = df_temp.plot(kind="bar",stacked=True,color=color_df,figsize=(11,12.0),width=0.75) #figsize=(5.4,5.0)
    ax_value_labels(ax,df_temp,0.1,0)
    ax.set_ylabel('Nye kapaciteter (MWq)',fontsize=12)
   # ax.legend(loc='center',bbox_to_anchor=(1.12,0.5))
    ax.set_xlabel('Årstal',fontsize=12)
    ax.set_ylim([0, 500])
    plt.yticks([0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500])
    ax.set_title([scen[scenario]])
    handles, labels = ax.get_legend_handles_labels() #Definere handles and labels
    ax.legend(reversed(handles), reversed(labels))  #Viser labels omvendt af normalt. Så værkerne vises i samme rækkefølge som i bar plottet.
    fig_name = 'Kapacitet_'+scenario+'.svg'
    plt.savefig(os.path.join(my_path, fig_name),facecolor="none",bbox_inches='tight')

#%%Udvalgt scenarie for gdx data udtræk
scen_choice = {#'14101010000': "Scen 1.1.0.0, ingen bio",
        #'14101020000': "Scen 1.2.0.0, bio u/KV",
        '14101020100': "Scen 1.2.1.0, bio u/KV",
        #'14101050000': "Scen 1.5.0.0, bio ok",
        #'14102010000': "Scen 2.1.0.0, ingen bio, FW elpris",
        #'14102020000': "Scen 2.2.0.0, bio u/KV, FW elpris",
       # '14102050000': "Scen 2.5.0.0, bio ok, FW elpris",
       # '14103010000': "Scen 3.1.0.0, TN25 lav",
       # '14104010000': "Scen 4.1.0.0, stor VAK",
       # '14104020000': "Scen 4.2.0.0, lille sæson",
       # '14104030000': "Scen 4.3.0.0, mellem sæson",
       # '14105010000': "Scen 5.1.0.0, nul geo",
       # '14106010000': "Scen 6.1.0.0, nul CC",
       # '14106020000': "Scen 6.2.0.0, CC affald",
       # '14107010000': "Scen 7.1.0.0, red. VPA",
        #'14108010000': "Scen 8.1.0.0, Eksl. ST site", 
        #'14108010100': "Scen 8.1.1.0, Eksl. ST site", 
        #'14108010200': "Scen 8.1.2.0, Eksl. ST site, 100 MW luft-VP", 
        # '14108030000': "Scen 8.3.0.0, SSV3 2035", 
} # Scenarios to run

per_plot = 'per8'
per_chosen = 8
per_choice = 8 #for udtræk af hvilke units der er i spil (on)... per choice skal matche periodenummer brugt ifm driftoptimering (ikke samme som per plot)


for scen_plot in scen_choice:
    pathGdx = res_dir+"d_opt/AVA_"+scen_plot+"_iter2_"+per_plot+".gdx"
    
    #Generate index
    if per_plot == 'per23':
        index_timestamps = pd.date_range(start='1/1/2040 00:00',end='31/12/2040 23:00', freq='H')
    if per_plot == 'per18':
        index_timestamps = pd.date_range(start='1/1/2035 00:00',end='31/12/2035 23:00', freq='H')
    elif per_plot == 'per14':
        index_timestamps = pd.date_range(start='1/1/2031 00:00',end='31/12/2031 23:00', freq='H')
    elif per_plot == 'per13':
        index_timestamps = pd.date_range(start='1/1/2030 00:00',end='31/12/2030 23:00', freq='H')
    elif per_plot == 'per12':
        index_timestamps = pd.date_range(start='1/1/2029 00:00',end='31/12/2029 23:00', freq='H')
    elif per_plot == 'per11':
        index_timestamps = pd.date_range(start='1/1/2028 00:00',end='31/12/2028 23:00', freq='H')
    elif per_plot == 'per10':
        index_timestamps = pd.date_range(start='1/1/2027 00:00',end='31/12/2027 23:00', freq='H')
    elif per_plot == 'per9':
        index_timestamps = pd.date_range(start='1/1/2026 00:00',end='31/12/2026 23:00', freq='H')
    elif per_plot == 'per8':
        index_timestamps = pd.date_range(start='1/1/2025 00:00',end='31/12/2025 23:00', freq='H')
    elif per_plot == 'per7':
        index_timestamps = pd.date_range(start='1/1/2024 00:00',end='31/12/2024 23:00', freq='H')
    elif per_plot == 'per6':
        index_timestamps = pd.date_range(start='1/1/2023 00:00',end='31/12/2023 23:00', freq='H')
    elif per_plot == 'per5':
        index_timestamps = pd.date_range(start='1/1/2022 00:00',end='31/12/2022 23:00', freq='H')
    elif per_plot == 'per4':
        index_timestamps = pd.date_range(start='1/1/2021 00:00',end='31/12/2021 23:00', freq='H')
    elif per_plot == 'per3':
        index_timestamps = pd.date_range(start='1/1/2020 00:00',end='31/12/2020 23:00', freq='H')
    elif per_plot == 'per2':
        index_timestamps = pd.date_range(start='1/1/2019 00:00',end='31/12/2019 23:00', freq='H')
    else:
        index_timestamps = pd.date_range(start='1/1/2018 00:00',end='31/12/2018 23:00', freq='H')
    leap = []
    for each in index_timestamps:
        if each.month==2 and each.day ==29:
            leap.append(each)
    index_timestamps = index_timestamps.drop(leap)
    
    #Initiate class with pathGdx
    w = gw.GdxWrapper('Main', pathGdx)
    
    #Import all set members of u
    U = w.getSetMembers('u')
    CHP = w.getSetMembers('chp')
    tSet = w.getSetMembers('t')
    FORBR = w.getSetMembers('Forbr')
    VAK = w.getSetMembers('vak')
    PTES = w.getSetMembers('ptes')
    PRODUEXTR = w.getSetMembers('ProduExtR')
    FIX = w.getSetMembers('fix')
    FIXF = w.getSetMembers('fixf')
    TAX = w.getSetMembers('tax')
    
    df_on = pd.DataFrame(index = U, columns = ['UnitOn'])
    df_on['UnitOn'] = w.getValues('OnUNomGlobal','u',{}) * w.getValues('OnUNomPer','u',{'perA':'per'+str(per_choice)})
    
    
    #% Indlæsning af driftsoptimeringsdata
    
    # DataFrame to hold all production data, consumption and elspot series
    Production_df = pd.DataFrame(index = index_timestamps, columns = ['Elspot']+['NGasPris']+['dQExt.'+ProduExtR for ProduExtR in PRODUEXTR]+['dQDmd.'+forbr for forbr in FORBR]+['dQU.'+u for u in U] + ['Pnet.'+chp for chp in CHP] + ['Pbrut.'+chp for chp in CHP] + ['PowInU.'+u for u in U])
    
    PrisMWh = w.getValues('Brandsel','f',{'ParFuel':'PrisMWh'})
    Production_df['NGasPris'] = w.getValues('GasPriceActual_tt','tt',{})
    Production_df['Elspot'] = w.getValues('ElspotActual_tt','tt',{})
    
    
    for forbr in FORBR:
        Production_df['dQDmd.'+forbr] = w.getValues('QDemandActual_tt','tt',{'forbr':forbr})

 #   for forbr in FORBR:
 #       if forbr == 'Nordb':
 #           Production_df['Qdanfoss'] = w.getValues('Qdanfoss','tt',{'forbr':forbr})
    
    for ProduExtR in PRODUEXTR:
        Production_df['dQExt.'+ProduExtR] = w.getValues('dQExt_tt','tt',{'ProduExtR':ProduExtR})
    if per_chosen > 3:
        Production_df['dQExt.LiOv'] = 0
    
    for u in U:
        if df_on['UnitOn'][u] == 1:
            Production_df['dQU.'+u] = w.getValues('dQU','tt',{'u':u})
            Production_df['dQU.'+u] = Production_df['dQU.'+u].clip(lower=0) #oplevede en værdi der var ca. -1e-8 (duer ikke med stacked plot)
        else:
            Production_df['dQU.'+u] = 0

    for fixf in FIXF:
        Production_df['bHfremNu.'+fixf] = w.getValues('bHfremNu','tt',{'fixf':fixf})
    Production_df['Tfrem_nulpunkt'] = Production_df['bHfremNu.tf1'] * 80 + Production_df['bHfremNu.tf2'] * 85 + Production_df['bHfremNu.tf3'] * 90 + Production_df['bHfremNu.tf4'] * 95 + Production_df['bHfremNu.tf5'] * 100 + Production_df['bHfremNu.tf6'] * 105 + Production_df['bHfremNu.tf7'] * 110 + Production_df['bHfremNu.tf8'] * 115 + Production_df['bHfremNu.tf9'] * 120 + Production_df['bHfremNu.tf10'] * 125 

    for forbr in FORBR:
        Production_df['dQExtDrain.'+forbr] = w.getValues('dQExtDrain','tt',{'forbr':forbr})
    
#    for chp in CHP:
#        Production_df['Pnet.'+chp] = w.getValues('Pnet','tt',{'cp':chp})
#        
#    for chp in CHP:
#        Production_df['Pbrut.'+chp] = w.getValues('Pbrut','tt',{'cp':chp})
#        
#    for u in U:
#        if df_on['UnitOn'][u] == 1:
#            Production_df['PowInU.'+u] = w.getValues('PowInU','tt',{'u':u})
#        else:
#            Production_df['PowInU.'+u] = 0
            
#    for u in U:
#        if df_on['UnitOn'][u] == 1:
#            Production_df['FuelQty.'+u] = w.getValues('FuelQty','tt',{'u':u})
#        else:
#            Production_df['FuelQty.'+u] = 0
            
#    for u in U:
#        if df_on['UnitOn'][u] == 1:
#            Production_df['bOn.'+u] = w.getValues('bOn','tt',{'u':u})
#        else:
#            Production_df['bOn.'+u] = 0
        
#    for u in U:
#        if df_on['UnitOn'][u] == 1:
#            Production_df['TotalCostU.'+u] = w.getValues('TotalCostU','tt',{'u':u})
#        else:
#            Production_df['TotalCostU.'+u] = 0
        
#    for u in U:
#        if df_on['UnitOn'][u] == 1:
#            Production_df['TotalTaxU.'+u] = w.getValues('TotalTaxU','tt',{'u':u})
#        else:
#            Production_df['TotalTaxU.'+u] = 0
        
#    for u in U:
#        if df_on['UnitOn'][u] == 1:
#            Production_df['TaxUCo2.'+u] = w.getValues('TaxU','tt',{'tax':'co2','u':u})
#        else:
#            Production_df['TaxUCo2.'+u] = 0    
#    
#    for u in U:     
#        for tax in TAX:        
#            if df_on['UnitOn'][u] == 1:             
#                Production_df['TaxU.'+tax+u] = w.getValues('TaxU','tt', {'tax':tax,'u':u})         
#            else:             
#                Production_df['TaxU.'+tax+u] = 0
        
#    for chp in CHP:
#        if df_on['UnitOn'][chp] == 1:
#            Production_df['TotalElIncome.'+chp] = w.getValues('TotalElIncome','tt',{'cp':chp})
#        else:
#            Production_df['TotalElIncome.'+chp] = 0

    HVak = w.getValues('HVak','vak',{}) #/ LiVak, StVak, SkVak /;  
    HVakR = w.getValues('HVakR','vak',{}) #/ LiVak, StVak, SkVak /;  
    HPtes = w.getValues('HPtes','ptes',{}) #/ ptes1 /;  
    HPtesR = w.getValues('HPtesR','ptes',{}) #/ ptes1 /; 
    i = 0
    for vak in VAK:
        Production_df['QVak.'+vak] = w.getValues('MVakTop','tt',{'vak':vak}) * (HVak[i] - HVakR[i]) * 1000 / 3600
        i += 1
    i = 0
    for ptes in PTES:
        Production_df['QVak.'+ptes] = w.getValues('MPtesTop','tt',{'ptes':ptes}) * (HPtes[i] - HPtesR[i]) * 1000 / 3600
        i += 1

        
#    for transprim in TRANSPRIM:
#        Production_df['QTrans.'+transprim] = w.getValues('QTrans','tt',{'TransPrim':transprim})

#    for transprim in TRANSPRIM:
#        Production_df['QTransMax.'+transprim] = w.getValues('QTransMax','tt',{'TransPrim':transprim})        
    
    ObjSumRH = w.getValues('ObjSumRH',{},{})
    
#    for u in U:
#        if u != 'WEAv' and u != 'BEGm' and u != 'BrEGm':
#            Production_df['HeatUnitPrice.'+u] = (Production_df['TotalCostU.'+u] + Production_df['TotalTaxU.'+u]) / Production_df['dQU.'+u]
#            Production_df.loc[~np.isfinite(Production_df['HeatUnitPrice.'+u]), 'HeatUnitPrice.'+u] = 0
#        else:
#            Production_df['HeatUnitPrice.'+u] = (Production_df['TotalCostU.'+u] + Production_df['TotalTaxU.'+u] - Production_df['TotalElIncome.'+u]) / Production_df['dQU.'+u]
#            Production_df.loc[~np.isfinite(Production_df['HeatUnitPrice.'+u]), 'HeatUnitPrice.'+u] = 0
#            
    with pd.ExcelWriter(os.path.join(my_path, 'Driftsoptimering_'+index_df[per_chosen-1]+'_'+scen_plot+".xlsx"), mode='w',engine = 'openpyxl') as writer:  
        Production_df.to_excel(writer, sheet_name='driftsoptimering')

    #% Varmefordeling på årsbasis (total)
    df_temp = Production_df[['dQDmd.Li']]
    df_temp['LiEAv'] = Production_df['dQU.LiEAv']
    df_temp['SkEAv'] = Production_df['dQU.SkEAv'] 
    df_temp['Ov'] = Production_df['dQExt.LiOv'] + Production_df['dQExt.AaOv'] + Production_df['dQExt.KoOv'] - Production_df['dQExtDrain.Aa'] - Production_df['dQExtDrain.La'] 
    if group_geo == 1:
        df_temp['Geo'] = Production_df['dQU.VeGeo1'] + Production_df['dQU.VeGeo2'] + Production_df['dQU.AaGeo1'] + Production_df['dQU.AbGeo1'] + Production_df['dQU.ChGeo1'] + Production_df['dQU.ByGeo1'] + Production_df['dQU.JjGeo1'] + Production_df['dQU.HhGeo1'] + Production_df['dQU.GeGeo1']
    else:
        df_temp['VeGeo1'] = Production_df['dQU.VeGeo1']
        df_temp['VeGeo2'] = Production_df['dQU.VeGeo2']
        df_temp['AaGeo1'] = Production_df['dQU.AaGeo1']
        df_temp['AbGeo1'] = Production_df['dQU.AbGeo1']
        df_temp['ChGeo1'] = Production_df['dQU.ChGeo1']
        df_temp['ByGeo1'] = Production_df['dQU.ByGeo1']
        df_temp['JjGeo1'] = Production_df['dQU.JjGeo1']
        df_temp['HhGeo1'] = Production_df['dQU.HhGeo1']
        df_temp['GeGeo1'] = Production_df['dQU.GeGeo1']
    df_temp['LiEBKVV'] = Production_df['dQU.LiEBKVV'] 
    df_temp['StBKVV'] = Production_df['dQU.StBKVV']
    df_temp['StESSV3'] = Production_df['dQU.StESSV3']
    df_temp['LiFk1'] = Production_df['dQU.LiFk1']
    df_temp['LiFk2'] = Production_df['dQU.LiFk2']
    df_temp['StFk1'] = Production_df['dQU.StFk1']
    df_temp['RiVp1'] = Production_df['dQU.RiVp1']
    df_temp['AaVp2'] = Production_df['dQU.AaVp2']
    df_temp['ChVp1'] = Production_df['dQU.ChVp1']
    df_temp['AaVp1'] = Production_df['dQU.AaVp1']
    df_temp['StVp1'] = Production_df['dQU.StVp1']
    df_temp['StVp2'] = Production_df['dQU.StVp2']
    df_temp['LiVp1'] = Production_df['dQU.LiVp1']
    df_temp['OdVp1'] = Production_df['dQU.OdVp1']
    df_temp['HoVp1'] = Production_df['dQU.HoVp1']
    if group_ek == 1:
        df_temp['Ek'] = Production_df['dQU.StEk1'] + Production_df['dQU.LiEk1'] + Production_df['dQU.MoEk1'] + Production_df['dQU.OdEk1'] + Production_df['dQU.HoEk1'] 
    else:
        df_temp['StEk1'] = Production_df['dQU.StEk1'] 
        df_temp['LiEk1'] = Production_df['dQU.LiEk1'] 
        df_temp['MoEk1'] = Production_df['dQU.MoEk1'] 
        df_temp['OdEk1'] = Production_df['dQU.OdEk1'] 
        df_temp['HoEk1'] = Production_df['dQU.HoEk1'] 
    if group_fgo == 1:
        df_temp['Fgo'] = Production_df['dQU.JjEFgo'] + Production_df['dQU.AaEFgo'] + Production_df['dQU.GeEFgo'] + Production_df['dQU.OdEFgo'] + Production_df['dQU.HoEFgo'] + Production_df['dQU.ByEFgo'] + Production_df['dQU.VeEFgo'] + Production_df['dQU.MaEFgo'] 
    else:
        df_temp['JjEFgo'] = Production_df['dQU.JjEFgo'] 
        df_temp['AaEFgo'] = Production_df['dQU.AaEFgo'] 
        df_temp['GeEFgo'] = Production_df['dQU.GeEFgo'] 
        df_temp['OdEFgo'] = Production_df['dQU.OdEFgo'] 
        df_temp['HoEFgo'] = Production_df['dQU.HoEFgo'] 
        df_temp['ByEFgo'] = Production_df['dQU.ByEFgo'] 
        df_temp['VeEFgo'] = Production_df['dQU.VeEFgo'] 
        df_temp['MaEFgo'] = Production_df['dQU.MaEFgo'] 
    df_temp = df_temp.drop(columns=['dQDmd.Li'])
    df_temp = df_temp.loc[:, (df_temp > 0.25).any(axis=0)]
    
    df_pie = pd.DataFrame()
    if 'LiEAv' in df_temp:
        df_pie['Lisbjerg (affald KVV)'] = [df_temp.loc[:,'LiEAv'].sum()]
    if 'SkEAv' in df_temp:
        df_pie['Skanderborg (affald KVV)'] = [df_temp.loc[:,'SkEAv'].sum()]
    if 'Ov' in df_temp:
        df_pie['Overskudsvarme'] = [df_temp.loc[:,'Ov'].sum()]
    if 'Geo' in df_temp:
        df_pie['Geotermi'] = [df_temp.loc[:,'Geo'].sum()]
    if 'VeGeo1' in df_temp:
        df_pie['Skejby (geotermi)'] = [df_temp.loc[:,'VeGeo1'].sum()]
    if 'VeGeo2' in df_temp:
        df_pie['Nehrus (geotermi)'] = [df_temp.loc[:,'VeGeo2'].sum()]
    if 'AaGeo1' in df_temp:
        df_pie['Aarhus (geotermi)'] = [df_temp.loc[:,'AaGeo1'].sum()]
    if 'AbGeo1' in df_temp:
        df_pie['Hasle (geotermi)'] = [df_temp.loc[:,'AbGeo1'].sum()]
    if 'ChGeo1' in df_temp:
        df_pie['Brokvarter (geotermi)'] = [df_temp.loc[:,'ChGeo1'].sum()]
    if 'ByGeo1' in df_temp:
        df_pie['Bygholm (geotermi)'] = [df_temp.loc[:,'ByGeo1'].sum()]
    if 'JjGeo1' in df_temp:
        df_pie['Jens J. (geotermi)'] = [df_temp.loc[:,'JjGeo1'].sum()]
    if 'HhGeo1' in df_temp:
        df_pie['Kridthøj (geotermi)'] = [df_temp.loc[:,'HhGeo1'].sum()]
    if 'GeGeo1' in df_temp:
        df_pie['Brabrand (geotermi)'] = [df_temp.loc[:,'GeGeo1'].sum()]
    if 'LiEBKVV' in df_temp:
        df_pie['Lisbjerg (bio KVV)'] = [df_temp.loc[:,'LiEBKVV'].sum()]
    if 'StBKVV' in df_temp:
        df_pie['Studstrup (ny bio KVV)'] = [df_temp.loc[:,'StBKVV'].sum()]
    if 'StESSV3' in df_temp:
        df_pie['Studstrup (bio KVV)'] = [df_temp.loc[:,'StESSV3'].sum()]
    if 'LiFk1' in df_temp:
        df_pie['Lisbjerg (ny HPA-kedel)'] = [df_temp.loc[:,'LiFk1'].sum()]
    if 'LiFk2' in df_temp:
        df_pie['Lisbjerg (ny fliskedel)'] = [df_temp.loc[:,'LiFk2'].sum()]
    if 'StFk1' in df_temp:
        df_pie['Studstrup (ny fliskedel)'] = [df_temp.loc[:,'StFk1'].sum()]
    if 'RiVp1' in df_temp:
        df_pie['Egå (ny spilde-VP)'] = [df_temp.loc[:,'RiVp1'].sum()]
    if 'AaVp2' in df_temp:
        df_pie['Aarhus (ny spilde-VP)'] = [df_temp.loc[:,'AaVp2'].sum()]
    if 'ChVp1' in df_temp:
        df_pie['Maskinhuset (ny hav-VP)'] = [df_temp.loc[:,'ChVp1'].sum()]
    if 'AaVp1' in df_temp:
        df_pie['Aarhus (ny hav-VP)'] = [df_temp.loc[:,'AaVp1'].sum()]
    if 'StVp1' in df_temp:
        df_pie['Studstrup (ny hav-VP1)'] = [df_temp.loc[:,'StVp1'].sum()]
    if 'StVp2' in df_temp:
        df_pie['Studstrup (ny hav-VP2)'] = [df_temp.loc[:,'StVp2'].sum()]
    if 'LiVp1' in df_temp:
        df_pie['Lisbjerg (ny luft-VP)'] = [df_temp.loc[:,'LiVp1'].sum()]
    if 'OdVp1' in df_temp:
        df_pie['Odder (ny luft-VP)'] = [df_temp.loc[:,'OdVp1'].sum()]
    if 'HoVp1' in df_temp:
        df_pie['Hornslet (ny luft-VP)'] = [df_temp.loc[:,'HoVp1'].sum()]
    if 'Ek' in df_temp:
        df_pie['Elkedler'] = [df_temp.loc[:,'Ek'].sum()]
    if 'StEk1' in df_temp:
        df_pie['Studstrup (elkedel)'] = [df_temp.loc[:,'StEk1'].sum()]
    if 'LiEk1' in df_temp:
        df_pie['Lisbjerg (ny elkedel)'] = [df_temp.loc[:,'LiEk1'].sum()]
    if 'MoEk1' in df_temp:
        df_pie['Motorvej (ny elkedel)'] = [df_temp.loc[:,'MoEk1'].sum()]
    if 'OdEk1' in df_temp:
        df_pie['Odder (ny elkedel)'] = [df_temp.loc[:,'OdEk1'].sum()]
    if 'HoEk1' in df_temp:
        df_pie['Hornslet (ny elkedel)'] = [df_temp.loc[:,'HoEk1'].sum()]
    if 'Fgo' in df_temp:
        df_pie['Oliekedler'] = [df_temp.loc[:,'Fgo'].sum()]
    if 'JjEFgo' in df_temp:
        df_pie['Jens Juuls Vej (oliekedel)'] = [df_temp.loc[:,'JjEFgo'].sum()]
    if 'AaEFgo' in df_temp:
        df_pie['Aarhusværket (oliekedel)'] = [df_temp.loc[:,'AaEFgo'].sum()]
    if 'GeEFgo' in df_temp:
        df_pie['Gellerup (oliekedel)'] = [df_temp.loc[:,'GeEFgo'].sum()] 
    if 'OdEFgo' in df_temp:
        df_pie['Odder (oliekedel)'] = [df_temp.loc[:,'OdEFgo'].sum()]
    if 'HoEFgo' in df_temp:
        df_pie['Hornslet (oliekedel)'] = [df_temp.loc[:,'HoEFgo'].sum()]  
    if 'ByEFgo' in df_temp:
        df_pie['Bygholm (oliekedel)'] = [df_temp.loc[:,'ByEFgo'].sum()]
    if 'VeEFgo' in df_temp:
        df_pie['Tværmarksvej (oliekedel)'] = [df_temp.loc[:,'VeEFgo'].sum()]           
    if 'MaEFgo' in df_temp:
        df_pie['Malling (oliekedel)'] = [df_temp.loc[:,'MaEFgo'].sum()] 
    df_pie = df_pie.T
    df_plotly = df_pie
    df_pie = df_pie.loc[:,0]
    
    explode = tuple(np.repeat(0.02,len(df_temp.columns)))    
    color_df = []
    for col in df_temp:
        color_df.append(color_map[col]) 
    
    values = np.zeros(len(df_pie))
    for i in range(len(df_pie)):
        values[i] = df_pie[i]
            
    total = sum(values)
    pct = np.round(values/total*100,1)
    for i in range(len(df_pie)):
        df_pie = df_pie.rename({df_pie.index[i]: df_plotly.index[i]+': '+str(pct[i])+'% ('+str(np.round(values[i]/1000,1))+' GWh)'})
     
    fig1, ax1 = plt.subplots()
    ax1 = df_pie.plot(kind='pie',explode=explode,pctdistance=1.2, colors=color_df, figsize=(4,4),shadow=False,startangle=0,fontsize=14,labeldistance=1.5, labels=['','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','',''])
    ax1.axis('equal')  # Equal aspect ratio ensures that pie is drawn as a circle.
    ax1.set_ylabel(' ')
    ax1.set_title(scen_plot+" - "+xtick_lab[per_chosen-1])
    plt.legend(labels=df_pie.index,loc='center',bbox_to_anchor=(1.60,0.5))
    #handles, labels = ax.get_legend_handles_labels() #Definere handles and labels
    #ax.legend(reversed(handles), reversed(labels),loc='center',bbox_to_anchor=(1.60,0.5))  #Viser labels omvendt af normalt. Så værkerne vises i samme rækkefølge som i bar plottet.

    fig_name = 'Varmeprod_pie_'+index_df[per_chosen-1]+'_'+scen_plot+'.svg'
    plt.savefig(os.path.join(my_path, fig_name),facecolor="none",bbox_inches='tight')
    
    #% Stacked varmeproduktion henover året (Kredsløb)
    pd.options.mode.chained_assignment = None  # default='warn'
    resample_time = '24H' 
    df_temp = Production_df[['dQDmd.Ho','dQDmd.Ri','dQDmd.Li','dQDmd.Ve','dQDmd.Ch','dQDmd.Aa','dQDmd.Ti','dQDmd.Ab','dQDmd.Ge','dQDmd.Hh','dQDmd.Ko','dQDmd.Sk','dQDmd.Jj','dQDmd.Od','dQDmd.La','dQDmd.By']]
    df_temp['LiEAv'] = Production_df['dQU.LiEAv']
    df_temp['SkEAv'] = Production_df['dQU.SkEAv'] 
    df_temp['Ov'] = Production_df['dQExt.LiOv']+Production_df['dQExt.AaOv'] + Production_df['dQExt.KoOv'] - Production_df['dQExtDrain.Aa'] - Production_df['dQExtDrain.La'] 
    if group_geo == 1:
        df_temp['Geo'] = Production_df['dQU.VeGeo1'] + Production_df['dQU.VeGeo2'] + Production_df['dQU.AaGeo1'] + Production_df['dQU.AbGeo1'] + Production_df['dQU.ChGeo1'] + Production_df['dQU.ByGeo1'] + Production_df['dQU.JjGeo1'] + Production_df['dQU.HhGeo1'] + Production_df['dQU.GeGeo1']
    else:
        df_temp['VeGeo1'] = Production_df['dQU.VeGeo1']
        df_temp['VeGeo2'] = Production_df['dQU.VeGeo2']
        df_temp['AaGeo1'] = Production_df['dQU.AaGeo1']
        df_temp['AbGeo1'] = Production_df['dQU.AbGeo1']
        df_temp['ChGeo1'] = Production_df['dQU.ChGeo1']
        df_temp['ByGeo1'] = Production_df['dQU.ByGeo1']
        df_temp['JjGeo1'] = Production_df['dQU.JjGeo1']
        df_temp['HhGeo1'] = Production_df['dQU.HhGeo1']
        df_temp['GeGeo1'] = Production_df['dQU.GeGeo1']
    df_temp['LiEBKVV'] = Production_df['dQU.LiEBKVV'] 
    df_temp['StBKVV'] = Production_df['dQU.StBKVV']
    df_temp['StESSV3'] = Production_df['dQU.StESSV3']
    df_temp['LiFk1'] = Production_df['dQU.LiFk1']
    df_temp['LiFk2'] = Production_df['dQU.LiFk2']
    df_temp['StFk1'] = Production_df['dQU.StFk1']
    df_temp['RiVp1'] = Production_df['dQU.RiVp1']
    df_temp['AaVp2'] = Production_df['dQU.AaVp2']
    df_temp['ChVp1'] = Production_df['dQU.ChVp1']
    df_temp['AaVp1'] = Production_df['dQU.AaVp1']
    df_temp['StVp1'] = Production_df['dQU.StVp1']
    df_temp['StVp2'] = Production_df['dQU.StVp2']
    df_temp['LiVp1'] = Production_df['dQU.LiVp1']
    df_temp['OdVp1'] = Production_df['dQU.OdVp1']
    df_temp['HoVp1'] = Production_df['dQU.HoVp1']
    if group_ek == 1:
        df_temp['Ek'] = Production_df['dQU.StEk1'] + Production_df['dQU.LiEk1'] + Production_df['dQU.MoEk1'] + Production_df['dQU.OdEk1'] + Production_df['dQU.HoEk1'] 
    else:
        df_temp['StEk1'] = Production_df['dQU.StEk1'] 
        df_temp['LiEk1'] = Production_df['dQU.LiEk1'] 
        df_temp['MoEk1'] = Production_df['dQU.MoEk1'] 
        df_temp['OdEk1'] = Production_df['dQU.OdEk1'] 
        df_temp['HoEk1'] = Production_df['dQU.HoEk1'] 
    if group_fgo == 1:
        df_temp['Fgo'] = Production_df['dQU.JjEFgo'] + Production_df['dQU.AaEFgo'] + Production_df['dQU.GeEFgo'] + Production_df['dQU.OdEFgo'] + Production_df['dQU.HoEFgo'] + Production_df['dQU.ByEFgo'] + Production_df['dQU.VeEFgo'] + Production_df['dQU.MaEFgo']
    else:
        df_temp['JjEFgo'] = Production_df['dQU.JjEFgo'] 
        df_temp['AaEFgo'] = Production_df['dQU.AaEFgo'] 
        df_temp['GeEFgo'] = Production_df['dQU.GeEFgo'] 
        df_temp['OdEFgo'] = Production_df['dQU.OdEFgo'] 
        df_temp['HoEFgo'] = Production_df['dQU.HoEFgo'] 
        df_temp['ByEFgo'] = Production_df['dQU.ByEFgo'] 
        df_temp['VeEFgo'] = Production_df['dQU.VeEFgo'] 
        df_temp['MaEFgo'] = Production_df['dQU.MaEFgo'] 
    df_temp['QVAK'] = Production_df['QVak.LiVak'] + Production_df['QVak.StVak'] + Production_df['QVak.SkVak'] + Production_df['QVak.ptes1']
    if len(leap) > 1:
        df_temp.index = df_temp.index - pd.DateOffset(years=1)
    df_temp = df_temp.resample(resample_time).mean()
    if len(leap) > 1:
        df_temp.index = df_temp.index + pd.DateOffset(years=1)
    df_temp2 = df_temp['dQDmd.Ho']
    df_temp2['Leveret FJV an dist.'] = df_temp['dQDmd.Ho'] + df_temp['dQDmd.Ri'] + df_temp['dQDmd.Li'] + df_temp['dQDmd.Ve'] + df_temp['dQDmd.Ch'] + df_temp['dQDmd.Aa'] + df_temp['dQDmd.Ti'] + df_temp['dQDmd.Ab'] + df_temp['dQDmd.Ge'] + df_temp['dQDmd.Hh'] + df_temp['dQDmd.Ko'] + df_temp['dQDmd.Sk'] + df_temp['dQDmd.Jj'] + df_temp['dQDmd.Od'] + df_temp['dQDmd.La'] + df_temp['dQDmd.By'] 
    df_temp2['Lagret FJV'] = df_temp['QVAK'] 
    df_temp = df_temp.drop(columns=['dQDmd.Ho','dQDmd.Ri','dQDmd.Li','dQDmd.Ve','dQDmd.Ch','dQDmd.Aa','dQDmd.Ti','dQDmd.Ab','dQDmd.Ge','dQDmd.Hh','dQDmd.Ko','dQDmd.Sk','dQDmd.Jj','dQDmd.Od','dQDmd.La','dQDmd.By','QVAK'])
    df_temp = df_temp.loc[:, (df_temp > 0.25).any(axis=0)]
    color_df = []
    for col in df_temp:
        color_df.append(color_map[col])
    df_temp = df_temp.rename(columns = {'LiEAv':'Lisbjerg (affald KVV)'})
    df_temp = df_temp.rename(columns = {'SkEAv':'Skanderborg (affald KVV)'})
    df_temp = df_temp.rename(columns = {'LiEBKVV':'Lisbjerg (bio KVV)'})
    df_temp = df_temp.rename(columns = {'StBKVV':'Studstrup (ny bio KVV)'})
    df_temp = df_temp.rename(columns = {'Ov':'Overskudsvarme'})
    df_temp = df_temp.rename(columns = {'Geo':'Geotermi'})
    df_temp = df_temp.rename(columns = {'VeGeo1':'Skejby (geotermi)'})
    df_temp = df_temp.rename(columns = {'VeGeo2':'Nehrus (geotermi)'})
    df_temp = df_temp.rename(columns = {'AaGeo1':'Aarhus (geotermi)'})
    df_temp = df_temp.rename(columns = {'AbGeo1':'Hasle (geotermi)'})
    df_temp = df_temp.rename(columns = {'ChGeo1':'Brokvarter (geotermi)'})
    df_temp = df_temp.rename(columns = {'ByGeo1':'Bygholm (geotermi)'})
    df_temp = df_temp.rename(columns = {'JjGeo1':'Jens J. (geotermi)'})
    df_temp = df_temp.rename(columns = {'HhGeo1':'Kridthøj (geotermi)'})
    df_temp = df_temp.rename(columns = {'GeGeo1':'Brabrand (geotermi)'})
    df_temp = df_temp.rename(columns = {'StESSV3':'Studstrup (bio KVV)'})
    df_temp = df_temp.rename(columns = {'StFk1':'Studstrup (ny fliskedel)'})
    df_temp = df_temp.rename(columns = {'LiFk1':'Lisbjerg (ny HPA-kedel)'})
    df_temp = df_temp.rename(columns = {'LiFk2':'Lisbjerg (ny fliskedel)'})
    df_temp = df_temp.rename(columns = {'RiVp1':'Maskinhuset (ny spilde-VP)'})
    df_temp = df_temp.rename(columns = {'AaVp2':'Maskinhuset (ny spilde-VP)'})
    df_temp = df_temp.rename(columns = {'ChVp1':'Maskinhuset (ny hav-VP)'})
    df_temp = df_temp.rename(columns = {'AaVp1':'Aarhus (ny hav-VP)'})
    df_temp = df_temp.rename(columns = {'StVp2':'Studstrup (ny hav-VP2)'})
    df_temp = df_temp.rename(columns = {'StVp1':'Studstrup (ny hav-VP1)'})
    df_temp = df_temp.rename(columns = {'LiVp1':'Lisbjerg (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'OdVp1':'Odder (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'HoVp1':'Hornslet (ny luft-VP)'})
    df_temp = df_temp.rename(columns = {'Ek':'Elkedler'})
    df_temp = df_temp.rename(columns = {'StEk1':'Studstrup (elkedel)'})
    df_temp = df_temp.rename(columns = {'LiEk1':'Lisbjerg (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'MoEk1':'Motorvej (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'OdEk1':'Odder (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'HoEk1':'Hornslet (ny elkedel)'})
    df_temp = df_temp.rename(columns = {'Fgo':'Oliekedler'})
    df_temp = df_temp.rename(columns = {'JjEFgo':'Jens Juuls Vej (oliekedel)'})
    df_temp = df_temp.rename(columns = {'AaEFgo':'Aarhusværket (oliekedel)'})
    df_temp = df_temp.rename(columns = {'GeEFgo':'Gellerup (oliekedel)'})
    df_temp = df_temp.rename(columns = {'OdEFgo':'Odder (oliekedel)'})
    df_temp = df_temp.rename(columns = {'HoEFgo':'Hornslet (oliekedel)'})
    df_temp = df_temp.rename(columns = {'ByEFgo':'Bygholm (oliekedel)'})
    df_temp = df_temp.rename(columns = {'VeEFgo':'Tværmarksvej (oliekedel)'})
    df_temp = df_temp.rename(columns = {'MaEFgo':'Malling (oliekedel)'})
    ax = df_temp.plot(kind='area',color=color_df,figsize=(10.5, 4),linewidth=0)#
    ax.set_ylabel('Produceret og leveret FJV (MWq)')
    #ax.set_xlabel('Tid')
    if resample_time == '1H':
        ax.set_ylim([0, 1000]) 
        ax.set_yticks(np.arange(0, 1001, 100))
    else:
        ax.set_ylim([0, 900]) 
        ax.set_yticks(np.arange(0, 901, 100))        
    ax.set_title(str([scen_choice[scen_plot]])+' - 24 timers midling')
    df_temp2['Leveret FJV an dist.'].plot(color='k',style='--',linewidth=1,label='_')
    df_temp2['Lagret FJV'].plot(secondary_y=True, color='y',style='--',linewidth=1)
    ax.right_ax.set_ylabel('Lagret FJV (MWhq)')
    ax.right_ax.set_ylim([0,df_temp2['Lagret FJV'].max()])
    df_temp2['Leveret FJV an dist.'] = -df_temp2['Leveret FJV an dist.']
    df_temp2['Leveret FJV an dist.'].plot(secondary_y=True, color='k',style='--',linewidth=1)
    ax.right_ax.legend(['lagret FJV','Leveret FJV an dist.'],loc='upper center')
    fig_name = 'Varmeprod_timebasis_stacked_24H_'+index_df[per_chosen-1]+'_'+scen_plot+'.svg'   
    if per_plot == 'per7':    
        ax.right_ax.set_xlim('2024-01-01 00:00:00','2025-01-01 00:00:00')
    if resample_time == '1H':  
        ax.right_ax.set_xlim('2018-02-24 00:00:00','2018-03-10 00:00:00')
        ax.set_title(str([scen_choice[scen_plot]]))
        ax.right_ax.legend(['lagret FJV','Leveret FJV an dist.'],loc='upper right')
        fig_name = 'Varmeprod_timebasis_stacked_1H_'+index_df[per_chosen-1]+'_'+scen_plot+'.svg'    
   # ax.legend(loc='center',bbox_to_anchor=(1.23,0.5))      
    handles, labels = ax.get_legend_handles_labels() #Definere handles and labels
    ax.legend(reversed(handles), reversed(labels),loc='center',bbox_to_anchor=(1.23,0.5))  #Viser labels omvendt af normalt. Så værkerne vises i samme rækkefølge som i bar plottet.

    plt.savefig(os.path.join(my_path, fig_name),facecolor="none",bbox_inches='tight')
    
#%% Flow og temperatur 

#Udvalgt scenarie for gdx data udtræk
scen_choice = { '08900000': "AS-IS 2018",
                #'06100100': "Scen. 1.0.0, kap. opt.",
                #'06100101': "Scen. 1.1.0, etapeopdelt",   
                #'06100102': "Scen. 1.2.0, få etaper", 
                #'06100103': "Scen. 1.3.0, 120 MWq BKVV", 
                #'06100104': "Scen. 1.4.0, etapeopdelt, +2 LiVak", 
                #'06100105': "Scen. 1.5.0, kun 1 hav-VP", 
                #'06100111': "Scen. 1.1.1, etapeopdelt, 1.5x el", 
                #'06100113': "Scen. 1.3.1, 120 MWq BKVV, 1.5x el", 
                #'06100121': "Scen. 1.1.2, etapeopdelt, tfrem 95C med", 
} # Scenarios to run

per_plot = 'per8'
per_chosen = 8
per_choice = 8 #for udtræk af hvilke units der er i spil (on)... per choice skal matche periodenummer brugt ifm driftoptimering (ikke samme som per plot)


for scen_plot in scen_choice:
    pathGdx = res_dir+"d_opt/AVA_"+scen_plot+"_iter2_"+per_plot+".gdx"
    
    #Generate index
    if per_plot == 'per23':
        index_timestamps = pd.date_range(start='1/1/2040 00:00',end='31/12/2040 23:00', freq='H')
    if per_plot == 'per18':
        index_timestamps = pd.date_range(start='1/1/2035 00:00',end='31/12/2035 23:00', freq='H')
    elif per_plot == 'per14':
        index_timestamps = pd.date_range(start='1/1/2031 00:00',end='31/12/2031 23:00', freq='H')
    elif per_plot == 'per13':
        index_timestamps = pd.date_range(start='1/1/2030 00:00',end='31/12/2030 23:00', freq='H')
    elif per_plot == 'per12':
        index_timestamps = pd.date_range(start='1/1/2029 00:00',end='31/12/2029 23:00', freq='H')
    elif per_plot == 'per11':
        index_timestamps = pd.date_range(start='1/1/2028 00:00',end='31/12/2028 23:00', freq='H')
    elif per_plot == 'per10':
        index_timestamps = pd.date_range(start='1/1/2027 00:00',end='31/12/2027 23:00', freq='H')
    elif per_plot == 'per9':
        index_timestamps = pd.date_range(start='1/1/2026 00:00',end='31/12/2026 23:00', freq='H')
    elif per_plot == 'per8':
        index_timestamps = pd.date_range(start='1/1/2025 00:00',end='31/12/2025 23:00', freq='H')
    elif per_plot == 'per7':
        index_timestamps = pd.date_range(start='1/1/2024 00:00',end='31/12/2024 23:00', freq='H')
    elif per_plot == 'per6':
        index_timestamps = pd.date_range(start='1/1/2023 00:00',end='31/12/2023 23:00', freq='H')
    elif per_plot == 'per5':
        index_timestamps = pd.date_range(start='1/1/2022 00:00',end='31/12/2022 23:00', freq='H')
    elif per_plot == 'per4':
        index_timestamps = pd.date_range(start='1/1/2021 00:00',end='31/12/2021 23:00', freq='H')
    elif per_plot == 'per3':
        index_timestamps = pd.date_range(start='1/1/2020 00:00',end='31/12/2020 23:00', freq='H')
    elif per_plot == 'per2':
        index_timestamps = pd.date_range(start='1/1/2019 00:00',end='31/12/2019 23:00', freq='H')
    else:
        index_timestamps = pd.date_range(start='1/1/2018 00:00',end='31/12/2018 23:00', freq='H')
    leap = []
    for each in index_timestamps:
        if each.month==2 and each.day ==29:
            leap.append(each)
    index_timestamps = index_timestamps.drop(leap)
    
    #Initiate class with pathGdx
    w = gw.GdxWrapper('Main', pathGdx)
    
    #Import all set members of u
    U = w.getSetMembers('u')
    tSet = w.getSetMembers('t')
    FIX = w.getSetMembers('fix')
    FIXF = w.getSetMembers('fixf')
    TRANS = w.getSetMembers('Trans')
    KOB = w.getSetMembers('kob')
    FORBR = w.getSetMembers('Forbr')
    PRODUEXTR = w.getSetMembers('ProduExtR')
    PRODUEXP = w.getSetMembers('ProduExp')
    VAK = w.getSetMembers('vak')
    
    df_on = pd.DataFrame(index = U, columns = ['UnitOn'])
    df_on['UnitOn'] = w.getValues('OnUNomGlobal','u',{}) * w.getValues('OnUNomPer','u',{'perA':'per'+str(per_choice)})
    
    #% Indlæsning af driftsoptimeringsdata
    
    # DataFrame to hold all production data, consumption and elspot series
    FlowTemp_temp_df = pd.DataFrame(index = index_timestamps, columns = ['bHFremNu.'+fixf for fixf in FIXF])
    FlowTemp_df = pd.DataFrame(index = index_timestamps, columns = ['Tfrem_St'])    
    
    for fixf in FIXF:
        FlowTemp_temp_df['bHfremNu.'+fixf] = w.getValues('bHfremNu','tt',{'fixf':fixf})
 
    for fixf in FIXF:
        FlowTemp_temp_df['bHFremMp.'+fixf] = w.getValues('bHFremMp','tt',{'fixf':fixf})

    for fixf in FIXF:
        FlowTemp_temp_df['bHFremLi.'+fixf] = w.getValues('bHFremLi','tt',{'fixf':fixf})

    for fixf in FIXF:
        FlowTemp_temp_df['bHFremSt.'+fixf] = w.getValues('bHFremSt','tt',{'fixf':fixf})

    for fixf in FIXF:
        FlowTemp_temp_df['bHFremSk.'+fixf] = w.getValues('bHFremSk','tt',{'fixf':fixf})
        
    FlowTemp_df['Tfrem_St'] = FlowTemp_temp_df['bHFremSt.tf1'] * 80 + FlowTemp_temp_df['bHFremSt.tf2'] * 85 + FlowTemp_temp_df['bHFremSt.tf3'] * 90 + FlowTemp_temp_df['bHFremSt.tf4'] * 95 + FlowTemp_temp_df['bHFremSt.tf5'] * 100 + FlowTemp_temp_df['bHFremSt.tf6'] * 105 + FlowTemp_temp_df['bHFremSt.tf7'] * 110 + FlowTemp_temp_df['bHFremSt.tf8'] * 115 + FlowTemp_temp_df['bHFremSt.tf9'] * 120 + FlowTemp_temp_df['bHFremSt.tf10'] * 125
    FlowTemp_df['Tfrem_Li'] = FlowTemp_temp_df['bHFremLi.tf1'] * 80 + FlowTemp_temp_df['bHFremLi.tf2'] * 85 + FlowTemp_temp_df['bHFremLi.tf3'] * 90 + FlowTemp_temp_df['bHFremLi.tf4'] * 95 + FlowTemp_temp_df['bHFremLi.tf5'] * 100 + FlowTemp_temp_df['bHFremLi.tf6'] * 105 + FlowTemp_temp_df['bHFremLi.tf7'] * 110 + FlowTemp_temp_df['bHFremLi.tf8'] * 115 + FlowTemp_temp_df['bHFremLi.tf9'] * 120 + FlowTemp_temp_df['bHFremLi.tf10'] * 125
    FlowTemp_df['Tfrem_Sk'] = FlowTemp_temp_df['bHFremSk.tf1'] * 80 + FlowTemp_temp_df['bHFremSk.tf2'] * 85 + FlowTemp_temp_df['bHFremSk.tf3'] * 90 + FlowTemp_temp_df['bHFremSk.tf4'] * 95 + FlowTemp_temp_df['bHFremSk.tf5'] * 100 + FlowTemp_temp_df['bHFremSk.tf6'] * 105 + FlowTemp_temp_df['bHFremSk.tf7'] * 110 + FlowTemp_temp_df['bHFremSk.tf8'] * 115 + FlowTemp_temp_df['bHFremSk.tf9'] * 120 + FlowTemp_temp_df['bHFremSk.tf10'] * 125
    FlowTemp_df['Tfrem_Mp'] = FlowTemp_temp_df['bHFremMp.tf1'] * 80 + FlowTemp_temp_df['bHFremMp.tf2'] * 85 + FlowTemp_temp_df['bHFremMp.tf3'] * 90 + FlowTemp_temp_df['bHFremMp.tf4'] * 95 + FlowTemp_temp_df['bHFremMp.tf5'] * 100 + FlowTemp_temp_df['bHFremMp.tf6'] * 105 + FlowTemp_temp_df['bHFremMp.tf7'] * 110 + FlowTemp_temp_df['bHFremMp.tf8'] * 115 + FlowTemp_temp_df['bHFremMp.tf9'] * 120 + FlowTemp_temp_df['bHFremMp.tf10'] * 125
    FlowTemp_df['Tfrem_Nu'] = FlowTemp_temp_df['bHfremNu.tf1'] * 80 + FlowTemp_temp_df['bHfremNu.tf2'] * 85 + FlowTemp_temp_df['bHfremNu.tf3'] * 90 + FlowTemp_temp_df['bHfremNu.tf4'] * 95 + FlowTemp_temp_df['bHfremNu.tf5'] * 100 + FlowTemp_temp_df['bHfremNu.tf6'] * 105 + FlowTemp_temp_df['bHfremNu.tf7'] * 110 + FlowTemp_temp_df['bHfremNu.tf8'] * 115 + FlowTemp_temp_df['bHfremNu.tf9'] * 120 + FlowTemp_temp_df['bHfremNu.tf10'] * 125
    FlowTemp_df['Tretur_Li'] = w.getValues('TKob','tt',{'kob':'LiR2P'}) 
    
    FlowTemp_df['mTrans.'+'LiT2LiR'] = w.getValues('MForbrLi','tt',{})
    for Trans in TRANS:
        FlowTemp_df['mTrans.'+Trans] = w.getValues('mTrans','tt',{'Trans':Trans})

    for kob in KOB:
        FlowTemp_df['mKob.'+kob] = w.getValues('mKob','tt',{'kob':kob})
        
    for forbr in FORBR:
        FlowTemp_df['dQDmd.'+forbr] = w.getValues('QDemandActual_tt','tt',{'forbr':forbr})

    for forbr in FORBR:
        FlowTemp_df['dQTrTab.'+forbr] = w.getValues('QtranstabActual','tt',{'forbr':forbr})

    for ProduExtR in PRODUEXTR:
        FlowTemp_df['dQExt.'+ProduExtR] = w.getValues('dQExt_tt','tt',{'ProduExtR':ProduExtR})
    if per_chosen > 3:
        FlowTemp_df['dQExt.LiOv'] = 0
        
    for forbr in FORBR:
        FlowTemp_df['dQExtDrain.'+forbr] = w.getValues('dQExtDrain','tt',{'forbr':forbr})

    for ProduExp in PRODUEXP:
        FlowTemp_df['dQUDistExp.'+ProduExp] = w.getValues('dQUDistExp','tt',{'ProduExp':ProduExp})

    FlowTemp_df['QSvT2AaT'] = w.getValues('QSvT2AaT','tt',{})
    
    for u in U:
        if df_on['UnitOn'][u] == 1:
            FlowTemp_df.loc[:,'dQU.'+u] = w.getValues('dQU','tt',{'u':u})
            FlowTemp_df['dQU.'+u] = FlowTemp_df['dQU.'+u].clip(lower=0) #oplevede en værdi der var ca. -1e-8 (duer ikke med stacked plot)
        else:
            FlowTemp_df.loc[:,'dQU.'+u] = 0
            
    HVak = w.getValues('HVak','vak',{}) #/ LiVak, StVak, SkVak /;   
    HVakR = w.getValues('HVakR','vak',{})#
    i = 0
    for vak in VAK:
        FlowTemp_df.loc[:,'QVak.'+vak] = w.getValues('MVakTop','tt',{'vak':vak}) * (HVak[i] - HVakR[i]) * 1000 / 3600
        i += 1
  
    HVakR = w.getValues('HNom','tt',{'fix':'LiR'}) #w.getValues('HVakR','vak',{})#
    i = 0
    for vak in VAK:
        FlowTemp_df.loc[:,'dQVak.'+vak] = w.getValues('dMVakTop','tt',{'vak':vak}) * (HVak[i] - HVakR) 
        i += 1

    i = 0
    for vak in VAK:
        FlowTemp_df.loc[:,'dQVakLoss.'+vak] = w.getValues('dMVakLeak','tt',{'vak':vak}) * (HVak[i] - HVakR) 
        i += 1
        
    for forbr in FORBR:
        FlowTemp_df['TfMinTrans.'+forbr] = w.getValues('TFremKravTrans','tt',{'forbr':forbr})
        FlowTemp_df['TfMinDist.'+forbr] = w.getValues('TFremDist','tt',{'forbr':forbr})
        FlowTemp_df['mFlowMax.'+forbr] = w.getValues('mFlowMaxTForbr','tt',{'forbr':forbr})
    
    with pd.ExcelWriter(os.path.join(my_path, 'FlowTemp_'+index_df[per_chosen-1]+'_'+scen_plot+".xlsx"), mode='w',engine = 'openpyxl') as writer:  
        FlowTemp_df.to_excel(writer, sheet_name='FlowTemp')
