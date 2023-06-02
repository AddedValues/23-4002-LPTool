# -*- coding: utf-8 -*-
"""
Dette python script producerer grafer og tabeller af nøgletal fra optimering af GAMS-modellen MEC FF, projekt 23-1002.
Scriptet importerer modulet MEClib.py, som består af én kodefil.
Scriptet kan i samme ombæring producere output for flere scenarier.

Data indlæses fra gdx-filer:
    MECmain_Scen_<scen>.gdx                     : Hele modellen
    MEC_Results_<iter>_<period>_Scen_<scen>.gdx : Resultater fra en given master-iteration og given periode (kalenderår)
    
    <scen>    angiver et scenarie-id med kodningen: mMMsSSuUUrRRfFF, (MM, SS, ...) er tocifrede tal med foranstillet nul, og
              hvor MM er model, SS er scenarie, UU er underscenarie, RR er roadmap, FF er følsomheder.
    <iter>    er master-iteration kodet som iter<I>, hvor I >= 2 er iterationsnummeret,
    <periode> er perioden (kalenderåret) kodet som per<P>, hvor P >= 1.
    
Følgende output produceres:
    * Varmeproduktion på årsniveau, hvor hvert aktivt anlægs bidrag stakkes    (bar chart)
    * Varmeproduktion på månedsniveau for et udvalgt kalenderår                (bar chart)
    * Varmeproduktionspris på månedsniveau                                     (bar chart)
      Prisbasis vælges blandt marginalt, kapacitetsmæssigt hhv. totalt
    * Varme, el, drivmiddel, lagerstande på timebasis for udvalgt kalenderår   (Excel fil) 
    * Varmeproduktion for et udvalgt kalenderår med angivelse af årsmængder    (pie chart)
    * Varmeproduktion på døgnmiddel for udvalgt kalenderår                     (area chart)
    
Placering af filer:
    * Rodfolderen root er C:\GitHub\MEC\23-1002 MEC FF\
    * Python scripts placeres i underfolderen Python
    * Inputfiler er placeret i folderen root\INVOPT\Results
    * Outputfiler: Excel-filer placeres i root\INVOPT\Results
                   Plots placeres i root\INVOPT\Results\Plots
 
      Navne på outputfiler er kvalificeret med scenarie-id.
      
GAMS symboler, som indlæses:
    Sets:  u, upr, uexist, unew, topicMecU, lblBrandsel
    Parms: IterOptim, OnUGlobal(u), StatsMecUPerIter(u,topicMecU,mo,perA,iter), ElspotActual_tt(tt), QDemandActual_tt(tt,net) 
    Vars:  Q.L(tt,u), Pnet.L(tt,kv), PowInU.L(tt,upr), LVak.L(tt,vak), #--- FuelQty.L(tt,upr), bOn.L(tt,u)
 
"""
#%% Imports

# import sys
import os
from pathlib import Path
import logging
# import locale
import numpy as np
import pandas as pd
# from itertools import repeat
# from datetime import datetime, timedelta
# from calendar import Calendar
import matplotlib as mpl
import matplotlib.pyplot as plt
# from matplotlib import cm
import xlwings as xw
import GdxWrapper as gw
import MEClib as mec

NAME = 'MECcharts'

# Instantiate the logger 
global logger
logger = mec.init(NAME)

CONST: str = 'const'
MEAN:  str = 'mean'

mpl.pyplot.rcdefaults()


#%% Classes (to migrate to MEClib.py)

# from dataclasses import dataclass

class MecGlobals:
    """ Class to hold data that are not tied to any scenario. """
    
    def __init__(self, pathRoot: str, scens: dict[str,str], isInteractive: bool = False ):
        self.pathRoot = pathRoot  # = r'C:\GitHub\23-1002 MEC FF'
        self.pathWork = os.path.join(self.pathRoot, 'INVOPT', 'WorkDir')
        self.pathRes  = os.path.join(self.pathRoot, 'INVOPT', 'Results')
        self.pathPlot = os.path.join(self.pathRes,  'Plots')

        self.scens         = scens
        self.scenList      = list(self.scens.keys())    
        self.isInteractive = isInteractive

        # Select period range: period per7 equals calendar year 2025.
        self.allPeriods = list(range(1, 23+1))    
        self.allYears   = [str(2019 + p - self.allPeriods[0]) for p in self.allPeriods]
        self.year2per   = {self.allYears[i] : 'per'+str(self.allPeriods[i]) for i in range(len(self.allPeriods))}
        self.per2year   = {v: k  for k,v in self.year2per.items() }   

        
class MecProdData():
    """ Holds data pertaining to production data for at specific year"""
    def __init__(self, year: int, dfProd: pd.DataFrame, onU: dict[str,bool], leap):
        self.year   = year
        self.dfProd = dfProd
        self.onU    = onU
        self.leap   = leap
        
    def __str__(self):
        return f'{type(self)}: year={self.year}'


