$OnText
Denne GAMS modelfil er beregnet til inkludering ($INCLUDE) i SILK-modellen.
Den udfører rapportering af optimeringsfasen for en given periode, perL, som defineres i modellen.
$OffText

*begin DUMP til Excel output

SalesHeatTotal(net)  = tiny;
SalesPowerTotal(net) = tiny;
SubsidiesTotal(net)  = tiny;
CostMaintTotal(net)  = tiny;
CostStartTotal(net)  = tiny;
CostPowerTotal(net)  = tiny;
CostFuelTotal(net)   = tiny;
CostCO2EtsTotal(net) = tiny;
CostTotal(net)       = tiny;
TaxTotal(net)        = tiny;
TaxEnrTotal(net)     = tiny;
TaxCO2Total(net)     = tiny;
TaxNOxTotal(net)     = tiny;
TaxSOxTotal(net)     = tiny;

SalesHeatTotal(net)   $OnNet(net) = Max(tiny, sum(t,   QSales.L(t)) );
SalesPowerTotal(net)  $OnNet(net) = sum(kv,   sum(t,   TotalElIncome.L(t,kv)));

#--- SubsidiesTotal(net)   $OnNet(net) = Max(tiny, sum(kv,  sum(t, ElTilskud.L(t,kv))) );
SubsidiesTotal(net)   = tiny;

CostTotal(net)        $OnNet(net) = sum(u,    sum(t,   TotalCostU.L(t,u)));
CostMaintTotal(net)   $OnNet(net) = Max(tiny, sum(u,   sum(t, VarDVOmkst.L(t,u))) );
CostStartTotal(net)   $OnNet(net) = Max(tiny, sum(upr, sum(t, StartOmkst.L(t,upr))) );
CostFuelTotal(net)    $OnNet(net) = Max(tiny, sum(upr, sum(t, FuelCost.L(t,upr))) );
CostPowerTotal(net)   $OnNet(net) = Max(tiny, sum(upr, sum(t, ElEgbrugOmkst.L(t,upr))) );
CostCO2EtsTotal(net)  $OnNet(net) = Max(tiny, sum(upr, sum(t, TaxProdU.L(t,upr,'ets'))) );
TaxTotal(net)         $OnNet(net) = Max(tiny, sum(upr, sum(t, sum(tax, TaxProdU.L(t,upr,tax) ) ) ) - CostCO2EtsTotal(net));


#--- TaxEnrTotal(net)        = Max(tiny, sum(upr, sum(t, TaxU.L(t,'enr',upr))) );
#--- TaxCO2Total(net)        = Max(tiny, sum(upr, sum(t, TaxU.L(t,'co2',upr))) );
#--- TaxNOxTotal(net)        = Max(tiny, sum(upr, sum(t, TaxU.L(t,'nox',upr))) );
#--- TaxSOxTotal(net)        = Max(tiny, sum(upr, sum(t, TaxU.L(t,'sox',upr))) );

InfeasTotal(net,InfeasDir)   = Max(tiny, sum(t, StatsInfeas(t,net,InfeasDir)) );

#--- CostTransTotal              = Max(tiny, sum(net, sum(t, QTransOmkst.L(t,net))) );
#--- CostVakTotal                = Max(tiny, sum(vak, sum(t, CostVak.L(t,vak))) );
#--- SharedOpexPerIter(actPer,actIter) = CostVakTotal;

loop (net,
  if (SalesPowerTotal(net) EQ 0.0, SalesPowerTotal(net) = tiny; );
  if (CostTotal(net)       EQ 0.0, CostTotal(net) = tiny; );
  if (CostFuelTotal(net)   EQ 0.0, CostFuelTotal(net) = tiny; );
 );

display SalesHeatTotal, SalesPowerTotal, SubsidiesTotal;
display CostMaintTotal, CostStartTotal, CostFuelTotal, CostPowerTotal, CostCO2EtsTotal, CostTotal, TaxTotal; #--- , CostTransTotal, CostVakTotal;
display TaxEnrTotal, TaxCO2Total, TaxNOxTotal, TaxSOxTotal;
display InfeasTotal;


* Fuldlasttimer og lastprocent.
zNormalized = zSlave.L * PeriodObjScale;
zNormalizedReal = zNormalized + sum(net, sum(t, CostInfeas.L(t,net)));

