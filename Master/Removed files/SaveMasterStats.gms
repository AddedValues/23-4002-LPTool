$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        SaveMasterStats.gms
Scope:          Beregner og gemmer statistik for master forløb.
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText


#--- AlfaIter('iter1') = 0.0;  # Elimineres aht. dump til Excel: MECMasterOutput.xlsm

NPVIterCopy(iterAlias) = NPVIter(iterAlias);
NPVIterCopy('iter1') = 0.0;

#--- # Sammenfat kapac-omk. for alle anlæg.
#--- # NB: Variabel-kapacitets anlæg beregner kapac-omk anderledes end for eksisterende anlæg.
#--- loop (u $(NOT unew(u)),
#---   # Eksisterende anlæg kan have periode-afh. kapac-omkostninger. Når afskrivning går på nul, kan anlægget stadig benyttes, hvis kapaciteten er større end nul.
#---   CapUCostPerIter(u,perA,iterAlias) = [Capex(u,'fixCost') + DeprecExistPer(u,perA) * 1E+6] $OnUPer(u,perA);
#--- );
CapUCostPerIter(u,perA,iterAlias) = CapUCostPerIter(u,perA,iterAlias) $OnUPer(u,perA);

#INFLATION: Der er taget højde for inflation i inputfilen ... skrives ind i CapUCostPerIter herunder

# Bestem det optimale scenarie.
optIter('iter2') = yes;
optIter(iterAlias) = ord(iterAlias) EQ MasterBestIter(iter);
display optIter;

* Nøgletal for hver iteration.
FLHIter(upr,perA,iterAlias)         = StatsUPerIter(upr,'FullLoadHours',perA,iterAlias) $OnUPer(upr,perA);
OperHoursIter(upr,perA,iterAlias)   = StatsUPerIter(upr,'OperHours',perA,iterAlias) $OnUPer(upr,perA);
PowInUIter(upr,perA,iterAlias)      = StatsUPerIter(upr,'PowInU',perA,iterAlias) $OnUPer(upr,perA);
FuelQtysIter(upr,perA,iterAlias)    = StatsUPerIter(upr,'FuelQty',perA,iterAlias) $OnUPer(upr,perA);
CO2QtyPhysIter(upr,perA,iterAlias)  = StatsUPerIter(upr,'CO2QtyPhys',perA,iterAlias) $OnUPer(upr,perA);
CO2QtyRegulIter(upr,perA,iterAlias) = StatsUPerIter(upr,'CO2QtyRegul',perA,iterAlias) $OnUPer(upr,perA);
HeatGenUIter(upr,perA,iterAlias)    = StatsUPerIter(upr,'HeatGen',perA,iterAlias) $OnUPer(upr,perA);
PowerGenUIter(upr,perA,iterAlias)   = StatsUPerIter(upr,'PowerGen',perA,iterAlias) $OnUPer(upr,perA);
PowerUIter(upr,perA,iterAlias)      = StatsUPerIter(upr,'PowerNet',perA,iterAlias) $OnUPer(upr,perA);
HeatVentedIter(perA,iterAlias)      = StatsOtherPerIter('ucool','HeatVented',perA,iterAlias);

#begin Disabled: Beregn varmepris for hvert aktivt anlæg.
loop (upr,
  loop(per $OnUPer(upr,per),
    loop(iterAlias $(ord(iterAlias) GE 2 AND ord(iterAlias) LE MasterIter),
      If (HeatGenUIter(upr,per,iterAlias) GT 2*tiny,
        tmp = StatsUPerIter(upr,'HeatMargPrice',per,iterAlias) * HeatGenUIter(upr,per,iterAlias);
        HeatMargCostUIter(upr,per,iterAlias) = tmp / HeatGenUIter(upr,per,iterAlias);
        HeatCapCostUIter(upr,per,iterAlias)  = CapUCostPerIter(upr,per,iterAlias) / HeatGenUIter(upr,per,iterAlias);
        HeatCostUIter(upr,per,iterAlias)     = HeatMargCostUIter(upr,per,iterAlias) + HeatCapCostUIter(upr,per,iterAlias);
      #--- Else
      #---   HeatCostUIter(upr,per,iterAlias) = tiny $OnUPer(upr,per);
      );
    );
  );
);
#end
#begin Disabled code
#-loop (unew,
#-  loop(per $OnUPer(unew,per),
#-    loop(iterAlias $(ord(iterAlias) GE 2 AND ord(iterAlias) LE MasterIter),
#-      If (HeatGenUIter(unew,per,iterAlias) GE 2*tiny,
#-        tmp = StatsUPerIter(unew,'HeatMargPrice',per,iterAlias) * HeatGenUIter(unew,per,iterAlias);
#-        HeatCostUIter(unew,per,iterAlias) = (CapUCostPerIter(unew,per,iterAlias) + tmp) / HeatGenUIter(unew,per,iterAlias);
#-      Else
#-        HeatCostUIter(unew,per,iterAlias) = tiny $OnUPer(upr,per);
#-      );
#-    );
#-  );
#-);
#end Disabled code

# Beregn varmepris for alle aktive anlæg under ét.
#--- HeatCostAllIter(per,iterAlias) = tiny;

loop(per,
  loop(iterAlias $(ord(iterAlias) GE 2 AND ord(iterAlias) LE MasterIter),
    HeatAll = sum(upr $(OnUPer(upr,per)), HeatGenUIter(upr,per,iterAlias));
    CapCostAll  = sum (upr $(OnUPer(upr,per)), CapUCostPerIter(upr,per,iterAlias));
    MargCostAll = sum (upr $(OnUPer(upr,per)), StatsUPerIter(upr,'HeatMargPrice',per,iterAlias) * HeatGenUIter(upr,per,iterAlias)); 
    CostAll     = CapCostAll + MargCostAll;
    #remove CostAll = sum (upr $(OnUPer(upr,per)), CapUCostPerIter(upr,per,iterAlias) + StatsUPerIter(upr,'HeatMargPrice',per,iterAlias) * HeatGenUIter(upr,per,iterAlias) );
    if (HeatAll GT card(upr)*tiny,
      HeatCostAllIter(per,iterAlias)     = CostAll / HeatAll;     #--- HeatCostAllIter(per,iterAlias) = CostAll / (HeatAll - HeatVentedIter(per,iterAlias));
      HeatCapCostAllIter(per,iterAlias)  = CapCostAll  / HeatAll;
      HeatMargCostAllIter(per,iterAlias) = MargCostAll / HeatAll;
    );
  );
);

