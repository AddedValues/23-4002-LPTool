$OnText
Denne GAMS modelfil er beregnet til inkludering ($INCLUDE) i MEC-modellen.
Den udfører rapportering af optimeringsfasen for en given periode, perL, som defineres i modellen.
$OffText

#begin StatsMecU

#--- StatsMecU(upr,topicMecU,moyr) = tiny;
#--- StatsMecU(upr,topicMecU,moyr) = tiny;

#begin Beregning af StatsMecU på månedsniveau. 
tend = 0;
loop (mo,
  actMo(moa) = ord(moa) EQ ord(mo);
  tbeg       = tend + 1;
  tend       = MonthTimeAccumAggr(mo);
  tmo(tt)    = ord(tt) GE tbeg AND ord(tt) LE tend;
  #--- display "DEBUG: actMo, tbeg, tend, tmo", actMo, tbeg, tend, tmo; 
  
  StatsMecU(upr, 'OperHours',     mo) = sum(tmo, BLen(tmo) * bOn.L(tmo,upr) ); 
  StatsMecU(kv,  'BypassHours',   mo) = sum(tmo, BLen(tmo) * bBypass.L(tmo,kv) ); 
  StatsMecU(kv,  'Rgkhours',      mo) = sum(tmo, Blen(tmo) * bRgk.L(tmo,kv) ); 
  StatsMecU(kv,  'NStart',        mo) = sum(tmo, bStart.L(tmo,kv) ); 
  StatsMecU(kv,  'PowerNet',      mo) = sum(tmo, Pnet.L(tmo,kv) ); 
  StatsMecU(kv,  'PowerSales',    mo) = sum(tmo, Pnet.L(tmo,kv) * ElspotActual(tmo) ); 
  StatsMecU(kv,  'HeatBypass',    mo) = sum(tmo, QBypass.L(tmo,kv) ); 
  StatsMecU(kv,  'HeatRgk',       mo) = sum(tmo, QRgk.L(tmo,kv) ); 
  StatsMecU(upr, 'CO2QtyPhys',    mo) = sum(tmo, CO2Emis.L(tmo,upr,'phys') ); 
  StatsMecU(upr, 'CO2QtyRegul',   mo) = sum(tmo, CO2emis.L(tmo,upr,'regul') ); 
  StatsMecU(upr, 'PowInU',        mo) = sum(tmo, PowInU.L(tmo,upr) ); 
  StatsMecU(upr, 'FuelQty',       mo) = sum(tmo, FuelQty.L(tmo,upr) ); 
  StatsMecU(upr, 'FuelCost',      mo) = sum(tmo, FuelCost.L(tmo,upr) ); 
  
  StatsMecU(u,   'DVCost',        mo) = sum(tmo, VarDVOmkst.L(tmo,u) );     # Omfatter også VAK.
  StatsMecU(upr, 'StartCost',     mo) = sum(tmo, StartOmkst.L(tmo,upr) ); 
  StatsMecU(upr, 'ElCost',        mo) = sum(tmo, ElEgbrugOmkst.L(tmo,upr) ); 
  StatsMecU(u,   'TotalMargCost', mo) = sum(tmo, TotalCostU.L(tmo,u) ); 
  StatsMecU(upr, 'CO2KvoteCost',  mo) = sum(tmo, CO2KvoteOmkst.L(tmo,upr) ); 
  StatsMecU(upr, 'TotalTax',      mo) = sum(tmo, sum(tax $(NOT sameas(tax,'ets')), TaxProdU.L(tmo,upr,tax)) ); 
                                        
  StatsMecU(upr, 'HeatGen',          mo) = sum(tmo, Q.L(tmo,upr) ); 
  StatsMecU(uaff,'HeatCool',         mo) = sum(tmo, AffQCool.L(tmo,uaff) ); 
  StatsMecU(upr, 'HeatSent',         mo) = sum(uaff $sameas(upr,uaff), sum(tmo, AffQLev.L(tmo,uaff))) + StatsMecU(upr,'HeatGen',mo) $(NOT upraff(upr) ); 
  StatsMecU(kv,  'HeatBackPressure', mo) = sum(tmo, Qback.L(tmo,kv));

  # FixCapUCostPer indeholder både DV samt el-effekt tariff
  # OBS Worst-case beregning for VP, reelt skal el-effekt tariffen beregnes af max-effekttrækket som snit af 10 timer med højeste effekttræk jf. Dansk Energis Tarif-3.0 model.
  # OBS set uelec er foreningsmængden af set hp og set uek. 
  CapacP(u)                      = 0.0;
  CapacP(kv)         $OnU(kv)    = PowInMaxU(kv) * DataU(kv,'EtaP');
  CapacP(hp)         $OnU(hp)    = CapQU(hp) / COPmin(hp);           
  CapacP(uek)        $OnU(uek)   = CapQU(uek);
  CapacPoverQ(uelec)             = 0.0;
  CapacPoverQ(uelec) $(OnU(uelec) AND CapQU(uelec) GT 10*tiny) = CapacP(uelec) / CapQU(uelec); # Et anlæg kan være til rådighed med nul-kapacitet under masteriterationerne. 
  FixCapUTotalCost(u)            = Capex(u,'fixCost') + TariffElEffektU(u) * CapacPoverQ(u);  # DKK/MWq/yr
  FixTariffElCost(u)             = TariffElEffektU(u) * CapacPoverQ(u);  # DKK/MWq/yr

  StatsMecU(upr, 'FixCostElTariff', mo) = FixTariffElCost(upr) * CapQU(upr) * MonthFraction(mo); 
  StatsMecU(u,   'FixCostTotal',    mo) = FixCapUTotalCost(u) * [CapQU(u) $upr(u) + CapQVak(u) $vak(u)] * MonthFraction(mo);       # Omfatter også VAK.
  StatsMecU(u,   'DeprecCost',      mo) = DeprecCost(u) * MonthFraction(mo);                                  # Omfatter også VAK.
  StatsMecU(u,   'CapacCost',       mo) = StatsMecU(u,'FixCostTotal',mo) + StatsMecU(u, 'DeprecCost',mo);     # Omfatter også VAK.
                                    
  StatsMecU(u,   'TotalCost',       mo) = StatsMecU(u,'TotalMargCost',mo) + StatsMecU(u,'CapacCost',    mo);  # Omfatter også VAK.
  StatsMecU(u,   'ContribMargin',   mo) = StatsMecU(u,'PowerSales'   ,mo) - StatsMecU(u,'TotalMargCost',mo);  # Omfatter også VAK.

  # OBS Referencen for varmeproduktionsprisen er genereret varme (HeatGen) ikke leveret varme (HeatSent)
  StatsMecU(upr, 'HeatMargPrice',  mo) $(StatsMecU(upr,'HeatGen',mo) GT 100*tiny) = [-StatsMecU(upr,'ContribMargin',  mo)                                 ] / StatsMecU(upr, 'HeatGen', mo);
  StatsMecU(upr, 'HeatCapacPrice', mo) $(StatsMecU(upr,'HeatGen',mo) GT 100*tiny) = [                                      StatsMecU(upr, 'CapacCost', mo)] / StatsMecU(upr, 'HeatGen', mo);
  StatsMecU(upr, 'HeatTotalPrice', mo) $(StatsMecU(upr,'HeatGen',mo) GT 100*tiny) = [-StatsMecU(upr,'ContribMargin', mo) + StatsMecU(upr, 'CapacCost', mo)] / StatsMecU(upr, 'HeatGen', mo);
  
  # TurnOver gælder for lagerenheder og defineres som sum(t, abs(Q(t,vak))) / CapQVak(vak);
  StatsMecU(vak, 'TurnOver', mo) = sum(tmo, QVakAbs.L(tmo,vak)) * (1 / CapQVak(vak)) $OnVak(vak); 

  # RealPowerPrice gælder for elproducerende hhv. elforbrugende enheder samlet elomsætning delt med samlet elmængde.
  StatsMecU(uelec, 'RealPowerPriceBuy', mo)  $(OnU(uelec) AND StatsMecU(uelec, 'PowInU',   mo) NE 0.0) = sum(tmo, ElspotActual(tmo) * PowInU.L(tmo,uelec)) / StatsMecU(uelec, 'PowInU',   mo);
  StatsMecU(kv,    'RealPowerPriceSell', mo) $(OnU(kv)    AND StatsMecU(kv,    'PowerNet', mo) NE 0.0) = sum(tmo, ElspotActual(tmo) * Pnet.L(  tmo,kv))    / StatsMecU(kv,    'PowerNet', mo);
  
  #begin Aggregeret statistik på tværs af alle anlæg
  
  # Som udgangspunkt summeres over alle anlæg for hvert topic.
  StatsMecU('uaggr', topicMecU, mo) = sum(u, StatsMecU(u, topicMecU, mo));    # Omfatter også VAK.
  
#begin
#---  StatsMecU('uaggr', 'OperHours',          mo) = sum(upr,  StatsMecU(upr,  'OperHours'       , mo)); 
#---  StatsMecU('uaggr', 'BypassHours',        mo) = sum(kv,   StatsMecU(kv,   'BypassHours'     , mo)); 
#---  StatsMecU('uaggr', 'Rgkhours',           mo) = sum(kv,   StatsMecU(kv,   'Rgkhours'        , mo)); 
#---  StatsMecU('uaggr', 'NStart',             mo) = sum(kv,   StatsMecU(kv,   'NStart'          , mo)); 
#---  StatsMecU('uaggr', 'PowerNet',           mo) = sum(kv,   StatsMecU(kv,   'PowerNet'        , mo)); 
#---  StatsMecU('uaggr', 'PowerSales',         mo) = sum(kv,   StatsMecU(kv,   'PowerSales'      , mo)); 
#---  StatsMecU('uaggr', 'HeatBypass',         mo) = sum(kv,   StatsMecU(kv,   'HeatBypass'      , mo)); 
#---  StatsMecU('uaggr', 'HeatRgk',            mo) = sum(kv,   StatsMecU(kv,   'HeatRgk'         , mo)); 
#---  StatsMecU('uaggr', 'CO2QtyPhys',         mo) = sum(upr,  StatsMecU(upr,  'CO2QtyPhys'      , mo)); 
#---  StatsMecU('uaggr', 'CO2QtyRegul',        mo) = sum(upr,  StatsMecU(upr,  'CO2QtyRegul'     , mo)); 
#---  StatsMecU('uaggr', 'PowInU',             mo) = sum(upr,  StatsMecU(upr,  'PowInU'          , mo)); 
#---  StatsMecU('uaggr', 'FuelCost',           mo) = sum(upr,  StatsMecU(upr,  'FuelCost'        , mo)); 
#---  StatsMecU('uaggr', 'DVCost',             mo) = sum(upr,  StatsMecU(upr,  'DVCost'          , mo)); 
#---  StatsMecU('uaggr', 'StartCost',          mo) = sum(upr,  StatsMecU(upr,  'StartCost'       , mo)); 
#---  StatsMecU('uaggr', 'ElCost',             mo) = sum(upr,  StatsMecU(upr,  'ElCost'          , mo)); 
#---  StatsMecU('uaggr', 'TotalMargCost',      mo) = sum(upr,  StatsMecU(upr,  'TotalMargCost'   , mo)); 
#---  StatsMecU('uaggr', 'CO2KvoteCost',       mo) = sum(upr,  StatsMecU(upr,  'CO2KvoteCost'    , mo)); 
#---  StatsMecU('uaggr', 'TotalTax',           mo) = sum(upr,  StatsMecU(upr,  'TotalTax'        , mo)); 
#---  StatsMecU('uaggr', 'HeatGen',            mo) = sum(upr,  StatsMecU(upr,  'HeatGen'         , mo)); 
#---  StatsMecU('uaggr', 'HeatCool',           mo) = sum(uaff, StatsMecU(uaff, 'HeatCool'        , mo)); 
#---  StatsMecU('uaggr', 'HeatSent',           mo) = sum(upr,  StatsMecU(upr,  'HeatSent'        , mo)); 
#---  StatsMecU('uaggr', 'FixCostTotal',       mo) = sum(upr,  StatsMecU(upr,  'FixCostTotal'    , mo)); 
#---  StatsMecU('uaggr', 'FixCostElTariff',    mo) = sum(upr,  StatsMecU(upr,  'FixCostElTariff' , mo)); 
#---  StatsMecU('uaggr', 'DeprecCost',         mo) = sum(upr,  StatsMecU(upr,  'DeprecCost'      , mo)); 
#---  StatsMecU('uaggr', 'CapacCost',          mo) = sum(upr,  StatsMecU(upr,  'CapacCost'       , mo)); 
#---  StatsMecU('uaggr', 'TotalCost',          mo) = sum(upr,  StatsMecU(upr,  'TotalCost'       , mo)); 
#---  StatsMecU('uaggr', 'ContribMargin',      mo) = sum(upr,  StatsMecU(upr,  'ContribMargin'   , mo)); 
#end

  #--- SharedCapex = sum(vak $OnU(vak), StatsMecU(vak,'DeprecCost',mo) + StatsMecU(vak,'FixCostTotal',mo));
  tmp = sum(upr, StatsMecU(upr, 'HeatGen', mo));
  if (tmp GT 0.0,
    # OBS uaggr omfatter alle produktionsanlæg og VAK.
    StatsMecU('uaggr', 'HeatMargPrice',  mo) = sum(u, [-StatsMecU(u,'ContribMargin', mo)                               ]) / tmp;
    StatsMecU('uaggr', 'HeatCapacPrice', mo) = sum(u, [                                  + StatsMecU(u,'CapacCost', mo)]) / tmp;
    StatsMecU('uaggr', 'HeatTotalPrice', mo) = sum(u, [-StatsMecU(u,'ContribMargin', mo) + StatsMecU(u,'CapacCost', mo)]) / tmp;
  );
  
  tmp = sum(uelec, StatsMecU(uelec, 'PowInU', mo));
  if (tmp GT 0.0,  StatsMecU('uaggr', 'RealPowerPriceBuy', mo) = sum(uelec, StatsMecU(uelec, 'RealPowerPriceBuy', mo) * StatsMecU(uelec, 'PowInU', mo)) / tmp; );
  
  tmp = sum(kv, StatsMecU(kv, 'PowerNet', mo));
  if (tmp GT 0.0,  StatsMecU('uaggr', 'RealPowerPriceSell', mo) = sum(kv,    StatsMecU(kv, 'RealPowerPriceSell', mo) * StatsMecU(kv, 'PowerNet', mo)) / tmp; ); 
  
  #end   Aggregeret statistik på tværs af alle anlæg
 
);  # Loop mo                                          
#end Beregning af StatsMecU på månedsniveau. 