loop (upr, 
    tmp = sum(t, QF.L(t,upr));
    if (tmp > 0.1, 
        OperHours(upr) = sum(t, BLen(t) * bOn.L(t,upr)); 
    );
);

# Varmeprod. omkostning for alle pånær centrale anlæg.
loop (upr $(OnUGlobal(upr) and NOT kv(upr)),
  if (OperHours(upr) GT 0 AND smax(t, QF.L(t,upr)) > tiny, 
    QMargPrice(upr) = sum(t, TotalCostU.L(t,upr)) / sum(t,QF.L(t,upr));  
  );
);
# Varmeprod. omkostning for KV-anlæg (kv), som er en delmængde af cp, som kendetegnes ved at have elproduktion.
loop (kv $OnUGlobal(kv),
  if (OperHours(kv) GT 0 AND smax(t, QF.L(t,kv)) GT tiny, 
      QMargPrice(kv) = sum(t, [TotalCostU.L(t,kv) - TotalElIncome.L(t,kv)]) / sum(t, QF.L(t,kv)); 
  );
);

loop (upr $(OnUGlobal(upr) and NOT kv(upr)),
  if (OperHours(upr) GT 0 AND smax(t, QF.L(t,upr)) > tiny, 
    QMargPrice_Hourly(t,upr) = TotalCostU.L(t,upr) / max(0.01,QF.L(t,upr));  
  );
);


loop (kv $OnUGlobal(kv),
  if (OperHours(kv) GT 0 AND smax(t, QF.L(t,kv)) GT tiny, 
      QMargPrice_Hourly(t,kv) = [TotalCostU.L(t,kv) - TotalElIncome.L(t,kv)] / max(0.01,QF.L(t,kv)); 
  );
);
display OperHours, QMargPrice; 

$if not errorfree $exit

*begin Beregning af StatsT

StatsT(tr,topicT)     = 0.0;
loop (tr $OnTrans(tr),
  StatsT(tr,'QSent')    = sum(t, QTF.L(t,tr));
  StatsT(tr,'QLost')    = sum(t, QTeLoss.L(t,tr));
  StatsT(tr,'CostPump') = sum(t, CostPump.L(t,tr));
);

*end Beregning af StatsT

*begin Beregning af StatsU

#--- Set topicU     'Prod unit stats' /
#---    FullLoadHours, OperHours, BypassHours, RGKhours,
#---    NStart, CO2QtyPhys, CO2QtyRegul, FF, FuelQty,
#---    FuelConsumed, PowerGen, PowerNet, HeatGen, HeatCool, HeatBypass, HeatRGK,
#---    RGKshare,
#---    ElEgbrug,
#---    HeatMargPrice,
#---    SalesPower, #--- ElTilskud,
#---    CO2Kvote, TotalElIncome,
#---    FuelCost, DVCost, StartCost, ElCost, TotalCost, TotalTax,
#---    EtaPower, EtaHeat, PowInMax, ElSpotIncome,
#---    CapEAllocMWhUp, CapEAllocMWhDown
#---    /;

StatsU(upr,topicU)     = 0.0;
StatsVak(vak,topicVak) = 0.0;

StatsU(upr,'PowInMax') = FinFMax(upr);
StatsU(upr,'EtaPower') = EtaPU(upr) $OnUGlobal(upr);
StatsU(upr,'EtaHeat')  = EtaQU(upr) $OnUGlobal(upr);

* Varmepumpers fuldlasttimer skal opgøres efter varmeproduktion, da deres kapacitet er baseret på varmeoutput.
#--- StatsU(cp,'FullLoadHours') = [sum(t, FF.L(t,cp)) / Max(1, FinFMax(cp))] $OnUGlobal(cp);
#--- StatsU(hp,'FullLoadHours') = [sum(t, QF.L(t,hp)) / Max(1, FinFMax(hp))] $OnUGlobal(hp);

loop (upr $(OnUGlobal(upr)),
  StatsU(upr,'FullLoadHours') = sum(t, FF.L(t,upr)) / Max(1, FinFMax(upr));
);