HeatGenNewIter(per,iterAlias) = sum(unew $OnUPer(unew,per), HeatGenUIter(unew,per,iterAlias));
HeatGenAllIter(per,iterAlias) = sum(upr  $OnUPer(upr,per),  HeatGenUIter(upr,per,iterAlias));

#  Parameter HeatMargCostNewOptim(perA)       'Marginal andel af enhedsvarmeproduktionsomkostning over nye anlæg i optimum';
#  Parameter HeatCapCostNewOptim(perA)        'Kapac-andel af enhedsvarmeproduktionsomkostning over nye anlæg i optimum';
#  
#  Parameter HeatMargCostAllOptim(perA)       'Marginal andel af enhedsvarmeproduktionsomkostning over alle anlæg i optimum';
#  Parameter HeatCapCostAllOptim(perA)        'Kapac-andel af enhedsvarmeproduktionsomkostning over alle anlæg i optimum';
    

loop(per,
  loop(iterAlias $(ord(iterAlias) GE 2 AND ord(iterAlias) LE MasterIter),
    HeatAll = sum(unew $(OnUPer(unew,per)), HeatGenUIter(unew,per,iterAlias));
    CapCostAll  = sum (unew $(OnUPer(unew,per)), CapUCostPerIter(unew,per,iterAlias));
    MargCostAll = sum (unew $(OnUPer(unew,per)), StatsUPerIter(unew,'HeatMargPrice',per,iterAlias) * HeatGenUIter(unew,per,iterAlias) );
    CostAll     = CapCostAll + MargCostAll;
    #remove CostAll = sum (unew $(OnUPer(unew,per)), CapUCostPerIter(unew,per,iterAlias) + StatsUPerIter(unew,'HeatMargPrice',per,iterAlias) * HeatGenUIter(unew,per,iterAlias));

    if (HeatAll GT card(unew)*tiny,
      HeatCostNewIter(per,iterAlias) = CostAll / HeatAll;
      HeatCapCostNewIter(per,iterAlias)  = CapCostAll  / HeatAll;
      HeatMargCostNewIter(per,iterAlias) = MargCostAll / HeatAll;
    );
  );
);

# Subst. af nul-værdier med 'tiny' burde være overflødigt pga. squeeze=N, men det fungerer ikke med squeeze.
loop (unew,
  loop (per $OnUPer(unew,per),
    loop (iterAlias $(ord(iterAlias) GE 2 AND ord(iterAlias) LE MasterIter),
      if (HeatCostUIter(unew,per,iterAlias)    EQ 0.0, HeatCostUIter(unew,per,iterAlias)    = tiny; ); 
      if (MasCapActualIter(unew,per,iterAlias) EQ 0.0, MasCapActualIter(unew,per,iterAlias) = tiny; );
      if (CapUCostPerIter(unew,per,iterAlias)  EQ 0.0, CapUCostPerIter(unew,per,iterAlias)  = tiny; );
      if (CapUCostPerIter(unew,per,iterAlias)  EQ 0.0, CapUCostPerIter(unew,per,iterAlias)  = tiny; );
      if (CapUIter(unew,per,iterAlias)         EQ 0.0, CapUIter(unew,per,iterAlias)         = tiny; );
      if (dCapUOfzIter(unew,per,iterAlias)     EQ 0.0, dCapUOfzIter(unew,per,iterAlias)     = tiny; );
    );
  );
);



# Transmission stats.
HeatSentIter(tr,per,iter)  = StatsTPerIter(tr,'QSent',   per,optIter);
HeatLostIter(tr,per,iter)  = StatsTPerIter(tr,'QLost',   per,optIter);
CostPumpIter(tr,per,iter)  = StatsTPerIter(tr,'CostPump',per,optIter);

* Udtræk nøgletal for de optimale kapaciteter.
IterLast = ord(iter);
loop (iterAlias $(optIter(iterAlias)), IterOptim = ord(iterAlias));


if (DoPruneStatsMecU,
  # Nulstil alle elementer i StatsMecUPerIter, som ikke tilhører den hidtil optimale hhv. nuværende master-iteration.
  loop (iterAlias $(ord(iterAlias) NE IterOptim AND ord(iterAlias) LT IterLast),
    tmp = ord(iterAlias);
    display "PRUNING af StatsMecUPerIter for iterAlias, IterOptim, IterLast", tmp, IterOptim, IterLast;
    StatsMecUPerIter(uall,topicMecU,moyr,perA,iterAlias) = 0;
  );
);


AlfaOptim                  = AlfaIter(optIter);
NPVOptim                   = NPVBestIter(optIter);
MasObjOptimAbs             = MasObjIter(optIter);
MasObjOptimRel             = abs(MasObjIter(optIter) / NPVIter(iter));
ConvergenceCodeOptim       = ConvergenceCode(optIter);

MargObjOptim(per)          = PerMargObj(per,optIter);
HeatGenNewOptim(per)       = HeatGenNewIter(per,optIter);
HeatGenAllOptim(per)       = HeatGenAllIter(per,optIter);
CapUCostOptim(upr,per)     = CapUCostPerIter(upr,per,optIter);
                           
HeatMargCostUOptim(upr,per) = HeatMargCostUIter(upr,per,optIter);
HeatCapCostUOptim(upr,per)  = HeatCapCostUIter(upr,per,optIter);
HeatCostUOptim(upr,per)     = HeatCostUIter(upr,per,optIter);

HeatMargCostNewOptim(per)  = HeatMargCostNewIter(per,optIter); 
HeatCapCostNewOptim(per)   = HeatCapCostNewIter(per,optIter); 
HeatCostNewOptim(per)      = HeatCostNewIter(per,optIter);

HeatMargCostAllOptim(per)  = HeatMargCostAllIter(per,optIter); 
HeatCapCostAllOptim(per)   = HeatCapCostAllIter(per,optIter); 
HeatCostAllOptim(per)      = HeatCostAllIter(per,optIter); 

HeatVentedOptim(per)       = HeatVentedIter(per,optIter);
HeatSentOptim(per)         = sum(tr $OnTransGlobal(tr), HeatSentIter(tr,per,optIter));

#--- TotalDbElWindOptim(per)    = StatsWindPerIter('TotalDbElWind',per,optIter);
#--- TotalPWindHPOptim(per)     = StatsWindPerIter('TotalPWindHP',per,optIter);
#--- TotalPWindActualOptim(per) = StatsWindPerIter('TotalPWindActual',per,optIter);

