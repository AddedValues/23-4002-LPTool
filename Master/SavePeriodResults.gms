$log Entering file: %system.incName%
  
$OnText
Projekt:        23-1002 MEC Mulighedsanalyse opdateret.
Filnavn:        SavePeriodResults.gms
Scope:          Beregner og gemmer statistik for aktuel periode i aktuel master iteration.
Inkluderes af:  LoopPeriodPost.gms
Argumenter:     <ingen>
$OffText

DoDumpPeriodsToGdx = (DumpPeriodsToGdx GT 0) OR (DumpPeriodsToGdx LT 0);
display DumpPeriodsToGdx, DoDumpPeriodsToGdx;                                                                                                              

if (abs(DumpPeriodsToGdx) EQ 1 AND DoDumpPeriodsToGdx,
  execute_unload "Results actIter actPer.gdx" ; 
#--- elseif (abs(DumpPeriodsToGdx) EQ 2 AND DoDumpPeriodsToGdx),
#---   execute_unload "Results actIter actPer.gdx", yrElspot, yrFjv, actYrElspot, actYrFjv;
);

if (DumpPeriodsToGdx EQ 1, 
  execute_unload "Results actIter actPer.gdx" ;      # Unload entire model.

elseif (DumpPeriodsToGdx EQ 2),
  execute_unload "Results actIter actPer.gdx",       # Unload subset of model (to save disk space).

tt, t,   #--- mo,  
ElspotYear, QDemandYear, actSc, rhStep, beginend, InfeasDir    
net, netq, u, upr, uq, uaff, upsr, cp, kv, ucool, uexist, unew, vak, hp, tr, f, 
aff2cool, InfeasDir, co2kind, tax,
topicAll, topicSolver, topicU, topicMecU, topicT, topicVak, topicFuel, topicOther, 
lblDataU, lblDataAff, lblPrognoses, lblTaxes, lblCHP, lblBrandsel, pipeDataSet, lblDiverse, 
hpSource, lblHpCop, lblCOPyield,
                                 
# Parms
ActScen, HourBegin, HourEnd, HourBeginBidDay, DurationPeriod, BLen, Bbeg, Bend, RhIntv, 
OnTimeAggr, UseTimeAggr, UseTimeExpansion, Nblock, NblockActual, 
OnNet, OnU, OnTrans, 
QDemandActual_hh, ElspotActual_hh, DataU, DataAff, DataHp, DataTransm, QTmin, QTmax, Brandsel,
CapQU, CapQU, QTmax,  
StatsAll, StatsSolver, StatsRH, StatsU,  #--- StatsMecU, 
StatsT, StatsVak, StatsFuel, StatsOther, StatsTax, 
zNormalized, zNormalizedReal, CostInfeas, InfeasTotal,

# Variables

zSlave,                       #                        'Slave objective'
QSales,                       #  (tt)                  'Varmesalg [DKK]'
QInfeas,                      #  (tt,net,InfeasDir)    'Virtuelle varmekilder og -dræn [MW]'
                        
TotalCO2Emis,                 #  (tt,net,co2kind)      'Samlede regulatoriske CO2-emission [ton/h]'
TotalCO2EmisSum,              #  (net,co2kind)         'Sum af regulatorisk CO2-emission [ton]'
CO2KvoteOmkst,                #  (tt,upr)              'CO2 kvote omkostning [DKK]'
#--- TariffEl,                     #  (tt,upr)              'Eltarif på elektrisk drevne anlæg'

#--- Q_L, 
#--- QT_L, 
#--- QRgk_L, 
#--- Qbypass_L, 
#--- Qcool_L, 
#--- PowInU_L, 
#--- Pnet_L,
#--- bOn_L, 
#--- bOnSR_L,             
#--- LVak_L, 


#--- Q,                            #  (tt,u)                'Heat delivery from unit u'
FuelCost,                     #  (tt,upr)              'Fuel cost til el bliver negativ, hvis elprisen går i negativ'
TotalCostU,                   #  (tt,u)
TotalElIncome,                #  (tt,kv)
ElSales,                      #  (tt,kv)               'Indtægt fra elsalg'
#--- ElTilskud,                    #  (tt,kv)

# Transmission
QT,                           #  (tt,tr)               'Transmitteret varme [MWq]'
QTloss,                       #  (tt,tr)               'Transmissionsvarmetab [MWq]'
CostPump,                     #  (tt,tr)               'Pumpeomkostninger'
bOnT,                         #  (tt,tr)               'On/off timetilstand for T-ledninger'
bOnTAll,                      #  (tr)                  'On/off årstilstand for T-ledninger'

#--- FixedDVCost,                  #  (u)                   'Faste DV omk. [DKK/MWf/år]'
#--- FixedDVCostTotal,             #              

#--- PowInU,                       #  (tt,upr)              'Indgivet effekt [MW]'
StartOmkst,                   #  (tt,upr)              'Startomkostning [DKK]'
ElEgbrugOmkst,                #  (tt,upr)              'Egetforbrugsomkostning [DKK]'
VarDVOmkst,                   #  (tt,u)
DVOmkstRGK,                   #  (tt,kv)               'D&V omkostning relateret til RGK [DKK]'
CostInfeas,                   #  (tt,net)              'Infeasibility omkostn. [DKK]'
CostSrPenalty,                #  (tt,net)              'Penalty på SR-varme [DKK]'
TaxProdU,                     #  (tt,upr,tax)
TotalTaxUpr,                  #  (tt, upr)
CO2Emis,                      #  (tt,upr,co2kind)      'CO2 emission [kg]'
CO2emisFuelSum,               #  (f,co2kind)           'Sum af CO2-emission pr. drivmiddel [kg]'
#--- FuelQty,                      #  (tt,upr)              'Drivmiddelmængde [ton]'
FuelHeat,                     #  (tt,kv)               'Brændsel knyttet til varmeproduktion i KV-anlæg'
                                                       
#--- Pnet,                         #  (tt,kv)               'Elproduktion af kraftvarmeværker'
Pback,                        #  (tt,kv)              
Pbypass,                      #  (tt,kv)              
Qback,                        #  (tt,kv)              
Qbypass,                      #  (tt,kv)              
QRgk,                         #  (tt,kv)               'RGK varme fra KV-anlæg'
QbypassCost,                  #  (tt,kv)              
QCool,                        #  (tt,ucool)           
                                                       
bBypass,                      #  (tt,kv)              
bRgk,                         #  (tt,kv)              
#--- bOn,                          #  (tt,upr)              'On/off variable for all units'
bStart,                       #  (tt,upr)              'Indikator for start af prod unit'
bOnRGK,                       #  (tt,kv)               'Angiver om RGK-anlæg er i drift'
bOnSR,                        #  (tt,netq)             'On/off på SR-anlæg i reale forsyningsområder'
                                                       
# VAK                                                  
#--- LVak,                         #  (tt,vak)              'Ladning på vak [MWh]'
QMaxVak,                      #  (tt,vak)              'Øvre grænse på opladningseffekt'
VakLoss,                      #  (tt,vak)              'Storage loss per hour'
#--- CostVak,                      #  (tt,vak)              'Ladeomkostninger for vak'
#--- QVakAbs,                      #  (tt,vak)         'Absolut laderate for beregning af ladeomkostninger [MW]'

# Begrænsning på ejerandel af grundlastvarmen.
Qbase,                        #  (tt)                  'Grundlastvarmeproduktion'
QbasebOnSR                    #  (tt,netq)             'Product af Qbase og bOnSR'


# Equations
#--- EQ_QProdUqmax.m                #  (t,uq)                'Marginals of eqn: Q(t,upr)  =L=  BLen(t) * DataU(upr,'Fmax') * CapQU(upr) * [1 $(not hp(upr)) + sum(hp $sameas(hp,upr), QhpYield(t,hp))] * bOn(t,upr);'
#--- EQ_QProdKVmax.m                #  (t,uq)                'Marginals of eqn: Q(t,upr)  =L=  BLen(t) * DataU(upr,'Fmax') * CapQU(upr) * [1 $(not hp(upr)) + sum(hp $sameas(hp,upr), QhpYield(t,hp))] * bOn(t,upr);'

GradUCapE                      #  (tbid,uelec,updown)   'Følsomheder for CapE allokeringer';
GradUCapESumU                  #  (tbid,updown)         'Sum af GradUCapE over uelec for hver budtime';
GradUCapETotal                 #  (updown)              'Sum af GradUCapESumU over buddøgnet';
 ;

);