StatsU(upr,   'OperHours')        = OperHours(upr);
StatsU(upr,   'NStart')           = sum(t, bStart.L(t,upr));
StatsU(upr,   'CO2QtyRegul')      = sum(t, CO2Emis.L(t,upr,'regul'));
StatsU(upr,   'CO2QtyPhys')       = sum(t, CO2Emis.L(t,upr,'phys'));
StatsU(upr,   'CO2QtyRegul')      = sum(t, CO2Emis.L(t,upr,'regul'));
StatsU(upr,   'FF')           = sum(t, FF.L(t,upr));
StatsU(upr,   'FuelQty')          = sum(t, FuelQty.L(t,upr));
StatsU(upr,   'FuelConsumed')     = sum(t, FF.L(t,upr));
StatsU(upr,   'HeatGen')          = sum(t, QF.L(t,upr))           $OnUGlobal(upr);
StatsU(kv,    'HeatRGK')          = sum(t, QRgk.L(t,kv))         $OnUGlobal(kv);
StatsU(kv,    'HeatBypass')       = sum(t, QfBypass.L(t,kv))      $OnUGlobal(kv);
StatsU(u,     'TotalCost')        = sum(t, TotalCostU.L(t,u))    $OnUGlobal(u);
StatsU(upr,   'TotalTax')         = sum(t, TotalTaxUpr.L(t,upr)) $OnUGlobal(upr);
StatsU(upr,   'FuelCost')         = sum(t, FuelCost.L(t,upr))    $OnUGlobal(upr);
StatsU(u,     'DVCost')           = sum(t, VarDVOmkst.L(t,u))    $OnUGlobal(u);
StatsU(upr,   'StartCost')        = sum(t, StartOmkst.L(t,upr))  $OnUGlobal(upr);
StatsU(upr,   'ElCost')           = sum(t, ElEgbrugOmkst.L(t,upr));
StatsU(kv,    'TotalElIncome')    = sum(t, TotalElIncome.L(t,kv));
StatsU(kv,    'ElSpotIncome')     = sum(t, PfNet.L(t,kv) * ElspotActual(t));
StatsU(upr,   'CO2Kvote')         = sum(t, TaxProdU.L(t,upr,'ets'));   # NB: Udtræk af TaxProdU, skal ikke medregnes to gange.
StatsU(upr,   'PowerNet')         = tiny $OnUGlobal(upr);
StatsU(upr,   'PowerGen')         = tiny $OnUGlobal(upr);
StatsU(upr,   'ElEgbrug')         = sum(t, ElEigenE.L(t,upr));
StatsU(uelec, 'CapEAllocMWhUp')   = sum(tt2tbid(tt,tbid), CapEAlloc.L(tt,uelec,'up')); 
StatsU(uelec, 'CapEAllocMWhDown') = sum(tt2tbid(tt,tbid), CapEAlloc.L(tt,uelec,'down')); 

loop (kv $(OnUGlobal(kv)),
  StatsU(kv,'PowerNet')   = sum(t, PfNet.L(t,kv));
  StatsU(kv,'PowerGen')   = sum(t, PfBrut.L(t,kv));
  StatsU(kv,'SalesPower') = sum(t, ElSales.L(t,kv));
  #--- StatsU(kv,'ElTilskud')  = sum(t, ElTilskud.L(t,kv));

  if (StatsU(kv,'PowerNet')   EQ 0.0, StatsU(kv,'PowerNet')   = tiny $OnUGlobal(kv); );
  if (StatsU(kv,'PowerGen')   EQ 0.0, StatsU(kv,'PowerGen')   = tiny $OnUGlobal(kv); );
  if (StatsU(kv,'SalesPower') EQ 0.0, StatsU(kv,'SalesPower') = tiny $OnUGlobal(kv); );
  #--- if (StatsU(kv,'ElTilskud')  EQ 0.0, StatsU(kv,'ElTilskud')  = tiny $OnUGlobal(kv); );
);

loop (kv $(OnUGlobal(kv)),
  tmp = StatsU(kv,'HeatGen') + StatsU(kv,'PowerGen');
  if (tmp GT 0.0,
    StatsU(kv,'RGKshare') = max(tiny, StatsU(kv,'HeatRGK') / tmp) $OnUGlobal(kv);
  else 
    StatsU(kv,'RGKshare') = tiny $OnUGlobal(kv);
  );
);