CapUOptim(unew,per)         = max(tiny, MasCapActualIter(unew,per,optIter))$OnUPer(unew,per);
dCapUOptim(unew,per)         = max(tiny, dCapUIter(unew,per,optIter)) $OnUPer(unew,per);
NProjUOptim(unew,per)        = NProjUIter(unew,optIter) $OnUPer(unew,per);

NProjNetOptim(net,per)       = NProjNetIter(net,optIter) $OnNetGlobal(net);

FLHOptim(upr,per)            = FLHIter(upr,per,optIter)$OnUPer(upr,per);
OperHoursOptim(upr,per)      = OperHoursIter(upr,per,optIter)$OnUPer(upr,per);
PowInUOptim(upr,per)         = PowInUIter(upr,per,optIter) $OnUPer(upr,per);
FuelQtysOptim(upr,per)       = FuelQtysIter(upr,per,optIter)$OnUPer(upr,per);
CO2QtyPhysOptim(upr,per)     = CO2QtyPhysIter(upr,per,optIter) $OnUPer(upr,per);
CO2QtyRegulOptim(upr,per)    = CO2QtyRegulIter(upr,per,optIter) $OnUPer(upr,per);
PowerOptim(upr,per)          = PowerUIter(upr,per,optIter)$OnUPer(upr,per);
ElEgbrugOptim(upr,per)       = StatsUPerIter(upr,'ElEgbrug',per,optIter);
HeatGenUOptim(upr,per)       = HeatGenUIter(upr,per,optIter)  $OnUPer(upr,per);
HeatCostUOptim(upr,per)      = HeatCostUIter(upr,per,optIter) $OnUPer(upr,per); 

TaxProdUOptim(per,tax,upr)   = StatsTaxPerIter(upr,tax,per,optIter);


CO2QtyFuelOptim('phys', f,per) = StatsFuelPerIter(f,'CO2QtyPhys', per,optIter);
CO2QtyFuelOptim('regul',f,per) = StatsFuelPerIter(f,'CO2QtyRegul',per,optIter);

# TODO Husk også at overføre stats opsamlet i periodekørslerne.

# Set topicMasOvwPer      'Master overview topics for periods'    / MargObjOptim, HeatGenNewOptim, HeatGenAllOptim, HeatVentedOptim, 
#                                                                   HeatMargCostAllOptim, HeatCapCostAllOptim, HeatMargCostNewOptim, HeatCapCostNewOptim, 
#                                                                   HeatCostAllOptim, HeatCostNewOptim, HeatSentOptim /;
# Set topicMasOvwUNew     'Master overview topics for units unew' / CapUOptim /; 
# Set topicMasOvwU        'Master overview topics for units u'    / HeatCapCostUOptim, HeatMargCostUOptim, HeatCostUOptim, HeatGenUOptim, FLHOptim, PowInUOptim, OperHoursOptim, 
#                                                                   FuelQtysOptim, CO2QtyPhysOptim, CO2QtyRegulOptim, PowerOptim, ElEgbrugOptim  /; 
# Set topicMasOvwT        'Master overview topics for T-lines'    / HeatSent, HeatLost,CostPump /; 
# Set topicMasOvwFuel     'Master overview topics for periods'    / CO2QtyPhys, CO2QtyRegul /;

# Parameter StatsMasOvwPer(perA,topicMasOvwPer)          'Master overview stats for period aggregates';
# Parameter StatsMasOvwUNew(perA,topicMasOvwUNew,unew)   'Master overview stats for units';
# Parameter StatsMasOvwU(perA,topicMasOvwU,u)            'Master overview stats for units';
# Parameter StatsMasOvwTax(perA,tax,upr)                 'Master overview stats for taxes';
# Parameter StatsMasOvwUnewIter(perA,iter,topicMasOvwUNew,unew)   'Master overview stats for new units';

# Stats for net. -------------------------------------------------------------
loop (net $OnNetGlobal(net),
  StatsMasOvwNet(per,'QDemandAnnual',net) = QDemandAnnualPer(net,per);
  StatsMasOvwNet(per,'QDemandPeak',net)   = QDemandPeakYr(net,per);
  StatsMasOvwNet(per,'QDemandAvg',net)    = QDemandAvgPer(net,per);
  StatsMasOvwNet(per,'NProjNet',net)      = NProjNetOptim(net,per);
  StatsMasOvwNet(per,'CapUExcess',net)    = ExcessCapUIter(net,per,optIter);
);

# Stats på tværs af net og anlæg. -------------------------------------------------------------
StatsMasOvwPer(per,'MargObjOptim')         = ifthen (MargObjOptim(per) EQ 0.0, tiny, MargObjOptim(per));

StatsMasOvwPer(per,'HeatMargCostAllOptim') = HeatMargCostAllOptim(per);
StatsMasOvwPer(per,'HeatCapCostAllOptim')  = HeatCapCostAllOptim(per);

StatsMasOvwPer(per,'HeatMargCostNewOptim') = HeatMargCostNewOptim(per);
StatsMasOvwPer(per,'HeatCapCostNewOptim')  = HeatCapCostNewOptim(per);

StatsMasOvwPer(per,'HeatCostAllOptim')     = HeatCostAllOptim(per);
StatsMasOvwPer(per,'HeatCostNewOptim')     = HeatCostNewOptim(per);

StatsMasOvwPer(per,'HeatGenAllOptim')      = HeatGenAllOptim(per);
StatsMasOvwPer(per,'HeatGenNewOptim')      = HeatGenNewOptim(per);

StatsMasOvwPer(per,'HeatVentedOptim')      = HeatVentedOptim(per);
StatsMasOvwPer(per,'HeatSentOptim')        = HeatSentOptim(per);

# Stats for nye anlæg. -------------------------------------------------------------
StatsMasOvwUNew(per,'CapU',       unew) = max(tiny, CapUOptim(unew,per)) $OnUPer(unew,per);
StatsMasOvwUNew(per,'dCapU',      unew) = max(tiny, dCapUOptim(unew,per)) $OnUPer(unew,per);
StatsMasOvwUNew(per,'NProjU',     unew) = max(tiny, NProjUOptim(unew,per)) $OnUPer(unew,per);
StatsMasOvwUNew(per,'bOnInvestU', unew) = max(tiny, bOnInvestUIter(unew,per,optIter)) $OnUPer(unew,per);