#begin Beregning af StatsMecU på årsniveau (moall i set moyr).

# Først beregnes alle topics som summen af månedsværdierne.
# Dernæst overskrives de topics, som ikke kan være årssummer, men skal beregnes igen.

StatsMecU(u, topicMecU, 'moall')  = sum(mo, StatsMecU(u, topicMecU, mo));

# Som udgangspunkt er anlægsaggregerede størrelser lig med summen over anlæg.
StatsMecU('uaggr', topicMecU, 'moall') = sum(u, StatsMecU(u, topicMecU, 'moall'));

# Sæt tidsdomænet til hele året.
tmo(tt) = ord(tt) LE MonthTimeAccumAggr('mo12');

#--- SharedCapex = sum(vak $OnU(vak), StatsMecU(vak,'DeprecCost','moall') + StatsMecU(vak,'FixCostTotal','moall'));
#--- SharedCapexPerIter(actPer,actIter) = SharedCapex;
                                                                                                                                                                     
StatsMecU(upr, 'HeatMargPrice',  'moall') $(StatsMecU(upr, 'HeatGen', 'moall') GT 100*tiny) = [-StatsMecU(upr,'ContribMargin', 'moall')                                       ] / StatsMecU(upr, 'HeatGen', 'moall');
StatsMecU(upr, 'HeatCapacPrice', 'moall') $(StatsMecU(upr, 'HeatGen', 'moall') GT 100*tiny) = [                                           StatsMecU(upr, 'CapacCost', 'moall')] / StatsMecU(upr, 'HeatGen', 'moall');
StatsMecU(upr, 'HeatTotalPrice', 'moall') $(StatsMecU(upr, 'HeatGen', 'moall') GT 100*tiny) = [-StatsMecU(upr,'ContribMargin', 'moall') + StatsMecU(upr, 'CapacCost', 'moall')] / StatsMecU(upr, 'HeatGen', 'moall');