# Bortkølet varme.
loop (uaff $OnUGlobal(uaff),
  StatsU(uaff, 'HeatCool') = max(tiny, sum(t, AffQcool.L(t,uaff)) ) $OnUGlobal(uaff);
);

StatsU(upr, 'HeatMargPrice') = QMargPrice(upr);

# Sikre at nul-elementer tildeles en meget lille værdi.
loop (u $OnUGlobal(u),
  loop (topicU,
    if (StatsU(u,topicU) EQ 0, StatsU(u,topicU) = tiny; );
  );
);

*end Beregning af StatsU


*end Beregning af StatsVak

StatsVak(vak,'TurnOver') $(OnUGlobal(vak) AND CapQU(vak) GT 0.0) = max(tiny, sum(tt, QVakAbs.L(tt,vak)) / CapQU(vak)) $OnUGlobal(vak);
StatsVak(vak,'QLoss')    $(OnUGlobal(vak) AND CapQU(vak) GT 0.0) = max(tiny, sum(tt, VakLossE.L(tt,vak))) $OnUGlobal(vak);

*end Beregning af StatsVak

#--- loop (upr, loop (topicU,   if (StatsU(upr,topicU)     EQ 0.0, StatsU(upr,topicU)     = tiny; ); ); ) $OnUGlobal(upr);
#--- loop (vak, loop (topicVak, if (StatsVak(vak,topicVak) EQ 0.0, StatsVak(vak,topicVak) = tiny; ); ); ) $OnUGlobal(upr);
display StatsU, StatsVak;


*begin Beregning af StatsTax

StatsTax(upr,tax) = 0.0;

#OBS CO2 kvote-omk. er teknisk set ikke en afgift, men af bekvemmelighedsgrunde indsættes den i StatsTax.
loop (upr $OnUGlobal(upr),
  StatsTax(upr,tax)   = sum(t, TaxProdU.L(t,upr,tax));
  StatsTax(upr,'ets') = sum(t, CO2KvoteOmkst.L(t,upr));
);

*end 

*begin Beregning af StatsFuel

StatsFuel(f,'CO2QtyPhys')  = CO2emisFuelSum(f,'phys');
StatsFuel(f,'CO2QtyRegul') = CO2emisFuelSum(f,'regul');
StatsFuel(f,'Qty')         = sum(upr $(OnUGlobal(upr) AND FuelMix(upr,f) GT 0.0), FuelMix(upr,f) * FinSum(upr) / LhvMWhPerUnitFuel(f) );

*end

*begin Beregning af StatsOther

# Other stats
StatsOther('ucool','HeatVented') = max(tiny, sum(ucool $OnUGlobal(ucool), sum(t, QCool.L(t,ucool))) );

*end 


*begin Beregn hver ejers andel af grundlastvarmen i hvert tidspunkt.

# Først beregnes den samlede grundlast fra BHP (netMa og netHo).

BaseLoadSum                = sum(t, Qbase.L(t));
QTransSum(tr) $OnTrans(tr) = sum(t, QTF.L(t,tr));

# Dernæst beregnes andelen for hver time, hvor SR-anlæg var aktive.
BaseLoadShare(t,'netHo') = QTF.L(t,'tr2') / Qbase.L(t);
BaseLoadShare(t,'netSt') = QTF.L(t,'tr1') / Qbase.L(t);

#--- abort.noerror "BEVIDST STOP i DumpPeriodsToExcel.gms";
#--- execute_unload "MecLpMain.gdx";

# Overskridelser af ejerandelen vil ligge indenfor relaxation tolerancer for binære variable i.e. af størrelsesorden 1E-3 og kan derfor ignoreres.
ViolationOwnerShare(t,'netHo') = bOnSR.L(t,'netSt') $(BaseLoadShare(t,'netHo') GT (1 - Diverse('StruerAndel')));
ViolationOwnerShare(t,'netSt') = bOnSR.L(t,'netHo') $(BaseLoadShare(t,'netSt') GT (    Diverse('StruerAndel')));
CountViolationOwnerShare(netq) = sum(t, ViolationOwnerShare(t,netq));

*end


*begin Beregning af StatsAll

StatsAll('SlaveObj')      = ObjSumRHreal * PeriodObjScale;
StatsAll('HeatProduced')  = sum(upr $OnUGlobal(upr), StatsU(upr, 'HeatGen'));