class MecResults():
    """ Class to load and hold data for a specific scenario. """
    
    @property
    def pathRoot(self):
        return self.chartGlobals.pathRoot
    @property
    def pathWork(self):
        return self.chartGlobals.pathWork
    @property
    def pathRes(self):
        return self.chartGlobals.pathRes
    @property
    def pathPlot(self):
        return self.chartGlobals.pathPlot
    @property
    def allPeriods(self):
        return self.chartGlobals.allPeriods
    @property
    def allYears(self):
        return self.chartGlobals.allYears
    @property
    def year2per(self):
        return self.chartGlobals.year2per
    @property
    def per2year(self):
        return self.chartGlobals.per2year
    @property
    def scenList(self):
        return self.chartGlobals.scenList
    @property
    def scens(self):
        return self.chartGlobals.scens

    def getGdxWrapper(self, scen: str, pathGdx: str):
        return gw.GdxWrapper(scen, pathGdx, logger)

    def __init__(self, scen: str, chartGlobals: MecGlobals):
        logger.info(f'Extracting basic data for scenario {scen}')
        self.scen    = scen
        self.chartGlobals = chartGlobals
        if not scen in self.scenList:
            raise ValueError(f'{scen=} was not found in list of scenarios.')
        
        self.gdxName = "MECmain_Scen_" + self.scen + '.gdx'
        self.pathGdx = os.path.join(self.pathRes, self.gdxName)
        self.path    = Path(self.pathGdx)
        if not self.path.exists():
            raise FileNotFoundError(self.pathGdx)
    
        gwyr = self.getGdxWrapper(self.scen, self.pathGdx)
        
        # Check validity
        # Time aggregation is not yet supported.
        self.onTimeAggr = int(gwyr.getValue('OnTimeAggr'))
        self.onDeAggr   = int(gwyr.getValue('OnDeAggr'))
        #--- if self.onTimeAggr != 0 and self.onDeAggr == 0:
        #---     logger.warn(f'Results are time aggregated hence higher resolution heat distribution plots are not supported: {self.onTimeAggr=}, {self.onDeAggr=}')
        
        # Extract all set and subset members
        self.NET = gwyr.getSetMembers('net')
        self.U   = gwyr.getSetMembers('u')
        self.UPR = gwyr.getSetMembers('upr')
        self.KV  = gwyr.getSetMembers('kv')
        self.T   = gwyr.getSetMembers('t')
        self.VAK = gwyr.getSetMembers('vak')
        self.TAX = gwyr.getSetMembers('tax')

        self.scenTitle     = mec.getScenarioTitle(self.scen) + ': ' + self.scens[self.scen]
        self.filetimestamp = mec.convertExcelTime(gwyr.getValue('TimeOfWritingMasterResults'))
        self.periodFirst   = int(gwyr.getValue('PeriodFirst'))
        self.periodLast    = int(gwyr.getValue('PeriodLast'))
        self.periods       = list(range(self.periodFirst, self.periodLast + 1))
        self.pers          = ['per'+str(p) for p in self.periods]
        self.years         = [self.per2year['per' + str(per)] for per in self.periods]
        
        self.topicsMecF = gwyr.getSetMembers('topicMecF')
        self.topicsMecU = gwyr.getSetMembers('topicMecU')
        self.onUglobal  = gwyr.getValues('OnUGlobal', 'u', {}, asDict=True)
        self.upr        = gwyr.getSetMembers('upr')
        self.uexist     = gwyr.getSetMembers('uexist')
        self.unew       = gwyr.getSetMembers('unew')
        self.availU     = [u for u, on in self.onUglobal.items() if on]
        self.availUpr   = sorted(set.intersection(set(self.availU), set(self.upr)))
        self.availExist = set.intersection(set(self.availUpr), set(self.uexist))
        self.availNew   = set.intersection(set(self.availUpr), set(self.unew))

        # CO2 emission correction for waste fuel.
        dfBrandsel = gwyr.getDataFrame('Brandsel')
        co2EmisWaste = dfBrandsel.loc['Affald', 'CO2emis']
        self.co2EmisWasteCorrectionFactor = 1 if co2EmisWaste != 70.00 else 42.50 / co2EmisWaste  # Correct emission factor is 42.50 kg/GJ.
        
        # Create relations btw. plants and fuels.
        self.fuels       = gwyr.getSetMembers('f')
        self.activeFuels = gwyr.getSetMembers('fActive')
        self.fuelMix     = gwyr.getDataFrame('FuelMix')  # index=upr, columns=f
        self.dfFuel      = gwyr.getDataFrame('Brandsel') # index=f,   columns=lblBrandsel
        self.LhvMWh      = self.dfFuel['LhvMWh']
        self.fuelUnits = {'BioOlie': 'L', 'FGO':'L', 'Ngas':'m3', 
                          'Flis':'kg', 'Pellet':'kg', 'Halm':'kg', 'Affald':'kg', 'HPA':'kg', 
                          'Elec':'MWhe', 'Varme':'MWhq', 'Sol':'MWhq', 'Gratis':'MWhq', 'FoxOV':'MWhq', 'Stenkul':'kg',
                          'OV-Arla':'MWhq', 'OV-Arla2':'MWhq', 'OV-Birn':'MWhq', 'OV-Ptx':'MWhq'}
        self.fuelBio       = ['Flis', 'Pellet', 'Halm', 'HPA']
        self.sortedFuelAll = ['Affald', 'Sol', 'Flis', 'Halm', 'HPA', 'Pellet', 'Elec', 'OV-Arla', 'OV-Arla2', 'OV-Birn', 'OV-Ptx', 'FoxOV', 'Gratis', 'Ngas', 'BioOlie', 'FGO', 'Stenkul']

        self.plantFuels = {upr: list() for upr in self.upr if self.onUglobal[upr] }   # Key is upr, Value is list of fuels (f).
        for f in self.fuels:
            uprOfFuel = list(self.fuelMix[self.fuelMix[f] > 0.0].index)
            for upr in uprOfFuel:
                if self.onUglobal[upr] and f not in self.plantFuels[upr]:
                    (self.plantFuels[upr]).append(f)
                
        # Create inverse of plantFuel.
        self.fuelPlant = {f: list() for f in self.activeFuels}   # Key is fuel, Value is list of plants (may be empty)
        for upr, fuelList in self.plantFuels.items():
            for f in fuelList:
                if not upr in self.fuelPlant[f]:
                    self.fuelPlant[f].append(upr)
                
        # for f in self.fuels:
        #     self.fuelPlant[f] = [p for p, fp in self.plantFuels.items() if fp == f]
        
        # Create sortedFuel for graphing, including only fuels used by actually available plants.
        self.sortedFuel = list()
        for fuel in self.sortedFuelAll:
            if fuel in self.activeFuels:
                self.sortedFuel.append(fuel)

        # Create sortedUpr for graphing, first ordering by DH-network, next by plant name.
        # sortedUpr is based on OnUGlobal hence is applicable across all plots as a list of potentially available plants.
        self.sortedUpr = list()
        for prefix in ['Ma','Ho','St']:
            for upr in self.availUpr:
                if upr[:2] == prefix:
                    self.sortedUpr.append(upr)
    
        self.uNames    = mec.getVerbosePlantNames()  # Key is abbr. plant name, Value is long name.
        self.plantColors, self.fuelColors = mec.getColorMap()
        self.uprColors = [self.plantColors[upr] for upr in self.sortedUpr]
        self.fColors   = [self.fuelColors[f] for f in self.sortedFuel]

        
        self.validPriceLevels = ['HeatMargPrice', 'HeatCapacPrice', 'HeatTotalPrice']
        self.validHeatLevels  = ['HeatGen', 'HeatSent']
    
        # Get records of the StatsMecU data for the optimal master iteration.
        self.iterNo = max(2, int(gwyr.getValue('IterOptim')))
        self.iter   = f'iter{self.iterNo}'
        self.dfRecsMecU = gwyr.getRecords('StatsMecUPerIter', 'value')
        self.dfIterMecU = self.dfRecsMecU[self.dfRecsMecU.iter == self.iter] 
        self.dfIterMecU = self.dfIterMecU.drop(columns=['iter'])

        self.dfRecsMecF = gwyr.getRecords('StatsMecFPerIter', 'value')
        self.dfIterMecF = self.dfRecsMecF[self.dfRecsMecF.iter == self.iter] 
        self.dfIterMecF = self.dfIterMecF.drop(columns=['iter'])

        # Extract StatsMecF tables for all topics, aggregated on an annual level. Key is topicMecF, Value is dataframe (index=fuel, columns=periods).
        self.yearTablesMecF = mec.extractAllTopicsMecFYearly(self.topicsMecF, self.dfIterMecF, self.periods)

        # Extract StatsMecU tables for all but price topics, aggregated from monthly to annual level.
        self.yearTablesMecU  = mec.extractAllTopicsMecUYearly(self.topicsMecU, self.dfIterMecU, self.periods)
        self.dfHeatGen       = self.yearTablesMecU['HeatGen']
        self.dfHeatSent      = self.yearTablesMecU['HeatSent']
        self.dfContribMargin = self.yearTablesMecU['ContribMargin']
        self.dfCapacCost     = self.yearTablesMecU['CapacCost']
        self.dfFuelQty       = self.yearTablesMecU['FuelQty']
        
        # Compute total heat production price on an annual basis.
        self.dfHeatMargPrice  = pd.DataFrame(data=0.0, index=self.sortedUpr, columns=self.years, dtype='float') 
        self.dfHeatCapacPrice = pd.DataFrame(data=0.0, index=self.sortedUpr, columns=self.years, dtype='float') 
        self.dfHeatTotalPrice = pd.DataFrame(data=0.0, index=self.sortedUpr, columns=self.years, dtype='float') 
        
        for upr in self.sortedUpr:
            for yr in self.years:
                if self.dfHeatGen.loc[upr,yr] > 0:
                    self.dfHeatMargPrice.loc[upr,yr]  = (                             - self.dfContribMargin.loc[upr,yr]) / self.dfHeatSent.loc[upr,yr]
                    self.dfHeatCapacPrice.loc[upr,yr] = (self.dfCapacCost.loc[upr,yr]                                   ) / self.dfHeatSent.loc[upr,yr]
                    self.dfHeatTotalPrice.loc[upr,yr] = (self.dfCapacCost.loc[upr,yr] - self.dfContribMargin.loc[upr,yr]) / self.dfHeatSent.loc[upr,yr]
        
        self.yearTablesMecU['HeatMargPrice']  = self.dfHeatMargPrice
        self.yearTablesMecU['HeatCapacPrice'] = self.dfHeatCapacPrice
        self.yearTablesMecU['HeatTotalPrice'] = self.dfHeatTotalPrice
    
        self.dfCapExist  = gwyr.getDataFrame('CapUExistPer')   # Transpose to get plants as index and periods as columns.
        self.dfCapNew    = gwyr.getDataFrame('CapUOptim')
        self.dfOnUNomPer = gwyr.getDataFrame('OnUNomPer')
        
        # Drop periods not in range.
        dropPeriods = ['per'+str(p) for p in range(1, len(self.dfCapExist.columns) + 1) if p not in self.periods]
        dropU       = [u for u in self.onUglobal.keys() if u not in self.sortedUpr]
            
        self.sortedU = [u for u in self.sortedUpr if u not in dropU]        
            
        self.dfCapExist  = (self.dfCapExist.drop( columns=dropPeriods)).drop(labels=dropU, axis=0)
        self.dfCapNew    = (self.dfCapNew.drop(   columns=dropPeriods)).drop(labels=dropU, axis=0)
        self.dfOnUNomPer = (self.dfOnUNomPer.drop(columns=dropPeriods)).drop(labels=dropU, axis=0)
        
        self.dfCapAll = pd.DataFrame(data=0.0, index=self.sortedU, columns=self.pers)
        for upr in self.dfCapAll.index:
            for per in self.pers:
                #--- logger.debug(f'{upr=}, {per=}')
                self.dfCapAll.loc[upr,per] = (self.dfCapExist.loc[upr,per] + self.dfCapNew.loc[upr,per]) * self.dfOnUNomPer.loc[upr,per]
                
        # Convert period names to calendar years.
        self.dfCapAll = self.dfCapAll.rename(dict(zip(self.pers, self.years)), axis=1)

        # Release the gdx-file.
        gwyr = None
        
    def plotColors(self):  #--- , uprList, colorList):
        uprList   = self.sortedU
        colorList = self.uprColors
        fig = plt.figure(figsize=(8,1))
        ax = plt.bar(uprList, data=[1 for i in range(len(colorList))], height=1.0, color=colorList)
        plt.title('Plant colors (uprColors)')
        plt.show()
        
    def plotCapacities(self, maxCapacTick: float, omitSRplants: bool = False, saveAsSvg: bool = True):
        """ Plot capacity evolution vs calendar years """
        
        logger.info('Plotting capacities')
        if omitSRplants:
            dropU = [u for u in self.onUglobal.keys() if u not in self.sortedUpr or 'Gk' in u or 'Ok' in u]
            
        # Get plant colors.
        uColors = [self.plantColors[upr] for upr in self.sortedU]

        dfCaps = self.dfCapAll.T
        ax = dfCaps.plot(kind="bar", stacked=True, color=uColors, figsize=(11, 8), width=0.75) 
        fig = ax.get_figure()
        fig.patch.set_facecolor('white')
        # mec.ax_value_labels(ax, dfCaps, 0.1, 0)
        ax.set_ylabel('Anlægskapaciteter (MWq)', fontsize=14)
        ax.set_xlabel('Årstal', fontsize=14)
        capacSum = self.dfCapAll.sum().max()
        
        #--- maxYticks = 12 if omitSRplants else 15
        #--- plt.yticks([i*20 for i in range(0, maxYticks + 1)])
        
        ax.set_ylim([0, maxCapacTick])
        ax.grid(alpha=0.5)
        ax.set_title(f'{self.scenTitle}: Anlægskapacitets udvikling', fontsize=16)
        handles, labels = ax.get_legend_handles_labels() 
        ax.legend(reversed(handles), reversed(labels), loc='center', bbox_to_anchor=(1.13,0.5), fontsize=12)  
        figName = f'{self.scen}_Kapaciteter.svg'
        if saveAsSvg:
            plt.savefig(os.path.join(self.pathPlot, figName), facecolor="none", bbox_inches='tight')
        if not self.chartGlobals.isInteractive:
            plt.close()            

    def plotHeatByYear(self, heatLevel: str = 'HeatGen'):
        """ Plot heat level for actual year """
        
        logger.info('Plotting heat level across years')
        if heatLevel not in self.validHeatLevels:
            raise ValueError(f'{heatLevel=} is not valid, must be one of ({self.validHeatLevels}).')
        
        dfTopic     = (self.yearTablesMecU[heatLevel]).T   # Transposed dataframe s.t. plants become row index.
        dropColumns = [u for u in dfTopic.columns if u not in self.sortedUpr]
        dfTopic.drop(columns=dropColumns, inplace=True)
        dfTopic     = dfTopic[self.sortedUpr]
        
        ax = dfTopic.plot(kind="bar", stacked=True, color=self.uprColors, figsize=(12,7), width=0.75)
        fig = ax.get_figure()
        fig.patch.set_facecolor('white')

        ndiv = 100_000
        ymax = (dfTopic.T).sum().max()   # Max. heat of any year.
        ymax = ndiv * np.ceil(ymax / ndiv)
        ax.set_ylim([0.0, ymax])
        ax.grid(alpha=0.5)
        ax.set_ylabel('MWq', fontsize=14)
        ax.set_xlabel('Årstal', fontsize=14)
        
        if heatLevel == 'HeatSent':
            ax.set_title(f'{self.scenTitle}: Varmeleverance år {self.years[0]} - {self.years[-1]}', fontsize=14)
        elif heatLevel == 'HeatGen':
            ax.set_title(f'{self.scenTitle}: Varmeproduktion år {self.years[0]} - {self.years[-1]}', fontsize=14)
        else:
            raise ValueError(f'{heatLevel=} is not recognized.')
    
        handles, labels = ax.get_legend_handles_labels()
        ax.legend(reversed(handles), reversed(labels), loc='center', bbox_to_anchor=(1.13,0.5))
        
        figName = f'{self.scen}_Varmeproduktion_årstotal'
        plt.savefig(os.path.join(self.pathPlot, figName + '.svg'), facecolor="none", bbox_inches='tight')
        plt.savefig(os.path.join(self.pathPlot, figName + '.png'), facecolor="none", bbox_inches='tight')
        if not self.chartGlobals.isInteractive:
            plt.close()            


    def plotHeatByMonth(self, year: int, heatLevel: str = 'HeatGen', omitWholeYear: bool = True):
        """ Monthly plot of heat generation or deliverance. """
        
        logger.info(f'Plotting heat by month of {year=}')
        if heatLevel not in self.validHeatLevels:
            raise ValueError(f'{heatLevel=} is not valid, must be one of ({self.validHeatLevels}).')
    
        actualYear  = str(year)
        period      = self.year2per[actualYear]
        monthTables = mec.extractAllTopicsMecUMonthly(period, self.topicsMecU, self.dfIterMecU, self.periods)

        # Generate monthly plot of heatLevel for each active plant.
        dfTopic = (monthTables[heatLevel]).T
        dropColumns = [u for u in dfTopic.columns if u not in self.sortedUpr]
        dfTopic.drop(columns=dropColumns, inplace=True)
        dfTopic = dfTopic[self.sortedUpr]
        if omitWholeYear:
            dfTopic = dfTopic.drop(labels=['ÅR'], axis=0)
        
        ax = dfTopic.plot(kind="bar", stacked=True, color=self.uprColors, figsize=(12,7), width=0.75)
        fig = ax.get_figure()
        fig.patch.set_facecolor('white')

        ndiv      = 10_000
        heatMax   = (dfTopic.T).sum().max()   # Max. heat of any month.
        heatMax   = np.ceil(heatMax / ndiv) * ndiv
        ax.set_ylim([0.0, heatMax])
        ax.grid(alpha=0.5)
        ax.set_ylabel('MWq', fontsize=14)
        ax.set_xlabel('Årstal', fontsize=14)
    
        handles, labels = ax.get_legend_handles_labels()
        ax.legend(reversed(handles), reversed(labels), loc='center', bbox_to_anchor=(1.13, 0.5))
        
        if heatLevel == 'HeatSent':
            ax.set_title(f'{self.scenTitle}: Varmeleverance månedsniveau i {actualYear}', fontsize=14)
        elif heatLevel == 'HeatGen':
            ax.set_title(f'{self.scenTitle}: Varmeproduktion månedsniveau i {actualYear}', fontsize=14)
        else:
            raise ValueError(f'{heatLevel=} is not recognized.')
    
        figName = f'{self.scen}_{actualYear}_Varmeproduktion_månedsniveau'
        plt.savefig(os.path.join(self.pathPlot, figName + '.svg'), facecolor="none", bbox_inches='tight')
        plt.savefig(os.path.join(self.pathPlot, figName + '.png'), facecolor="none", bbox_inches='tight')
        if not self.chartGlobals.isInteractive:
            plt.close()            


    def plotVpoByMonth(self, year: int, priceLevel: str, omitWholeYear: bool = False,  debug: bool = False):
        """ Monthly plot of combined heat production price showing contributions from each active plant. """
    
        logger.info(f'Plotting heat {priceLevel=} by month for {year=}')

        if not priceLevel in self.validPriceLevels:
            raise ValueError(f'{priceLevel=} is not valid. Choose from: {self.validPriceLevels}')

        actualYear  = str(year)
        period      = self.year2per[actualYear]
        monthTables = mec.extractAllTopicsMecUMonthly(period, self.topicsMecU, self.dfIterMecU, self.periods)
            
        # TODO Introduce heatLevel as argument to this function.
        dfHeatGen   = mec.getCleanTopic('HeatGen',  monthTables, self.sortedUpr)
        dfHeatPrice = mec.getCleanTopic(priceLevel, monthTables, self.sortedUpr)
        if omitWholeYear:
            dfHeatGen   = dfHeatGen.drop(labels=['ÅR'], axis=1)
            dfHeatPrice = dfHeatPrice.drop(labels=['ÅR'], axis=1)
    
        # Compute share of generated heat by plant upr in each month.
        heatGenSum     = (dfHeatGen.T).sum()
        dfHeatGenShare = dfHeatGen.copy(deep=True)      # Share of generated heat by plant upr in each month.
        heatGenTotalPrice = dict()                      # Key is month name (JAN, FEB, ...)
        for upr in dfHeatGen.columns:
            dfHeatGenShare[upr] = dfHeatGen[upr] / heatGenSum.values
            
        # Compute combined total heat gen price for each month. sum(HeatGen * HeatTotalPrice) / sum(HeatGen)
        heatGenCosts   = dfHeatGen * dfHeatPrice
        heatPriceMonth = heatGenCosts.sum(axis=1) / heatGenSum   # Series with month names as index.
        ndiv           = 50
        heatPriceMax   = heatPriceMonth.max()
        heatPriceMax   = np.ceil(heatPriceMax / ndiv) * ndiv
        heatPriceMin   = heatPriceMonth.min()
        heatPriceMin   = min(0.0, np.floor(heatPriceMin / ndiv) * ndiv)
        # logger.debug(f'{heatPriceMin=}, {heatPriceMax=}')
        
        # Compute for each month and for each plant upr the heat-based share of the total price.
        dfPriceShare = dfHeatGenShare.copy(deep=True)
        for upr in dfHeatGen.columns:
            dfPriceShare[upr] = dfHeatGenShare[upr] * heatPriceMonth

        if debug:
            self.monthTables    = monthTables
            self.dfHeatGen      = dfHeatGen
            self.dfHeatPrice    = dfHeatPrice
            self.dfHeatGenShare = dfHeatGenShare
            self.heatGenCosts   = heatGenCosts
            self.heatPriceMonth = heatPriceMonth
            self.dfPriceShare   = dfPriceShare
    
        # Generate stacked bar chart of heat generation share in each month.
        ax = dfPriceShare.plot(kind="bar", stacked=True, color=self.uprColors, figsize=(12, 7), width=0.75)
        fig = ax.get_figure()
        fig.patch.set_facecolor('white')

        handles, labels = ax.get_legend_handles_labels()
        ax.legend(reversed(handles), reversed(labels), loc='center', bbox_to_anchor=(1.13, 0.5))
        ax.grid(alpha=0.5)
        ax.set_ylim([heatPriceMin, heatPriceMax])
        ax.set_xlabel('Måned ' + actualYear, fontsize=12)
        ax.set_ylabel('DKK / MWhq', fontsize=12)
        if 'Marg' in priceLevel:
            ax.set_title(f'{self.scenTitle}: Marginal varmeproduktionspris', fontsize=14)
        else:
            ax.set_title(f'{self.scenTitle}: Total varmeproduktionspris')
            
        # Put label on each bar showing the heat price if heat generation share is above either threshold.
        bars = [rect for rect in ax.get_children() if isinstance(rect, mpl.patches.Rectangle)]
        barValues = np.asanyarray(dfHeatPrice.T.values, dtype='float')
        barValues = barValues.reshape(barValues.size, order='C')
        
        if debug:
            self.barValues = barValues
            
        barThreshold    = 2.0    # A bar patch having a value below barThreshold will not be labeled.
        heightThreshold = 5.0    # Threshold in units of GWhq
        #--- logger.debug(f'{barValues.size=}')
        #--- logger.debug(f'{barValues=}')
        mec.label_bar(ax, bars[:-1], '.1f', barValues, barThreshold, heightThreshold)
        
        figName = f'{self.scen}_{actualYear}_{priceLevel}'
        plt.savefig(os.path.join(self.pathPlot, figName + '.svg'), facecolor="none", bbox_inches='tight')
        plt.savefig(os.path.join(self.pathPlot, figName + '.png'), facecolor="none", bbox_inches='tight')
        if not self.chartGlobals.isInteractive:
            plt.close()            

    def getProductionData(self, year: int, saveProdDataToExcel: bool = False) -> MecProdData:
        # Generate data for heat production for a selected year and returns as dataframe.  
    
        logger.info(f'Getting production data for {year=}')
        actualYear = str(year)
        period     = self.year2per[actualYear]              # Period as string 'perN'
        #--- periodNo   = self.periods.index(int(period[3:]))    # Period is integer
    
        index_timestamps = pd.date_range(start=f'1/1/{actualYear} 00:00', end=f'31/12/{actualYear} 23:00', freq='H')
        leap             = [ts for ts in index_timestamps if ts.month == 2 and ts.day == 29]
        index_timestamps = index_timestamps.drop(leap)
    
        gdxNamePeriod = f'MEC_Results_{self.iter}_{period}_Scen_{self.scen}.gdx'
        pathGdxPeriod = os.path.join(self.pathRes, gdxNamePeriod)
        
        # Check existence of file.
        path = Path(pathGdxPeriod)
        if not path.exists():
            raise FileNotFoundError(pathGdxPeriod)
    
        gwmo = gw.GdxWrapper(name='Period' + actualYear, pathFile=pathGdxPeriod, logger=logger)

        nblock     = int(gwmo.getValue('Nblock'))
        onTimeAggr = int(gwmo.getValue('OnTimeAggr'))
        onDeAggr   = int(gwmo.getValue('OnDeAggr'))
        bLen = np.array([int(b) for b in gwmo.getValues('BLen', 'tt', fixSetKeyValues={} )][:nblock])
        doUnpack = (nblock < 8760) and (onTimeAggr != 0) and (onDeAggr == 0)
    
        dfOnU = pd.DataFrame(index = self.U, columns = ['OnU'])
        dfOnU['OnU'] = gwmo.getValues('OnU', 'u', {}) 
        onU = dfOnU['OnU'].to_dict()
        
        # Reading results from operations optimization.
    
        #--- PrisMWh = gwmo.getValues('Brandsel', 'f', {'lblBrandsel': 'PrisMWh'})
        #--- dfProd['NGasPris'] = w.getValues('GasPriceActual_tt','tt',{})
    
        # DataFrame dfProd will hold all necessary production data, consumption and elspot series.
        dfProd = pd.DataFrame(index = index_timestamps, columns=[])
        
        # Select time-dependent 2D-symbols (items) to be retrieved from the gdx-file.
        # Symbol suffixed with '_L' are space-efficient replicas of the level-attribute of the GAMS variable of the same name without suffix.
        # This hack saves quite a bit of extraction time for large symbols like bOn, Q, PowInU and FuelQty.
        Item = mec.Item
        items = [  # active  gdxName             dfName     gdxDim  pyList    unpackAction       doClip
                Item(True,  'ElspotActual_tt',  'Elspot',   '',     None,     unpackAction=None),
                Item(True,  'QDemandActual_tt', 'QDem',     'net',  self.NET, unpackAction=None,   doClip=True),
                Item(True,  'Q_L',              'Q',        'u',    self.U,   unpackAction=MEAN),
                Item(True,  'LVak_L',           'LVak',     'vak',  self.VAK, unpackAction=CONST)

                # Item(False, 'Pnet_L',           'Pnet',     'kv',   self.KV,  unpackAction=MEAN),
                # Item(False, 'PowInU_L',         'PowInU',   'upr',  self.UPR, unpackAction=MEAN),
                # Item(True,  'FuelQty_L',        'FuelQty',  'upr',  self.UPR, unpackAction=MEAN),
                # Item(False, 'bOn_L',            'bOn',      'upr',  self.UPR, unpackAction=CONST)
                ]
        
        # Associate an unpack action to each GAMS symbol: 'const' means assign packed value to all unpacked timestamps within a block.
        unpackActions = {'bOn_L':'const', 'LVak_L':'const', \
                         'Q_L':'mean', 'FuelQty_L':'mean','PowInU_L': 'mean', 'Pnet_L': 'mean'}

        # Efficient loading from gdx-file by retrieving the entire symbol and dropping unwanted parts afterwards.
        for item in items:
            if item.active:
                logger.info(f'  Extracting item: {item.gdxName} ...')
                if item.pyList is None:
                    df = gwmo.getValues(item.gdxName, 'tt', {})
                    if doUnpack and item.unpackAction is not None:
                        df = mec.unpackGamsSymbol(df, bLen, unpackActions[item.gdxName])
                    dfProd[item.dfName] = df
                else:
                    df = gwmo.getDataFrame(item.gdxName)
                    # Drop columns not in pylist
                    drops = [d for d in df.columns if d not in item.pyList]
                    df = df.drop(labels=drops, axis=1)
                    if item.doClip:
                        df = df.clip(lower=0.0) 
  
                    if doUnpack and item.unpackAction is not None:
                        df = mec.unpackGamsSymbol(df, bLen, unpackActions[item.gdxName])

                    # Rename columns to obtain unique names.
                    renames = {element: f'{item.dfName}.{element}' for element in item.pyList}
                    df = df.rename(columns=renames)
                    for col in df.columns:
                        dfProd[col] = df[col].values  # Needs to use values, as index of df differs from index of dfProd.
        
        # Optionally, save dfProd to Excel for later reference (pure convenience).
        if saveProdDataToExcel:
            fileName =  f'Driftsoptimering_{self.scen}_{self.iter}_{period}.xlsx'
            logger.info(f'Saving production data to Excel-file {fileName}')
            
            xlapp = xw.App(visible=False, add_book=True)
            wb = xlapp.books(1)
            sh = wb.sheets(1)
            sh.name = 'dfProd'
            sh.range('A10').value = dfProd
            wb.save(os.path.join(self.pathRes, fileName))
            wb.close()
            xlapp.quit()
            xlapp = None
        
        # Release gdx file        
        gwmo = None
        
        return MecProdData(year, dfProd, onU, leap)

    def plotCO2BiomassConsumptionByYear(self, debug: bool = False):
        """ CO2-emission and Biomass consumption """

        logger.info('Plotting CO2-emission and Biomass consumption across years')

        # Extract CO2-emission
        dfCO2regul = self.yearTablesMecU['CO2QtyRegul']      # Index is plants u, columns are years
        dropPlants = [u for u in dfCO2regul.index if u not in self.sortedUpr]
        dfCO2regul = dfCO2regul.drop(dropPlants)         # Remove rows of unavailable plants
        dfCO2regul = dfCO2regul.loc[self.sortedUpr, :]   # Sort rows according to sortedUpr

        # Extract fuel consumption
        # dfFuelQty = self.yearTablesMecU['FuelQty']       # Index is plants u, columns are years
        # dfFuelQty = dfFuelQty.drop(dropPlants)           # Remove rows of unavailable plants
        # dfFuelQty = dfFuelQty.loc[self.sortedUpr, :]     # Sort rows according to sortedUpr
        dfFuelQty = self.yearTablesMecF['Qty']           # Index is fuel (f), columns are years

        # Setup dataframe to hold aggregated values of CO2-emission and biomass consumption
        dfTopic   = pd.DataFrame(data=0.0, index=['CO2-emission'] + [f for f in self.fuelBio], columns=dfFuelQty.columns)
        fuelBio = self.fuelBio  #--- [f for f in self.fuelBio if f in self.activeFuels]
        longNames = ['CO2-emission (ton)'] + [f + ' (ton)' for f in fuelBio] 
            
        # Compute total CO2-emissions.
        dfTopic.loc[dfTopic.index[0], :] = dfCO2regul.sum(axis=0) * self.co2EmisWasteCorrectionFactor    # Sum over plants (rows). OBS: unit is ton for CO2.
        
        # Compute fuel consumption: see self.fuelUnits for quantity measure units.
        for f in fuelBio:
            dfTopic.loc[f, :] = dfFuelQty.loc[f, :] / 1000    # Convert from kg to ton.

        dfTopic = dfTopic.rename(axis=0, mapper=dict(zip(list(dfTopic.index), longNames)) )
        dfTopic.index.name = 'År'
        
        bioColors = [self.fuelColors[f] for f in fuelBio]

        ax = (dfTopic.iloc[1:].T).plot(kind="bar", stacked=True, color=bioColors, figsize=(12, 7), width=0.75)
        fig = ax.get_figure()
        fig.patch.set_facecolor('white')

        # Find the maximum stacked sum of fuel consumption over the years.
        ymax = dfTopic.iloc[1:,:].sum().max()
        ndiv = 10_000
        ymax = ndiv * np.ceil(ymax / ndiv)
        # ymax = 120_000
        #--- logger.debug(f'{ymax=}')
        ax.set_xlabel('År')
        ax.set_ylim([0, ymax])
        ax.set_title(f'{self.scenTitle}: CO2-emission og Biomasse-forbrug for år {self.years[0]} - {self.years[-1]}', fontsize=14)
        ax.set_ylabel('Brændselsforbrug (ton)')
        ax.grid(alpha=0.5)
        
        includeCO2emissions = True
        if includeCO2emissions:
            (dfTopic.loc[dfTopic.index[0]].T).plot(secondary_y=True, color='k', style='--', linewidth=2, label='_')
            fig = ax.get_figure()
            fig.patch.set_facecolor('white')

            ax.right_ax.set_ylabel(dfTopic.index[0])
            
            # Find the maximum of CO2 emissions over the years.
            ymax = dfTopic.loc[dfTopic.index[0]].max()
            ndiv = 10_000
            ymax = ndiv * np.ceil(ymax / ndiv)
            # ymax = 120_000
            ax.right_ax.set_ylim([0, ymax])
            
            ax.right_ax.legend([dfTopic.index[0]], loc='upper right')
            handles, labels = ax.get_legend_handles_labels()
            ax.legend(reversed(handles), reversed(labels), loc='center', bbox_to_anchor=(1.13, 0.5))

            handles1, labels1 = ax.get_legend_handles_labels()                  # Definerer handles and labels for legend på venstre ordinat.
            handles2, labels2 = ax.right_ax.get_legend_handles_labels()         # Definerer handles and labels for legend på højre ordinat.
            handles = reversed(handles1 + handles2)
            levels  = reversed(labels1  + labels2)
            ax.legend(handles, levels, loc='center', bbox_to_anchor=(1.23, 0.7))           
            figName = f'{self.scen}_CO2-emission Biomasse-forbrug_Årstotal'
        else:
            handles, labels = ax.get_legend_handles_labels()
            ax.legend(reversed(handles), reversed(labels), loc='center', bbox_to_anchor=(1.13, 0.5))
            figName = f'{self.scen}_Biomasseforbrug_CO2_Emission_Årstotal'
        
        ax.set_xlabel('År')

        plt.savefig(os.path.join(self.pathPlot, figName + '.svg'), facecolor="none", bbox_inches='tight')
        plt.savefig(os.path.join(self.pathPlot, figName + '.png'), facecolor="none", bbox_inches='tight')
        if not self.chartGlobals.isInteractive:
            plt.close()            
        return

    def plotHeatDistributionAsPie(self, prodData: MecProdData):
        # Pie-chart annual basis 
        
        logger.info('Plotting pie-chart of heat distribution across years')

        #--- if self.onTimeAggr != 0 and self.onDeAggr == 0:
        #---    raise ValueError(f'Time aggregated results are not yet supported: {self.onTimeAggr=}, {self.onDeAggr=}')


        actualYear = str(prodData.year)
        period     = self.year2per[actualYear]              # Period as string 'perN'
        #--- periodNo   = self.periods.index(int(period[3:]))    # Period is integer

        # Take a subset of dfProd holding only heat generation.
        dfProd    = prodData.dfProd
        chartDict = {col: col[2:] for col in dfProd.columns if col.startswith('Q.') and not 'Vak' in col }  #  Key is '<upr>', Value is 'Q.<upr>'
        dfTemp = dfProd[chartDict.keys()]
        dfTemp = dfTemp.rename(columns=chartDict)   # Remove prefix 'Q.' .
        dfTemp = dfTemp[self.sortedUpr]
        
        dfPie = pd.DataFrame()         # Dataframe has only one row.
        for upr in self.sortedUpr:
            if upr in dfTemp.columns and not upr in self.VAK:
                # print(f'{upr}')
                dfPie.loc[0, self.uNames[upr]] = sum(dfTemp[upr])   # Sum of heat generation over entire year.
                
        dfPie     = dfPie.T
        dfPieCopy = dfPie #--- .copy(deep=True)
        dfPie     = dfPie.loc[:,0]
        
        explode  = tuple(np.repeat(0.02, len(dfTemp.columns)))    
        colors   = [self.plantColors[upr] for upr in dfTemp.columns if not upr in self.VAK]
        
        # Generate legend labels holding for each plant the percentage and absolute value [GWHq] of all heat generation. 
        values   = [dfPie[i] for i in range(len(dfPie))]
        total    = sum(values)
        pct      = np.round(values / total * 100.0, 1)
        old2newColumns = {dfPie.index[i]: f'{dfPieCopy.index[i]}: {str(pct[i])} % ({str(np.round(values[i] / 1000, 1))} GWh)' for i in range(len(dfPie)) }  
        dfPie = dfPie.rename(old2newColumns)
         
        ax = dfPie.plot(kind='pie', explode=explode, pctdistance=1.2, colors=colors, figsize=(4,4), shadow=False, 
                         startangle=0, fontsize=10, labeldistance=1.5, labels=['' for i in dfPie.index])
        
        fig = ax.get_figure()
        fig.patch.set_facecolor('white')
        ax.axis('equal')    # Equal aspect ratio ensures that pie is drawn as a circle.
        ax.set_ylabel('')
        ax.set_title(f'{self.scenTitle}, År {actualYear}', fontsize=14)
        plt.legend(labels=dfPie.index, loc='center', bbox_to_anchor=(1.60, 0.5), fontsize=8)
        
        # ax.legend(reverse=True, loc='center', bbox_to_anchor=(1.60,0.5))

        figName = f'{self.scen}_{actualYear}_Varmeprod_pie'
        plt.savefig(os.path.join(self.pathPlot, figName + '.svg'), facecolor="none", bbox_inches='tight')
        plt.savefig(os.path.join(self.pathPlot, figName + '.png'), facecolor="none", bbox_inches='tight')
        if not self.chartGlobals.isInteractive:
            plt.close()            

        return

    def plotHeatDistribution(self, prodData: MecProdData, debug: bool = False):
        """ Area chart heat generation averaged over 24 hours. """

        logger.info(f'Plotting heat distribution averaged over 24 hours for year={prodData.year}')

        #--- if self.onTimeAggr != 0 and self.onDeAggr == 0:
        #---     raise ValueError(f'Time aggregated results are not yet supported: {self.onTimeAggr=}, {self.onDeAggr=}')

        actualYear = str(prodData.year)
        #--- period     = self.year2per[actualYear]              # Period as string 'perN'
        #--- periodNo   = self.periods.index(int(period[3:]))    # Period is integer
        
        # TODO Move groupNames to __init__  and convert groups to argument.
        groups     = { 'Ek': True, 'Gk': True, 'Ok': True, 'Ov': False }       # Key is group id, Value is True if active grouping applies. 
        groupNames = { 'Ek':'Elkedler', 'Gk': 'Gaskedler', 'Ov': 'Overskudsvarme'}

        resample_time = '24H' 
        pd.options.mode.chained_assignment = None  # default='warn'

        # Fetch and optionally aggregate heat flows. Column names af dfTemp are plant names.
        onU    = prodData.onU
        dfProd = prodData.dfProd
        chartDict = {col: col[2:] for col in dfProd.columns if col.startswith('Q.') and not 'Vak' in col }  #  Key is '<upr>', Value is 'Q.<upr>'
        dfTemp1 = dfProd[chartDict.keys()]
        
        #--- logger.debug(f'{debug=}')
        #--- logger.debug(f'{dfTemp1.index=}')
        if debug:
            self.onU       = onU
            self.chartDict = chartDict
            self.groups    = groups 
            self.dfTemp1   = dfTemp1
        
        for group in groups:
            if groups[group]:  # If True, then group is active.
                colsGroup = {member: f'Q.{member}' for member in self.UPR if group in member and onU[member]}    
                #--- logger.debug(f'{group=}: {colsGroup=}')
                #--- logger.debug(f'{dfTemp1.columns=}')
                #--- logger.debug(f'{dfTemp1.columns=}')
                dfTemp1[group] = (dfProd[colsGroup.values()]).sum(axis=1).values
                dfTemp1.drop(columns=colsGroup.values(), inplace=True)
                
        # Add columns of heat stored, summed over storages.
        colsLVak = [f'LVak.{vak}' for vak in self.VAK if onU[vak]]
        dfTemp1['LVak'] = (dfProd[colsLVak]).sum(axis=1)
       
        # Handling leap year
        dfTemp1 = self.handleLeapYear(dfTemp1, prodData.leap, resample_time)
        
        # Create data for line elements (delivered heat and stored heat) in separate dataframe.
        colsQDem = [f'QDem.{net}' for net in self.NET]
        dfTemp2  = pd.DataFrame(data=None, index=dfProd.index, columns=[])
        dfTemp2['Leveret FJV an dist.'] = (dfProd[colsQDem]).sum(axis=1).values
        dfTemp2 = self.handleLeapYear(dfTemp2, prodData.leap, resample_time)
        dfTemp2['Lagret FJV'] = dfTemp1['LVak'] 
        
        dfTemp1.drop(columns=['LVak'], inplace=True)
        dfTemp1 = dfTemp1.loc[:, (dfTemp1 > 0.25).any(axis=0)]
        dfTemp1 = dfTemp1.rename(columns=chartDict)  # Remove prefix 'Q.'
        uprNames = dict()
        for col in dfTemp1.columns:
            if col in self.uNames:
                uprNames[col] = self.uNames[col]
            elif col in groupNames:
                uprNames[col] = groupNames[col]
                
        if debug:
            self.uprNames = uprNames
                
        # Fetch colors from column names
        colors = [self.plantColors[upr] for upr in dfTemp1.columns]

        # Generate area plot.
        ax = dfTemp1.plot(kind='area', color=colors, figsize=(10.5, 5), linewidth=0)
        
        fig = ax.get_figure()
        fig.patch.set_facecolor('white')
        #ax.set_xlabel('Tid')
        ax.set_ylabel('Produceret og leveret FJV (MWq)')
        if resample_time == '1H':
            ax.set_ylim([0, 200]) 
            ax.set_yticks(np.arange(0, 201, 50))
        else:
            ax.set_ylim([0, 200]) 
            ax.set_yticks(np.arange(0, 201, 50))        

        dfTemp2['Leveret FJV an dist.'].plot(secondary_y=False, color='k', style='--', linewidth=1, label='_')
        dfTemp2['Lagret FJV'].plot(          secondary_y=True,  color='y', style='--', linewidth=1)
        ax.right_ax.set_ylabel('Lagret FJV (MWhq)')
        ax.right_ax.set_ylim([0, dfTemp2['Lagret FJV'].max()])
        ax.right_ax.legend(['Lagret FJV', 'Leveret FJV an dist.'], loc='upper right')
        
        if resample_time == '1H':    # Slice of calendar year
            ax.right_ax.set_xlim(f'{actualYear}-02-24 00:00:00', f'{actualYear}-03-10 00:00:00')
            ax.right_ax.legend(['lagret FJV','Leveret FJV an dist.'], loc='upper right')
            figName = f'{self.scen}_{actualYear}_Varmeprod_timebasis_stacked_1H'    
            ax.set_title(f'{self.scenTitle}, Varmeproduktion - 1 times midling')
        else:                        # Entire calendar year
            ax.right_ax.set_xlim(f'{actualYear}-01-01 00:00:00', f'{actualYear}-12-31 23:00:00')
            ax.set_title(f'{self.scenTitle}, Varmeproduktion - 24 timers midling')
            figName = f'{self.scen}_{actualYear}_Varmeprod_timebasis_stacked_24H'   

        ax.grid(alpha=0.5)
       
       # ax.legend(loc='center',bbox_to_anchor=(1.23, 0.5))      
        handles1, labels1 = ax.get_legend_handles_labels()                  # Definerer handles and labels for legend på venstre ordinat.
        handles2, labels2 = ax.right_ax.get_legend_handles_labels()         # Definerer handles and labels for legend på højre ordinat.
        h = reversed(handles1 + handles2)
        l = reversed(labels1  + labels2)
        ax.legend(h, l, loc='center', bbox_to_anchor=(1.23, 0.5))           # Viser labels omvendt af normalt, så værkerne vises i samme rækkefølge som i bar-plottet.

        plt.savefig(os.path.join(self.pathPlot, figName + '.svg'), facecolor="none", bbox_inches='tight')
        plt.savefig(os.path.join(self.pathPlot, figName + '.png'), facecolor="none", bbox_inches='tight')
        if not self.chartGlobals.isInteractive:
            plt.close()            
        return

    def handleLeapYear(self, df, leap, resample_time):
        if len(leap) > 1:  # If True, shift to a non-leap year, as a year in this model always has 365 days.
            df.index = df.index - pd.DateOffset(years=1)
            
        df = df.resample(resample_time).mean()

        if len(leap) > 1:  # If True, revert the shift above.
            df.index = df.index + pd.DateOffset(years=1)
        return df
        
    def __str__(self):
        return f'scen={self.scen}'