tmp = sum(upr, StatsMecU(upr, 'HeatGen', 'moall'));
if (tmp GT 100 * tiny,
  StatsMecU('uaggr', 'HeatMargPrice',  'moall') = [-StatsMecU('uaggr','ContribMargin', 'moall')                                           ] / tmp;
  StatsMecU('uaggr', 'HeatCapacPrice', 'moall') = [                                             + StatsMecU('uaggr', 'CapacCost', 'moall')] / tmp;
  StatsMecU('uaggr', 'HeatTotalPrice', 'moall') = [-StatsMecU('uaggr','ContribMargin', 'moall') + StatsMecU('uaggr', 'CapacCost', 'moall')] / tmp;
);

# TurnOver gælder for lagerenheder og defineres som sum(t, abs(Q(t,vak))) / CapQVak(vak);
# TurnOver har ikke en åbenbar definition på tværs af VAK.
StatsMecU(vak, 'TurnOver', 'moall') = sum(tmo, QVakAbs.L(tmo,vak)) * (1 / CapQVak(vak)) $OnVak(vak); 

# RealPowerPrice gælder for elproducerende hhv. elforbrugende enheder og udgør samlet elomsætning delt med samlet elmængde.
StatsMecU(uelec, 'RealPowerPriceBuy',  'moall') $(OnU(uelec) AND StatsMecU(uelec, 'PowInU',   'moall') NE 0.0) = sum(tmo, ElspotActual(tmo) * PowInU.L(tmo,uelec)) / StatsMecU(uelec, 'PowInU',   'moall');
StatsMecU(kv,    'RealPowerPriceSell', 'moall') $(OnU(kv)    AND StatsMecU(kv,    'PowerNet', 'moall') NE 0.0) = sum(tmo, ElspotActual(tmo) * Pnet.L(  tmo,kv))    / StatsMecU(kv,    'PowerNet', 'moall');