# Leveret varme er identisk med varmebehovet. Udover bortkøling på BHP er der tab i tanke og T-ledninger.
StatsAll('HeatDelivered') = StatsAll('HeatProduced') - StatsOther('ucool','HeatVented');

StatsAll('SrHeatHo')      = max(tiny, sum(urHo $(OnUGlobal(urHo) AND DataU(urHo,'SR') EQ 1), StatsU(urHo, 'HeatGen')));
StatsAll('SrHeatSt')      = max(tiny, sum(urSt $(OnUGlobal(urSt) AND DataU(urSt,'SR') EQ 1), StatsU(urSt, 'HeatGen')));
StatsAll('ViolateHo')     = max(tiny, CountViolationOwnerShare('netHo'));
StatsAll('ViolateSt')     = max(tiny, CountViolationOwnerShare('netSt'));
StatsAll('ElspotPrice')   = sum(t, ElspotActual(t)) / card(t);
StatsAll('VPO')           = - StatsAll('SlaveObj') / StatsAll('HeatDelivered');

*end Beregning af StatsAll
       

* Alle items skal have mindst ét ikke-nul element for at blive overført til gdx-databasen og dermed til rådighed for GDXXRW.
loop (lblScenMas, if (ActScen(lblScenMas)    EQ 0.0, ActScen(lblScenMas)    = tiny;));
loop (topicSolver,  if (StatsSolver(topicSolver) EQ 0.0, StatsSolver(topicSolver) = tiny;) );


*begin Udskrivning via GDX-file til Excel via GDXXRW

execute_unload 'MECoutput.gdx',
Scenarios, actSc, ActScen, DurationPeriod, DataU, DataHp, DataTransm, QTmin, QTmax, Brandsel,
zSlave, zNormalized, zNormalizedReal, CostInfeas, 
SalesHeatTotal, SalesPowerTotal, SubsidiesTotal, CostMaintTotal, CostStartTotal, CostCO2EtsTotal, CostFuelTotal, CostPowerTotal,
CostTotal, TaxTotal, TaxEnrTotal, TaxCO2Total, TaxNOxTotal, TaxSOxTotal, InfeasTotal,   
tt, t, net, netq, u, upr, ucool, hp, vak, urHo, urSt, tr, f, 
OnTimeAggr, UseTimeAggr, UseTimeExpansion, BLen, Nblock,
topicAll, topicSolver, topicU, topicVak, topicT, 
OnUGlobal, OnU, OnTrans,
#--- Q_L, QT_L, QRgk_L, Qbypass_L, Qcool_L, LVak_L, Fin_L, bOn_L, bOnSR_L,             
BaseLoad, BaseLoadSum, QTransSum, BaseLoadShare, CountViolationOwnerShare,
StatsSolver, StatsAll, StatsU, StatsVak, StatsT, StatsFuel, StatsOther;

If ( %oDumpStatsToExcel% NE 0,

$onecho > MECoutput.txt
filter=0

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

* OutItemsTable
*--- text="OutItemsTable" rng=OutItems!A8
*--- par=OutItemsTable squeeze=N rng=OutItems!A9

* Overview as the last sheet to be written hence the actual sheet when opening Excel file.

*-- OverView Inputs
text="ActualScenario" rng=Overview!A3:A3
set=actSc rng=Overview!B3:B3
text="DurationPeriod" rng=OverView!A6:A6
par=DurationPeriod rng=OverView!B6:B6
text="ActScen" rng=Overview!A7
par=ActScen squeeze=N rng=Overview!A8 cdim=0 rdim=1
par=StatsSolver squeeze=N rng=OverView!A71 cdim=0 rdim=1
text="GAMS Job statistics" rng=OverView!A70:A70

par=StatsU squeeze=N     rng=OverView!E4 cdim=1 rdim=1
text="Unit stats"        rng=Overview!E4
par=StatsVak squeeze=N   rng=OverView!E30 cdim=1 rdim=1
text="VAK stats"         rng=Overview!E30

$offecho

execute "gdxxrw.exe MECoutput.gdx o=MECoutput.xlsm trace=1 @MECoutput.txt";

);  # If %DumpStatsToExcel% NE 0 ...

*end Udskrivning via GDX-file til Excel via GDXXRW

*end DUMP til Excel output