StatsMasOvwUnewIter(per,iter,'CapU',       unew) = max(tiny, MasCapActualIter(unew,per,iter)) $OnUPer(unew,per);
StatsMasOvwUnewIter(per,iter,'dCapU',      unew) = ifthen (dCapUIter(unew,per,iter)    EQ 0.0, tiny, dCapUIter(unew,per,iter)) $OnUPer(unew,per);
StatsMasOvwUnewIter(per,iter,'dCapUofz',   unew) = ifthen (dCapUOfzIter(unew,per,iter) EQ 0.0, tiny, dCapUOfzIter(unew,per,iter)) $OnUPer(unew,per);
StatsMasOvwUnewIter(per,iter,'NProjU',     unew) = max(tiny, NProjUIter(unew,iter)) $OnUPer(unew,per);
StatsMasOvwUnewIter(per,iter,'bOnInvestU', unew) = max(tiny, bOnInvestUIter(unew,per,iter)) $OnUPer(unew,per);

# Stats for alle anlæg. -------------------------------------------------------------

# Set topicMasOvwU        'Master overview topics for units u'    
#                 / CapUCostOptim, HeatCapCostUOptim, HeatMargCostUOptim, HeatCostUOptim, HeatGenUOptim, FLHOptim, PowInUOptim, OperHoursOptim, 
#                   FuelQtysOptim, CO2QtyPhysOptim, CO2QtyRegulOptim, PowerOptim, ElEgbrugOptim  /; 

StatsMasOvwU(per,'CapUCost',       upr) = CapUCostOptim(upr,per);
StatsMasOvwU(per,'HeatCapCostU',   upr) = HeatCapCostUOptim(upr,per);
StatsMasOvwU(per,'HeatMargCostU',  upr) = HeatMargCostUOptim(upr,per);
StatsMasOvwU(per,'HeatCostU',      upr) = HeatCostUOptim(upr,per);
StatsMasOvwU(per,'HeatGenU',       upr) = HeatGenUOptim(upr,per);
StatsMasOvwU(per,'FLH',            upr) = FLHOptim(upr,per);
StatsMasOvwU(per,'OperHours',      upr) = OperHoursOptim(upr,per);
StatsMasOvwU(per,'PowInU',         upr) = PowInUOptim(upr,per);
StatsMasOvwU(per,'FuelQtys',       upr) = FuelQtysOptim(upr,per);
StatsMasOvwU(per,'CO2QtyPhys',     upr) = CO2QtyPhysOptim(upr,per);
StatsMasOvwU(per,'CO2QtyRegul',    upr) = CO2QtyRegulOptim(upr,per);
StatsMasOvwU(per,'Power',          upr) = PowerOptim(upr,per);
StatsMasOvwU(per,'ElEgbrug',       upr) = ElEgbrugOptim(upr,per);

# Stats for afgifter og tilskud. -------------------------------------------------------------
StatsMasOvwTax(per,tax,upr)  = TaxProdUOptim(per,tax,upr);

# Stats for T-ledninger. -------------------------------------------------------------
StatsMasOvwT(per,'HeatSent',tr) = StatsTPerIter(tr,'QSent',   per,optIter) $OnTransGlobal(tr);
StatsMasOvwT(per,'HeatLost',tr) = StatsTPerIter(tr,'QLost',   per,optIter) $OnTransGlobal(tr);
StatsMasOvwT(per,'CostPump',tr) = StatsTPerIter(tr,'CostPump',per,optIter) $OnTransGlobal(tr);

# Stats for drivmidler. -------------------------------------------------------------
StatsMasOvwFuel(per,'CO2QtyPhys', f) $OnFuel(f) = StatsFuelPerIter(f,'CO2QtyPhys', per,optIter);
StatsMasOvwFuel(per,'CO2QtyRegul',f) $OnFuel(f) = StatsFuelPerIter(f,'CO2QtyRegul',per,optIter);


RowCountOvwPer      = sum(per, sum(topicMasOvwPer,                                  1 $(StatsMasOvwPer (per,topicMasOvwPer))              ));
RowCountOvwNet      = sum(per, sum(topicMasOvwNet,  sum(net,  1 $(OnNetGlobal(net)  AND StatsMasOvwNet (per,topicMasOvwNet, net)) NE 0.0  )));
RowCountOvwU        = sum(per, sum(topicMasOvwU,    sum(u,    1 $(OnUGlobal(u)      AND StatsMasOvwU   (per,topicMasOvwU,   u  )) NE 0.0  )));
RowCountOvwUnew     = sum(per, sum(topicMasOvwUnew, sum(unew, 1 $(OnUGlobal(unew)   AND StatsMasOvwUnew(per,topicMasOvwUNew,unew))        )));
RowCountOvwTax      = sum(per, sum(tax,             sum(upr,  1 $(OnUGlobal(upr)    AND StatsMasOvwTax (per,tax,upr))                     )));
RowCountOvwT        = sum(per, sum(topicMasOvwT,    sum(tr,   1 $(OnTransGlobal(tr) AND StatsMasOvwT   (per,topicMasOvwT,   tr))          )));
RowCountOvwFuel     = sum(per, sum(topicMasOvwFuel, sum(f,    1 $(OnFuel(f)         AND StatsMasOvwFuel(per,topicMasOvwFuel,f))           )));

RowCountOvwUnewIter = sum(per, 
                        sum(iterAlias $(ord(iterAlias) GE 2 AND ord(iterAlias) LE ord(iter)), 
                          sum(topicMasOvwUnew, 
                            sum(unew, 1 $(OnUGlobal(unew)   AND StatsMasOvwUnewIter(per,iter,topicMasOvwUNew,unew)) ))));

TimeOfWritingMasterResults = jnow;