tmp = sum(uelec, StatsMecU(uelec, 'PowInU', 'moall'));
if (tmp GT 0.0, StatsMecU('uaggr', 'RealPowerPriceBuy', 'moall') = sum(uelec, sum(tmo, ElspotActual(tmo) * PowInU.L(tmo,uelec))) / tmp; );

tmp = sum(kv, StatsMecU(kv, 'PowerNet', 'moall'));
if (tmp GT 0.0, StatsMecU('uaggr', 'RealPowerPriceSell', 'moall') = sum(kv, sum(tmo, ElspotActual(tmo) * Pnet.L(tmo,kv))) / tmp; );
                                                                                                              
#end Beregning af StatsMecU på årsniveau (moall i set moyr).

                                                       
# Her sikres, at nulværdier erstattes af en meget lille værdi (tiny = 1E-14).
StatsMecU(uall,topicMecU,moyr) $(abs(StatsMecU(uall,topicMecU,moyr)) LE 1E-10) = tiny;

#end StatsMecU


#begin StatsMecF

StatsMecF(f,'Qty') = sum(upr $(OnU(upr) AND FuelMix(upr,f) GT 0.0), FuelMix(upr,f) * StatsU(upr,'FuelQty') );

# Brændselsprisen beregnes som et forbrugsvægtet gennemsnit over alle anlæg, som anvender et givet brændsel.
# FuelQty(t,upr)  =E=  PowInU(t,upr) / sum(f, FuelMix(upr,f) * LhvMWhPerUnitFuel(f)); 