#%% Setting up scenarios

# Scenarios to run: skip a scenario by commenting its entry.

isInteractive = False
# answer = 'fill-in'
# while answer[:1].lower() not in 'yn':
#     answer  = input('Run as interactive session (y/n) ?')

# isInteractive = answer[:1].lower() == 'y'

# Setting the plotting backend
if isInteractive:
    mpl.use('QtAgg')
else:
    mpl.use('svg')

logger.info(f'Plotting using backend = {mpl.get_backend()}')

scens = { # Key is scenario-id, Value is short name.     Include letter T if a scenario is just for testing and set doTest = True.
                  # 'T11T99T01T00T00': 'TestScenarie',               # Bruges til afprøvning af scripting.
                  
                  'm11s01u00r00f00': 'Basis m/2 Aff',              # Selvbærende forsyning uden OV, to aff-linjer, fra 2025, ny biokedel, MaNVak2 20000 m3. Planperiode 2025 - 2031
                  'm11s01u01r00f00': 'Basis m/2 Aff m/10000 m3 VAK',    # Selvbærende forsyning uden OV, to aff-linjer, fra 2025, ny biokedel, MaNVak2 0 m3. Planperiode 2025 - 2031
                  'm11s01u02r00f00': 'Basis m/2 Aff u/ekstra VAK',   # Selvbærende forsyning uden OV, to aff-linjer, fra 2025, ny biokedel, MaNVak2 0 m3. Planperiode 2025 - 2031

                #   'm11s02u10r00f00': 'Selvbærende forsyning: U/OV m/2 Affaldslinjer, kun ny biokedel',
                #   'm11s02u11r00f00': 'Selvbærende forsyning: U/OV m/1 Affaldslinje, kun ny biokedel',
                #   'm11s02u12r00f00': 'Selvbærende forsyning: U/OV m/0 Affaldslinjer, kun ny biokedel',

                #   'm11s02u20r00f00': 'Selvbærende forsyning: U/OV m/2 Affaldslinjer, alle nye anlæg',
                #   'm11s02u21r00f00': 'Selvbærende forsyning: U/OV m/1 Affaldslinje, alle nye anlæg',
                #   'm11s02u22r00f00': 'Selvbærende forsyning: U/OV m/0 Affaldslinjer, alle nye anlæg',

                #   'm11s02u10r00f01': 'Selvbærende forsyning: U/OV m/2 Affaldslinjer, Biomasse x 2',
                #   'm11s02u11r00f01': 'Selvbærende forsyning: U/OV m/1 Affaldslinje, Biomasse x 2',
                #   'm11s02u12r00f01': 'Selvbærende forsyning: U/OV m/0 Affaldslinjer, Biomasse x 2',

                #   'm11s02u20r00f01': 'Selvbærende forsyning: U/OV m/2 Affaldslinjer, Elpris x 2',
                #   'm11s02u21r00f01': 'Selvbærende forsyning: U/OV m/1 Affaldslinje, Elpris x 2',
                #   'm11s02u22r00f01': 'Selvbærende forsyning: U/OV m/0 Affaldslinjer, Elpris x 2',

                #   'm11s03u10r00f00': 'Overskudsvarme  forsyning: M/OV m/2 Affaldslinjer, kun ny biokedel',
                #   'm11s03u11r00f00': 'Overskudsvarme  forsyning: M/OV m/1 Affaldslinje, kun ny biokedel',
                #   'm11s03u12r00f00': 'Overskudsvarme  forsyning: M/OV m/0 Affaldslinjer, kun ny biokedel',

                #   'm11s03u20r00f00': 'Overskudsvarme  forsyning: M/OV m/2 Affaldslinjer, kun ny biokedel',
                #   'm11s03u21r00f00': 'Overskudsvarme  forsyning: M/OV m/1 Affaldslinje, kun ny biokedel',
                #   'm11s03u22r00f00': 'Overskudsvarme  forsyning: M/OV m/0 Affaldslinjer, kun ny biokedel'
                }