If ((WriteMasterOutput AND MasterIterMax GE 2) OR (%oDumpMasterStatsToExcel% NE 0 AND Stop) OR (BreakRun GT 0),

execute_unload 'MECMasterOutput.gdx',
net, tr, u, upr, uq, unew, uexist, unewuq, unewhp, ucool, hp, kv, vak, perA, per, iterAlias, scenMas, scyr, actSc, actScyr,    #remove , urgk
Actor, produExt, infeasDir, tax,
topicSolver, topicT, topicU, topicVak, topicMasOvwPer, topicMasOvwNet, topicMasOvwT, topicMasOvwU, topicMasOvwUNew, topicMasOvwFuel,
ActScen, QDemandPeakNom, OnNetGlobal, OnUGlobal, DataTransm, CapFacN1Res, Capex,
Periods, OnNetNomPer, OnTransPer, DirTransPer, OnUNomPer, OnRevisionPer, QDemandPeakPer, 
CapUReservePer, dCapUInitPer, dCapUMaxInitper, CapUInitPer, CapUMinPer, CapUMaxPer, CapUExistper, DeprecExistPer,
YearScenActual,
MasterIter, zMaster,
PeriodFirst, PeriodLast, PeriodCount, TimeOfWritingMasterResults, SaveTimestamp, ScenarioID,
AlfaVersion, AlfaReducIndiv, AlfaIter, AlfaIndi, AlfaIndiIter, MasObjIter, MasObjMinTotal,
NPVIterCopy, CapUCostPerIter, CapUCostPerIter, CapUCostSumPerIter, PerMargObj,
coef0, coef1, coef2,
dCapUOfzIter, dMargObjUIter, GradUMargIter, GradUMargAggrIter, GradCapUIter, GradUIter, GradUAggrIter, GradURelIter,
CapUExcess, ExcessCapUIter, dCapUOfzLenIter, 
CapUIter, MasCapActualIter, MasCapU, MasdCapU, MasCapOfzIter, NPVIter, dNPVIter, MasterBestIter, MonotonyExistsIter,
FLHIter, OperHoursIter, PowerUIter, PowerGenUIter, FuelQtysIter,
HeatMargCostUIter, HeatCapCostUIter, HeatCostUIter, HeatCostNewIter, HeatCostAllIter, 
HeatGenUIter, HeatGenNewIter, HeatGenAllIter,
HeatVentedIter, HeatVentedOptim,
HeatSentIter, HeatLostIter, CostPumpIter,
TotalDbElWindOptim, TotalPWindHPOptim, TotalPWindActualOptim,
IterLast, IterOptim, ConvergenceCodeOptim, NPVOptim, AlfaOptim, MasObjOptimAbs, MasObjOptimRel, MargObjOptim, CapUOptim, CapUCostOptim,
HeatMargCostUOptim, HeatCapCostUOptim, HeatCostUOptim, HeatCostNewOptim, HeatCostAllOptim, 
HeatGenUOptim, HeatGenNewOptim, HeatGenAllOptim,
OperHoursOptim, FLHOptim,
ConvergenceCode, PowInUIter, FuelQtysOptim, CO2QtyPhysOptim, CO2QtyRegulOptim, CO2QtyFuelOptim, PowerOptim, ElEgbrugOptim, QDemandAnnualSum,
StatsUPerIter, StatsVakPerIter, StatsSolverPerIter, StatsFuelPerIter, StatsOtherPerIter, cpStatsMonthPerIter,
StatsMasOvwPer, StatsMasOvwNet, StatsMasOvwU, StatsMasOvwUNew, StatsMasOvwUnewIter, StatsMasOvwTax, StatsMasOvwT, StatsMasOvwFuel,
RowCountOvwPer, RowCountOvwNet, RowCountOvwU, RowCountOvwUnew, RowCountOvwUnewIter, RowCountOvwTax, RowCountOvwT, RowCountOvwFuel,
trActive, uActive, unewActive, fActive, setOnNetGlobal, setOnUGlobal;   #---  vakActive, 

$OnText
* NOTE on using GDXXRW to export GDX results to Excel. McCarl
* Any item to be exported must be unloaded (saved) to a gdx file using the execute_unload stmt (see above).
* 1: By default an item is assumed to be a table (2D) and the first index being the row index.
* 2: By vectors (1D) do specify cdim=0 to obtain a column vector, otherwise a row vector is obtained.
* 3: GDXXRW args options cdim and rdim control how a multi-dim item is written to the Excel sheet:
*    a: cdim is the no. of dimensions going into columns.
*    b: rdim is the no. of dimensions going into rows.
*    c: The dimension of the item must equal cdim + rdim.
* 4: Column indices are the rightmost indices of the item (indices are set names).
* 5: The name of the item is not written as a part of export stmt eg var=<varname> rng=<sheetname>!<topleft cell> cdim=... rdim=...
* 6: When cdim=0 the range will hold no header row ie. the range should be addressed to begin one row lower than multidim. items.
* 7: Formulas cannot be written. A text starting with '=' raises a 'Parameter missing for option' error.
* See details and examples in the McCarl article "Rearranging rows and columns" in the GAMS Documentation Center.
$OffText


$onecho > MECMasterOutput.txt
filter=0

*begin Individuelle datårk

* INPUT SCENARIER
par=ActScen squeeze=N                rng=ActScen!A9             cdim=0 rdim=1
text="ActScen"                       rng=ActScen!A8:A8
par=QDemandPeakNom squeeze=N         rng=ActScen!D9             cdim=0 rdim=1
text="QDemandPeakNom"                rng=ActScen!D8:D8
par=OnNetGlobal squeeze=N            rng=ActScen!G9             cdim=0 rdim=1
text="OnNetGlobal"                   rng=ActScen!G8:G8
par=OnUGlobal squeeze=N              rng=ActScen!J9             cdim=0 rdim=1
text="OnUGlobal"                     rng=ActScen!J8:J8
par=DataTransm squeeze=N             rng=ActScen!M9             cdim=0 rdim=2
text="DataTransm"                    rng=ActScen!M8:M8
par=CapFacN1Res squeeze=N            rng=ActScen!Q9             cdim=0 rdim=1
text="CapFacN1Res"                   rng=ActScen!Q8:Q8
par=Capex squeeze=N                  rng=ActScen!T9             cdim=0 rdim=2
text="Capex"                         rng=ActScen!T8:T8

* Periodescenarie
par=Periods squeeze=N                rng=PeriodScen!A9          cdim=1 rdim=1
text="PeriodScen"                    rng=PeriodScen!A9:A9
par=OnNetNomPer squeeze=N            rng=PeriodScen!A25         cdim=1 rdim=1
text="OnNetNomPer"                   rng=PeriodScen!A25:A25
par=OnTransPer squeeze=N             rng=PeriodScen!A40         cdim=1 rdim=1
text="OnTransPer"                    rng=PeriodScen!A40:A40
par=DirTransPer squeeze=N            rng=PeriodScen!A50         cdim=1 rdim=1
text="DirTransPer"                   rng=PeriodScen!A50:A50     
par=OnUNomPer squeeze=N              rng=PeriodScen!A60         cdim=1 rdim=1
text="OnUNomPer"                     rng=PeriodScen!A60:A60    
par=OnRevisionPer squeeze=N          rng=PeriodScen!A130        cdim=1 rdim=1
text="OnRevisionPer"                 rng=PeriodScen!A130:A130  
par=QDemandPeakPer squeeze=N         rng=PeriodScen!A140        cdim=1 rdim=1
text="QDemandPeakPer"                rng=PeriodScen!A140:A140  
par=CapUReservePer squeeze=N         rng=PeriodScen!A155        cdim=1 rdim=1
text="CapUReservePer"                rng=PeriodScen!A155:A155  
par=dCapUInitPer squeeze=N           rng=PeriodScen!A170        cdim=1 rdim=1
text="dCapUInitPer"                  rng=PeriodScen!A170:A170  
par=dCapUMaxInitper squeeze=N        rng=PeriodScen!A190        cdim=1 rdim=1
text="dCapUMaxInitper"               rng=PeriodScen!A190:A190  
par=CapUInitPer squeeze=N            rng=PeriodScen!A205        cdim=1 rdim=1
text="CapUInitPer"                   rng=PeriodScen!A205:A205  
par=CapUMinPer squeeze=N             rng=PeriodScen!A221        cdim=1 rdim=1
text="CapUMinPer"                    rng=PeriodScen!A220:A220  
par=CapUMaxPer squeeze=N             rng=PeriodScen!A220        cdim=1 rdim=1
text="CapUMaxPer"                    rng=PeriodScen!A235:A235  
par=CapUExistper squeeze=N           rng=PeriodScen!A235        cdim=1 rdim=1
text="CapUExistper"                  rng=PeriodScen!A250:A250  
par=DeprecExistPer squeeze=N         rng=PeriodScen!A305        cdim=1 rdim=1
text="DeprecExistPer"                rng=PeriodScen!A305:A305

* årsscenarie
par=YearScenActual                   rng=YearScen!A9            cdim=1 rdim=1
text="YearScenActual"                rng=YearScen!A9:A9

* RESULTATER
par=ConvergenceCode                  rng=NPVIter!B5             cdim=1 rdim=0
text="ConvergenceCode"               rng=NPVIter!A5:A5
par=NPVIterCopy                      rng=NPVIter!B8             cdim=1 rdim=0
text="NPVIter"                       rng=NPVIter!A8:A8
par=dNPVIter                         rng=NPVIter!B11            cdim=1 rdim=0
text="dNPVIter"                      rng=NPVIter!A11:A11
par=MasObjIter squeeze=N             rng=NPVIter!B14            cdim=1 rdim=0
text="MasObjIter"                    rng=NPVIter!A14:A14
par=AlfaIter                         rng=NPVIter!A17            cdim=1 rdim=0
text="AlfaIter"                      rng=NPVIter!A17:A17
par=dCapUOfzLenIter       squeeze=N  rng=NPVIter!A20            cdim=1 rdim=1
text="dCapUOfzLenIter"               rng=NPVIter!A20:A20
par=CapUCostSumPerIter    squeeze=N  rng=NPVIter!A45            cdim=1 rdim=1
text="CapUCostSumPerIter"            rng=NPVIter!A45:A45
par=PerMargObj squeeze=N             rng=NPVIter!A70            cdim=1 rdim=1
text="PerMargObj"                    rng=NPVIter!A70:A70

* CapU iter
par=AlfaIter                         rng=CapUIter!B3             cdim=1 rdim=0
text="AlfaIter"                      rng=CapUIter!A3:A3
par=AlfaIndiIter                     rng=CapUIter!A15            cdim=2 rdim=1
text="AlfaIndiIter"                  rng=CapUIter!A15:A15
par=CapUIter                         rng=CapUIter!A35            cdim=2 rdim=1
text="CapUIter"                      rng=CapUIter!A35:A35
par=dCapUOfzIter                     rng=CapUIter!A55            cdim=2 rdim=1
text="dCapUOfzIter"                  rng=CapUIter!A55:A55
par=ExcessCapUIter                   rng=CapUIter!A75            cdim=2 rdim=1
text="ExcessCapUIter"                rng=CapUIter!A75:A75
par=dMargObjUIter                    rng=CapUIter!A95            cdim=1 rdim=1
text="dMargObjUIter"                 rng=CapUIter!A95:A95
par=GradUAggrIter                    rng=CapUIter!A115           cdim=2 rdim=1
text="GradUAggrIter"                 rng=CapUIter!A115:A115
par=GradUIter                        rng=CapUIter!A135           cdim=2 rdim=1
text="GradUIter"                     rng=CapUIter!A135:A135
par=GradCapUIter                     rng=CapUIter!A155           cdim=2 rdim=1
text="GradCapUIter"                  rng=CapUIter!A155:A155
par=GradUMargIter                    rng=CapUIter!A175           cdim=2 rdim=1
text="GradUMargIter"                 rng=CapUIter!A175:A175
par=GradUMargAggrIter                rng=CapUIter!A195           cdim=2 rdim=1
text="GradUMargAggrIter"             rng=CapUIter!A195:A195

* Drifts- og fuldlasttimer
par=FLHIter squeeze=N                rng=OperHoursIter!A9       cdim=2 rdim=1
text="FLHIter"                       rng=OperHoursIter!A9
par=OperHoursIter squeeze=N          rng=OperHoursIter!A69      cdim=2 rdim=1
text="OperHoursIter"                 rng=OperHoursIter!A69

* HeatGenIter
par=HeatGenUIter squeeze=N           rng=HeatGenIter!A9         cdim=2 rdim=1
text="HeatGenUIter"                  rng=HeatGenIter!A9
par=HeatGenNewIter squeeze=N         rng=HeatGenIter!A77        cdim=1 rdim=1
text="HeatGenNewIter"                rng=HeatGenIter!A77
par=HeatGenAllIter squeeze=N         rng=HeatGenIter!A100       cdim=1 rdim=1
text="HeatGenAllIter"                rng=HeatGenIter!A100

* PowerGenUIter
par=PowerGenUIter squeeze=N          rng=PowerGenIter!A9        cdim=2 rdim=1
text="PowerGenUIter"                 rng=PowerGenIter!A9

* HeatCostIter
par=HeatCostUIter squeeze=N          rng=HeatCostIter!A9        cdim=2 rdim=1
text="HeatCostUIter"                 rng=HeatCostIter!A9
par=HeatCostNewIter squeeze=N        rng=HeatCostIter!A77       cdim=1 rdim=1
text="HeatCostNewIter"               rng=HeatCostIter!A77
par=HeatCostAllIter squeeze=N        rng=HeatCostIter!A100      cdim=1 rdim=1
text="HeatCostAllIter"               rng=HeatCostIter!A100

* Statistikker
par=StatsUPerIter squeeze=N          rng=StatsUPerIter!A9        cdim=2 rdim=2
text="StatsUPerIter"                 rng=StatsUPerIter!A9
par=StatsVakPerIter squeeze=N        rng=StatsVakPerIter!A9      cdim=2 rdim=2
text="StatsVakPerIter"               rng=StatsVakPerIter!A9
par=StatsOtherPerIter squeeze=N      rng=StatsOtherPerIter!A9    cdim=2 rdim=2
text="StatsOtherPerIter"             rng=StatsOtherPerIter!A9
par=StatsSolverPerIter   squeeze=N   rng=StatsSolverPerIter!B50  cdim=0 rdim=3
text="StatsSolverPerIter"            rng=StatsSolverPerIter!B49


* Period records:
par=RowCountOvwPer      squeeze=N  rng=dPer!C2            
par=StatsMasOvwPer      squeeze=N  rng=dPer!D11         cdim=0 rdim=2
text="StatsMasOvwPer"   squeeze=N  rng=dPer!C10
set=topicMasOvwPer      squeeze=N  rng=dPer!N11        cdim=0 rdim=1
text="topicMasOvwPer"   squeeze=N  rng=dPer!N10           

* Net records: net
par=RowCountOvwNet      squeeze=N  rng=dNet!C2            
par=StatsMasOvwNet      squeeze=N  rng=dNet!D11        cdim=0 rdim=3
text="StatsMasOvwNet"   squeeze=N  rng=dNet!C10     
set=net                 squeeze=N  rng=dNet!J11        cdim=0 rdim=1
text="All nets"         squeeze=N  rng=dNet!J10           
set=setOnNetGlobal      squeeze=N  rng=dNet!K11        cdim=0 rdim=1
text="OnNetGlobal"      squeeze=N  rng=dNet!K10           
set=topicMasOvwNet      squeeze=N  rng=dNet!N11        cdim=0 rdim=1
text="topicMasOvwNet"   squeeze=N  rng=dNet!N10           

* Unit records: u
par=RowCountOvwU        squeeze=N  rng=dU!C2            
par=StatsMasOvwU        squeeze=N  rng=dU!D11           cdim=0 rdim=3
text="StatsMasOvwU"     squeeze=N  rng=dU!C10
set=setOnNetGlobal      squeeze=N  rng=dU!J11           cdim=0 rdim=1
text="OnNetGlobal"      squeeze=N  rng=dU!J10              
set=setOnUGlobal        squeeze=N  rng=dU!K11           cdim=0 rdim=1
text="OnUGlobal"        squeeze=N  rng=dU!K10              
set=uActive             squeeze=N  rng=dU!L11           cdim=0 rdim=1
text="uActive"          squeeze=N  rng=dU!L10           
set=topicMasOvwU        squeeze=N  rng=dU!N11           cdim=0 rdim=1
text="topicMasOvwU"     squeeze=N  rng=dU!N10           

* New unit records: unew
par=RowCountOvwUnew     squeeze=N  rng=dUnew!C2            
par=StatsMasOvwUnew     squeeze=N  rng=dUnew!D11        cdim=0 rdim=3
text="StatsMasOvwUnew"  squeeze=N  rng=dUnew!C10
set=setOnNetGlobal      squeeze=N  rng=dUnew!J11        cdim=0 rdim=1
text="OnNetGlobal"      squeeze=N  rng=dUnew!J10           
set=setOnUGlobal        squeeze=N  rng=dUnew!K11        cdim=0 rdim=1
text="OnUGlobal"        squeeze=N  rng=dUnew!K10           
set=uActive             squeeze=N  rng=dUnew!L11        cdim=0 rdim=1
text="uActive"          squeeze=N  rng=dUnew!L10           
set=unewActive          squeeze=N  rng=dUnew!M11        cdim=0 rdim=1
text="unewActive"       squeeze=N  rng=dUnew!M10           
set=topicMasOvwUNew     squeeze=N  rng=dUnew!N11        cdim=0 rdim=1
text="topicMasOvwUNew"  squeeze=N  rng=dUnew!N10           

* New unit records: unew, iter
par=RowCountOvwUnewIter     squeeze=N  rng=dUnewIter!C2            
par=StatsMasOvwUnewIter     squeeze=N  rng=dUnewIter!D11        cdim=0 rdim=4
text="StatsMasOvwUnewIter"  squeeze=N  rng=dUnewIter!C10
set=setOnNetGlobal          squeeze=N  rng=dUnewIter!J11        cdim=0 rdim=1
text="OnNetGlobal"          squeeze=N  rng=dUnewIter!J10           
set=setOnUGlobal            squeeze=N  rng=dUnewIter!K11        cdim=0 rdim=1
text="OnUGlobal"            squeeze=N  rng=dUnewIter!K10           
set=uActive                 squeeze=N  rng=dUnewIter!L11        cdim=0 rdim=1
text="uActive"              squeeze=N  rng=dUnewIter!L10           
set=unewActive              squeeze=N  rng=dUnewIter!M11        cdim=0 rdim=1
text="unewActive"           squeeze=N  rng=dUnewIter!M10           
set=topicMasOvwUNew         squeeze=N  rng=dUnewIter!N11        cdim=0 rdim=1
text="topicMasOvwUNew"      squeeze=N  rng=dUnewIter!N10           

* Transmission records: tr
par=RowCountOvwT        squeeze=N  rng=dT!C2            
par=StatsMasOvwT        squeeze=N  rng=dT!D11           cdim=0 rdim=3
text="StatsMasOvwT"     squeeze=N  rng=dT!C10
set=trActive            squeeze=N  rng=dT!J11           cdim=0 rdim=1
text="trActive"         squeeze=N  rng=dT!J10           
set=topicMasOvwT        squeeze=N  rng=dT!N11           cdim=0 rdim=1
text="topicMasOvwT"     squeeze=N  rng=dT!N10           

* Fuel records
par=RowCountOvwFuel     squeeze=N  rng=dF!C2            
par=StatsMasOvwFuel     squeeze=N  rng=dF!D11           cdim=0 rdim=3
text="StatsMasOvwFuel"  squeeze=N  rng=dF!C10
set=fActive             squeeze=N  rng=dF!J11           cdim=0 rdim=1
text="fActive"          squeeze=N  rng=dF!J10           
set=topicMasOvwFuel     squeeze=N  rng=dF!N11           cdim=0 rdim=1
text="topicMasOvwFuel"  squeeze=N  rng=dF!N10           

* Tax records
par=RowCountOvwTax      squeeze=N  rng=dTax!C2            
par=StatsMasOvwTax      squeeze=N  rng=dTax!D11         cdim=0 rdim=3
text="StatsMasOvwTax"   squeeze=N  rng=dTax!C10
set=tax                 squeeze=N  rng=dTax!J11         cdim=0 rdim=1
text="tax"              squeeze=N  rng=dTax!J10
set=setOnUGlobal        squeeze=N  rng=dTax!K11         cdim=0 rdim=1
text="OnUGlobal"        squeeze=N  rng=dTax!K10           
set=uActive             squeeze=N  rng=dTax!L11         cdim=0 rdim=1
text="uActive"          squeeze=N  rng=dTax!L10           

*end   Individuelle datårk

* Overview as the last sheet to be written hence the actual sheet when opening Excel file.

*begin OverView Inputs
text="TimeOfWritingMasterResults"   rng=OverView!A1:A1
par=TimeOfWritingMasterResults      rng=OverView!E1:E1
par=SaveTimestamp                   rng=OverView!F1:F1
text="Actual Scenario code"         rng=Overview!A3:A3
set=actSc                           rng=Overview!B3:B3
text="PeriodFirst"                  rng=Overview!A4:A4
par=PeriodFirst                     rng=Overview!B4:B4
text="PeriodLast"                   rng=Overview!A5:A5
par=PeriodLast                      rng=Overview!B5:B5
text="Actual Year Scenario"         rng=Overview!A6:A6
set=actScyr                         rng=Overview!B6:B6
text="Actual Master Scenario"       rng=Overview!A7
par=ActScen    squeeze=N            rng=Overview!A8:B100      cdim=0 rdim=1 

*--- text="QDemandAnnualSum"             rng=Overview!A210
*--- par=QDemandAnnualSum squeeze=N      rng=Overview!A211    cdim=0 rdim=1
*end

*begin OverView Outputs
par=IterLast                  squeeze=N  rng=OverView!F3:F3   cdim=0 rdim=0
text="IterLast"                          rng=OverView!E3:E3
par=IterOptim                 squeeze=N  rng=OverView!F4:F4   cdim=0 rdim=0
text="IterOptim"                         rng=OverView!E4:E4
par=ConvergenceCodeOptim      squeeze=N  rng=OverView!F5:F5   cdim=0 rdim=0
text="ConvergenceCodeOptim"              rng=OverView!E5
par=AlfaVersion               squeeze=N  rng=OverView!F6:F6   cdim=0 rdim=0
text="AlfaVersion"                       rng=OverView!E6:E6
par=AlfaReducIndiv            squeeze=N  rng=OverView!F7:F7   cdim=0 rdim=0
text="AlfaReducIndiv"                    rng=OverView!E7:E7
par=AlfaOptim                 squeeze=N  rng=OverView!F8:F8   cdim=0 rdim=0
text="AlfaOptim"                         rng=OverView!E8:E8
par=NPVOptim                  squeeze=N  rng=OverView!F9:F9   cdim=0 rdim=0
text="NPVOptim"                          rng=OverView!E9:E9
par=MasObjOptimRel            squeeze=N  rng=OverView!F10     cdim=0 rdim=0
text="MasObjOptimRel"                    rng=OverView!E10
par=MasObjOptimAbs            squeeze=N  rng=OverView!F11     cdim=0 rdim=0
text="MasObjOptimAbs"                    rng=OverView!E11
par=MasObjMinTotal            squeeze=N  rng=OverView!F12     cdim=0 rdim=0
text="MasObjMinTotal"                    rng=OverView!E12
par=ScenarioID                squeeze=N  rng=OverView!I2      cdim=0 rdim=0
text="ScenarioID"                        rng=OverView!H2
par=MargObjOptim              squeeze=N  rng=OverView!G22     cdim=1 rdim=0
text="MargObjOptim"                      rng=OverView!E22

*--- par=StatsMasOvwUNew     squeeze=N  rng=OverView!E28     cdim=1 rdim=2
*--- text="StatsMasOvwUNew"             rng=OverView!E28    
*--- par=StatsMasOvwPer      squeeze=N  rng=OverView!F43     cdim=1 rdim=1
*--- text="StatsMasOvwPer"   squeeze=N  rng=OverView!E43     
*--- par=StatsMasOvwT        squeeze=N  rng=OverView!E53     cdim=1 rdim=2
*--- text="StatsMasOvwT"     squeeze=N  rng=OverView!E53     
*--- par=StatsMasOvwU        squeeze=N  rng=OverView!E75     cdim=1 rdim=2
*--- text="StatsMasOvwU"     squeeze=N  rng=OverView!E75     
*--- par=StatsMasOvwU        squeeze=N  rng=RawUOverView!E75     cdim=1 rdim=2
*--- text="StatsMasOvwU"     squeeze=N  rng=OverView!E75     

$offecho

execute "gdxxrw.exe MECMasterOutput.gdx o=MECMasterOutput.xlsm trace=1 @MECMasterOutput.txt";

#DISABLED  GAMS put-facility konflikter subtilt med embedded python.
#DISABLED  # Put an entry into the GAMS log file:
#DISABLED  put gamslog / "Iter= ", MasterIter, ",  NPV= ", NPVIter(iter), "NPVoptim= ", NPVOptim  / ;

# ======================================================================================================================

embeddedCode Python:
  import os
  import shutil
  import datetime
  currentDate = datetime.datetime.today().strftime('%Y-%m-%d %Hh%Mm%Ss')

  actIter = list(gams.get('actIter'))[0]
  perLast = 'per' + str(int( list(gams.get('PeriodLast'))[0] ))

  #--- wkdir = gams.wsWorkingDir  # Does not work.
  wkdir = os.getcwd()
  #--- gams.printLog('wkdir: '+ wkdir)

  pathOldFile = os.path.join(wkdir, r'MECMasterOutput.xlsm')
  pathNewFile = os.path.join(wkdir, f'MECMasterOutput_{actIter}_{perLast}_{str(currentDate)}.xlsm')
  print(f'INFO: SaveMasterStats: {actIter=}, {perLast=},\n {pathOldFile=},\n {pathNewFile=}')
  shutil.copyfile(pathOldFile, pathNewFile)

endEmbeddedCode


# ======================================================================================================================

);