loop (f $(NOT sameas(f,'Elec') AND StatsFuel(f,'Qty') GT 0.0),
   StatsMecF(f,'Pris')  = sum(upr $(OnU(upr) AND FuelMix(upr,f) GT 0.0), FuelMix(upr,f) * PowInUSum(upr) / LhvMWhPerUnitFuel(f) * [FuelPrice(upr,f) * FuelPriceGain(f) + TariffFuelMWh(f)]) / StatsFuel(f,'Qty');
);
StatsMecF('Elec','Pris') = sum(tt, ElspotActual_tt(tt)) / card(tt); 

StatsMecF(f,'CO2QtyPhys')  = CO2emisFuelSum(f,'phys');
StatsMecF(f,'CO2QtyRegul') = CO2emisFuelSum(f,'regul');

# Her indsættes en meget lille værdi for at sikre at nul-priser også repræsenteres så en hel dimension i StatsMecF ikke forsvinder.
StatsMecF(f,topicMecF) $(abs(StatsMecF(f,topicMecF)) LE 1E-10) = tiny;

#end StatsMecF

# Kopiering af statsMec for aktuelle periode til opsamling henover perioder og masteriteration.
StatsMecUPerIter(uall,topicMecU,moyr,actPer,actIter) = StatsMecU(uall,topicMecU,moyr);
StatsMecFPerIter(f,topicMecF,actPer,actIter)         = StatsMecF(f,topicMecF);