try:
    pathRoot = r'C:\GitHub\23-1002 MEC FF'
    chartGlobals = MecGlobals(pathRoot, scens, isInteractive)

    # Loop scenarios
    doPlotSeasonalTopics = True
    doPlotHeatDistribution = False
    if not doPlotSeasonalTopics and not doPlotHeatDistribution:
        logger.error(f'Both plot types are disabled - nothing will be plotted.')

    for scen in scens:
        logger.info(f'Plotting charts for scenario {scen} ...\n')
        results = MecResults(scen, chartGlobals)
        
        # results.plotColors()
        if doPlotSeasonalTopics:
            results.plotCapacities(maxCapacTick=300.0, omitSRplants=True, saveAsSvg=True)
            results.plotHeatByYear()

            for year in results.years:
                results.plotHeatByMonth(int(year), 'HeatGen')
                results.plotVpoByMonth(int(year), 'HeatMargPrice')
                results.plotVpoByMonth(int(year), 'HeatTotalPrice') #--- , debug=True)
                results.plotCO2BiomassConsumptionByYear()           #--- debug=True)    
        
        if doPlotHeatDistribution:  # Time-consuming due to load of symbol StatsMecUPerIter
            for year in results.years:
                prodData = results.getProductionData(int(year), saveProdDataToExcel=False)
                results.plotHeatDistributionAsPie(prodData)
                results.plotHeatDistribution(prodData)  #--- , debug=True)

except Exception as ex:
    logger.critical(f'{ex} caught in MECcharts', exc_info=True)
finally:
    mec.shutdown(logger, f'{NAME} ended.')
    