if (DoDumpPeriodsToGdx,

#---   # Python-code renaming the newly minted gdx file to a proper name.
#---   
#--- embeddedCode Python:
#---   import os
#---   import datetime
#---   import shutil
#---   
#---   currentDate = datetime.datetime.today().strftime('%Y-%m-%d %Hh%Mm%Ss')
#--- 
#---   actIter = list(gams.get('actIter'))[0]
#---   actPer  = list(gams.get('actPer'))[0]
#--- 
#---   #--- wkdir = gams.wsWorkingDir  # Does not work.
#---   wkdir = os.getcwd()
#---   scen = os.path.basename(os.getcwd())
#---   #--- gams.printLog('wkdir: '+ wkdir)
#--- 
#---   pathOldFile = os.path.join(wkdir, r'Results actIter actPer.gdx')
#---   #--- pathNewFile = os.path.join(wkdir, f'MEC_{scen}_{actIter}_{actPer}_{str(currentDate)}.gdx')
#---   pathNewFile = os.path.join(wkdir, f'MEC_Results_{actIter}_{actPer}.gdx')
#--- 
#---   #--- os.rename(pathOldFile, pathNewFile)
#---   shutil.copy(pathOldFile, pathNewFile)
#---   
#---   #--- gams.printLog(f'File "{os.path.split(pathNewFile)[1]}" written to folder: {wkdir}')
#---   print(f'INFO: SavePeriodResults: {actIter=}, {actPer=},\n {pathOldFile=},\n {pathNewFile=}')
#--- 
#--- endEmbeddedCode 
#--- 
);



