$log Entering file: %system.incName%
#(
$OnText
Projekt:    20-1001 MEC BHP - Fremtidens fjernvarmeproduktion
Filnavn:    DeclareSlaveCommon.gms
Scope:      Definerer fælles / tværgående sets, parameters, variables, equations for slavemodellen.
Kaldes af:  gams.exe
Dato:       2020-01-18 13:09
Inkluderes af:  MecLpMain.gms
$OffText
    

*begin Sets og parametre.


*begin Variables

Free     variable       zSlave                       'Slave objective';
Positive variable       QSales(tt)                   'Varmesalg [DKK]';
Positive variable       QInfeas(tt,net,InfeasDir)    'Virtuelle varmekilder og -dræn [MW]';
                        
Positive variable       TotalCO2Emis(tt,net,co2kind) 'Samlede regulatoriske CO2-emission [ton/h]';
Positive variable       TotalCO2EmisSum(net,co2kind) 'Sum af regulatorisk CO2-emission [ton]';
Positive variable       CO2KvoteOmkst(tt,upr)        'CO2 kvote omkostning [DKK]';
# REMOVE Positive variable       TariffEl(tt,upr)             'Eltarif på elektrisk drevne anlæg';

# TODO For samme type flow, fx Q, VarDVOmkst, skal der ikke skelnes mellem produktionsanlæg og KV-anlæg på variabel-siden.

Free variable           Q(tt,u)                    'Heat delivery from unit u';
Free variable           FuelCost(tt,upr)           'Fuel cost til el bliver negativ, hvis elprisen går i negativ';
Free variable           TotalCostU(tt,u);
Free variable           TotalElIncome(tt,kv);
Free variable           ElSales(tt,kv)             'Indtægt fra elsalg';
#--- Free variable           ElTilskud(tt,kv);

*begin Transmission

Positive variable       QT(tt,tr)                   'Transmitteret varme [MWq]';
Positive variable       QTloss(tt,tr)               'Transmissionsvarmetab [MWq]';
#remove Positive variable       QTransOmkst(tt,netF,netT);
Free     variable       CostPump(tt,tr)             'Pumpeomkostninger';
Binary   variable       bOnT(tt,tr)                 'On/off timetilstand for T-ledninger';
Binary   variable       bOnTAll(tr)                 'On/off årstilstand for T-ledninger';

*end

Positive variable       QCool(tt,ucool);
Positive variable       PowInU(tt,upr)             'Indgivet effekt [MWf]';
#--- Positive variable       PowInUSum(upr)             'Sum af indgivet effekt [MWhf]';
Positive variable       StartOmkst(tt,upr)         'Startomkostning [DKK]';

#--- Positive variable       FixedDVCost(u)             'Faste DV omk. [DKK/MWf/år]';
#--- Positive variable       FixedDVCostTotal;

Positive variable       ElEgbrugOmkst(tt,upr)      'Egetforbrugsomkostning [DKK]';
Positive variable       VarDVOmkst(tt,u);
Positive variable       DVOmkstRGK(tt,kv)          'D&V omkostning relateret til RGK [DKK]';
Positive variable       CostInfeas(tt,net)         'Infeasibility omkostn. [DKK]';
Positive variable       CostSrPenalty(tt,net)      'Penalty på SR-varme [DKK]';
Positive variable       TaxProdU(tt,upr,tax);
Positive variable       TotalTaxUpr(tt, upr);
Positive variable       CO2Emis(tt,upr,co2kind)    'CO2 emission [kg]';
#--- Positive variable       CO2emisFuelSum(f,co2kind)  'Sum af CO2-emission pr. drivmiddel [kg]';
Positive variable       FuelQty(tt,upr)            'Drivmiddelmængde [ton]';
Positive variable       FuelHeat(tt,kv)            'Brændsel knyttet til varmeproduktion i KV-anlæg';
Positive variabLe       ElEigen(tt,upr)            'El-egetforbrug for hvert anlæg';

Positive variable       Pbrut(tt,kv)               'Brutto elproduktion på kraftvarmeværker';
Positive variable       Pnet(tt,kv)                'Netto elproduktion på kraftvarmeværker';
Positive variable       Pback(tt,kv);
Positive variable       Pbypass(tt,kv);
Positive variable       Qback(tt,kv);
Positive variable       Qbypass(tt,kv);
Positive variable       QRgk(tt,kv);
Positive variable       QbypassCost(tt,kv);

binary   variable       bBypass(tt,kv);
binary   variable       bRgk(tt,kv);
Binary   variable       bOn(tt,upr)                'On/off variable for all units';
Binary   variable       bStart(tt,upr)             'Indikator for start af prod unit';
Binary   variable       bOnRGK(tt,kv)              'Angiver om RGK-anlæg er i drift';
Binary   variable       bOnSR(tt,netq)             'On/off på SR-anlæg i reale forsyningsområder';

# VAK
Positive variable       LVak(tt,vak)               'Ladning på vak [MWh]';
Positive variable       QMaxVak(tt,vak)            'Øvre grænse på opladningseffekt';
Positive variable       VakLoss(tt,vak)            'Storage loss per hour';
#--- Positive variable       CostVak(tt,vak)            'Ladeomkostninger for vak';
Positive variable       QVakAbs(tt,vak)            'Absolut laderate for beregning af ladeomkostninger [MW]';
#--- Positive variable       QUpr2Vak(tt,vak)           'Indfødet varme fra alle prod-anlæg til vak';
#--- Positive variable       QT2Vak(tt,tr,vak)          'Indfødet varme fra hver T-ledning til vak';

# Begrænsning på ejerandel af grundlastvarmen.
Positive variable       Qbase(tt)                  'Grundlastvarmeproduktion';
Positive variable       QbasebOnSR(tt,netq)        'Product af Qbase og bOnSR';

*begin Kapacitetsallokeringer
Positive variable       CapEAlloc(tt,uelec,updown)    'Kapacitetsallokeringer på anlægsbasis';
Positive variable       CapESlack(tt,updown)          'Kapacitetsallokerings slack ift. diskret størrelse';
Positive variable       CapEAllocSumU(tt,updown)      'Kapacitetsallokering summeret over anlæg';
Positive variable       CostCapESlack(tt,updown)      'Penalty cost på CapESlack';

Equation EQ_CapEAllocConsDown(tt,uelcons) 'Reserverer nedregul. kapac. for elforbrug. anlæg';
Equation EQ_CapEAllocConsUp(tt,uelcons)   'Reserverer opregul.  kapac. for elforbrug. anlæg';
Equation EQ_CapEAllocProdDown(tt,uelprod) 'Reserverer nedregul. kapac. for elprod. anlæg';
Equation EQ_CapEAllocProdUp(tt,uelprod)   'Reserverer opregul.  kapac. for elprod. anlæg';

# CapEU er den øjeblikkelige max. kapacitet: PowInUMax / COP for elforbrugende anlæg, og Pnet(t) for elproducerende anlæg
EQ_CapEAllocConsUp(t,uelcons)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'up'))   .. PowInU(t,uelcons)                        =G=  BLen(t) * CapEAlloc(t,uelcons,'up');
EQ_CapEAllocConsDown(t,uelcons) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'down')) .. PowInU(t,uelcons)                        =L=  BLen(t) * (CapEU(t,uelcons) - CapEAlloc(t,uelcons,'down'));
EQ_CapEAllocProdUp(t,uelprod)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'up'))   .. sum(kv $sameas(kv,uelprod), Pnet(t,kv))  =L=  BLen(t) * (CapEU(t,uelprod) - CapEAlloc(t,uelprod,'up'));
EQ_CapEAllocProdDown(t,uelprod) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'down')) .. sum(kv $sameas(kv,uelprod), Pnet(t,kv))  =G=  BLen(t) * CapEAlloc(t,uelprod,'down');

Equation EQ_CapEAllocSum(tt,updown)       'Beregner CapEAllocSumU';
EQ_CapEAllocSum(t,updown) $(OnCapacityReservation AND IsBidDay(t)) .. CapEAllocSumU(t,updown)  =E=  sum(uelec $OnU(t,uelec), CapEAlloc(t,uelec,updown));

Equation EQ_AllocReservMatch(tbid,tt,updown)  'Sikrer match mellem allok. og reservation';
EQ_AllocReservMatch(tbid,tt,updown) $(OnCapacityReservation AND ord(tbid) LE HoursBidDay AND IsBidDay(tt) AND tt2tbid(tt,tbid)) .. 
                                         CapEAllocSumU(tt,updown) + CapESlack(tt,updown)  =E=  BLen(tt) * sum(elmarket $DataElMarket('Active',elmarket), CapEReservation(tbid,elmarket,updown));

Equation EQ_CostCapESlack(tt,updown)      'Beregner penalty på CapESlack';
EQ_CostCapESlack(t,updown) $(OnCapacityReservation AND IsBidDay(t)) .. CostCapESlack(t,updown)  =E=  CapESlackPenalty * CapESlack(t,updown);

*end Kapacitetsallokeringer

*end

*begin Ligningsspecifikationer

*begin Overordnede equations
Equation EQ_ObjSlave                        'Objektfunktion med totale omkostninger';
Equation EQ_QSales(tt)                      'FJV-salg';
Equation EQ_Start(tt,upr);
Equation EQ_Availability(tt,cp);
Equation EQ_CostInfeas(tt,net);
Equation EQ_CostSrPenalty(tt,net);
Equation EQ_TotalCostU(tt,u);
Equation EQ_TotalElIncome(tt,kv);
Equation EQ_CO2EmisSum(net,co2kind);
Equation EQ_TotalCO2Emis(tt,net,co2kind);
#--- Equation EQ_CO2EmitLimit(net,co2kind);

#OBS Genberegning af slave objective efter hver rullende horisont skal opdateres hvis EQ_ObjSlave opdateres.

EQ_ObjSlave .. zSlave  =E=  ( sum (t,
                               + QSales(t)
                               + sum (tr  $OnTrans(tr),    -CostPump(t,tr))
                               + sum (u   $OnU(t,u),       -TotalCostU(t,u))
                               + sum (kv  $OnU(t,kv),      +TotalElIncome(t,kv))
                               #--- + sum (vak $OnU(t,vak),   -CostVak(t,vak))
                               + sum (net $OnNet(net),     -CostInfeas(t,net))
                               + sum (net $OnNet(net),     -CostSrPenalty(t,net))
                               + sum (updown,              -CostCapESlack(t,updown))
                               )
                             ) / PeriodObjScale;      # Total cost in MDKK.

EQ_CostInfeas(t,net) $OnNet(net) .. CostInfeas(t,net)  =E=  sum(infeasDir, QInfeas(t,net,infeasDir)) * QInfeasPenalty;   #---  + sum(netq $OnNet(netq), sum(t, bOnSR(t,netq))) * bOnSRPenalty;

EQ_CostSrPenalty(t,net) .. CostSrPenalty(t,net)  =E=  sum(upsr $(OnU(t,upsr) AND AvailUNet(upsr,net)), Q(t,upsr) * QSrPenalty) $OnNet(net);

EQ_QSales(t) ..  QSales(t)  =E=  sum(net $(OnNet(net) AND QSalgspris(net) GT 0.0), QSalgspris(net) * QDemandActual(t,net));

$OffOrder
#--- EQ_Start(t,upr) $(OnU(t,upr) AND ord(t) GE 2)    .. bOn(t,upr) - bOnPrevious(upr) $(ord(t) EQ 1) + bOn(t-1,upr) $(ord(t) GT 1)  =L=  bStart(t,upr);

EQ_Start(t,upr) $(OnU(t,upr))  .. bOn(t,upr) - (bOnPrevious(upr) $(ord(t) EQ 1) + bOn(t-1,upr) $(ord(t) GT 1))  =L=  bStart(t,upr);
$OnOrder

EQ_Availability(t,cp) .. bOn(t,cp)  =L=  max(0, OnU(t,cp));

EQ_CO2EmisSum(net,co2kind)   .. TotalCO2EmisSum(net,co2kind)  =E=  sum(t, TotalCO2Emis(t,net,co2kind));

EQ_TotalCo2Emis(t,net,co2kind) $OnNet(net) .. TotalCO2Emis(t,net,co2kind)  =E=  sum(upr $(AvailUNet(upr,net) AND OnU(t,upr)), CO2emis(t,upr,co2kind) );

EQ_TotalCostU(t,u) $(OnU(t,u)) .. TotalCostU(t,u)  =E=  sum(upr $sameas(upr,u), 
                                                           [  FuelCost(t,upr) 
                                                            + StartOmkst(t,upr) 
                                                            + ElEgbrugOmkst(t,upr) 
                                                            + TotalTaxUpr(t,upr) 
                                                            + CO2KvoteOmkst(t,upr)
                                                            + sum(kv $sameas(kv,upr), QbypassCost(t,kv))
                                                           ])
                                                            + VarDVOmkst(t,u);


#--- EQ_TotalElIncome(t,kv) $(OnU(t,kv)) .. TotalElIncome(t,kv)    =E=  [ElSales(t,kv) + ElTilskud(t,kv)] $OnU(t,kv);
EQ_TotalElIncome(t,kv) $(OnU(t,kv)) .. TotalElIncome(t,kv)    =E=  [ElSales(t,kv)] $OnU(t,kv);

*end Overordnede equations


*begin Produktionsgrænser og varmebalance.
Equation EQ_PowInProdU(tt,upr)    'Indgiven effekt [MW]';
Equation EQ_QProdUmin(tt,upr)     'Min. varmeproduktion for units [MWq]';
Equation EQ_QProdUmax(tt,upr)     'Max. varmeproduktion for units [MWq]';
Equation EQ_QMaxPtX(tt)           'Max varmeprodutkion PtX elprisafhængig';
#--- Equation EQ_PowInUSum(upr)        'Sum af indgivet effekt [MWhf]';

# Indgiven effekt afledes af varmeeffekten, som er den styrende variabel, som igen er underlagt kapacitetsgrænser.
# Denne ligning gælder kun for rene varmeproducerende anlæg, ikke KV-anlæg.
EQ_PowInProdU(t,upr) $(OnU(t,upr) AND uq(upr)) .. PowInU(t,upr)  =E= (Q(t,upr) / EtaQU(upr)) $(NOT hp(upr)) + sum(hp $sameas(hp,upr), (Q(t,hp) / COP(t,hp)));

# Hensyntagen til modulstørrelse i beregning af mindstelast: EQ_QProdUmin:
EQ_QProdUmin(t,upr) $(OnU(t,upr) AND uq(upr)) .. Q(t,upr)  =G=  BLen(t) * DataU(upr,'Fmin') * CapQU(upr) * DataU(upr,'ModuleSize') * [1 $(not hp(upr)) + sum(hp $sameas(hp,upr), QhpYield(t,hp))] * bOn(t,upr);
EQ_QProdUmax(t,upr) $(OnU(t,upr) AND uq(upr)) .. Q(t,upr)  =L=  BLen(t) * DataU(upr,'Fmax') * CapQU(upr) * [1 $(not hp(upr)) + sum(hp $sameas(hp,upr), QhpYield(t,hp))] * bOn(t,upr);

EQ_QMaxPtX(t) $OnUGlobal('MaNhpPtX')  .. Q(t,'MaNhpPtX') =L= BLen(t) * QmaxPtX(t);


Equation EQ_HeatBalance(tt,net);

# TODO Varmetabet i retur-retningen bæres reelt af netF i modsætning til tabet i frem-retningen. Brug trkind til at skelne og revider EQ_Heat_Balance.

    EQ_HeatBalance(t,net) $OnNet(net) .. QDemandActual(t,net) =E=
                                     sum(uq $(OnUNet(uq,net)),            Q(t,uq))
                                   + sum(kv $(OnUNet(kv,net)),            Q(t,kv))
                                   - sum(cool2net(ucool,net) $OnU(t,ucool), QCool(t,ucool))
                                   + sum(vak $OnUNet(vak,net),            Q(t,vak))
                                   
                                   #--- # Fratræk varme, som er brugt til opladning af tanke, da den allerede er indeholdt i Q(t,vak).                                     
                                   #--- - sum(tr $(OnTrans(tr)), sum(vak $(OnU(t,vak) and tr2vak(tr,vak)), QT2Vak(t,tr,vak)))
                                   #--- - sum(vak $OnU(t,vak), QUpr2Vak(t,vak))

                                   # DirTrans er +1 for nominel flowretning og -1 for modsat flowretning.
                                   + sum(netT $OnNet(netT),
                                         - sum(tr $OnTransNet(tr,net,netT), DirTrans(tr) * [QT(t,tr) - QTloss(t,tr) * (DirTrans(tr) - 1) / 2 ])    # Varme nominelt afsendt  til netT.
                                         + sum(tr $OnTransNet(tr,netT,net), DirTrans(tr) * [QT(t,tr) - QTloss(t,tr) * (DirTrans(tr) + 1) / 2 ])    # Varme nominelt modtaget fra netT.
                                         )
                                   + (QInfeas(t,net,'source') - QInfeas(t,net,'drain')) $(QInfeasMax GT 0);


# Restriktioner på rampetid

Equation EQ_RampUpMax(tt,upr)   'RampUp begrænsning';
Equation EQ_RampDownMax(tt,upr) 'RampDown begrænsning';

$OffOrder    
# OBS PowInUPrevious er ligesom PowInU angivet i foregående tidspunkts tidsopløsning
#     Tilstande i tidspunktet før planperioden angives på timebasis. BLenRatio(t) afspejler dette, hvor BLenRatio(t) = BLen(t) / BLen(t-1).
#--- EQ_RampUpMax(t,upr)   $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampUp')   LT (1.0 - tiny)) .. PowInU(t,upr) - BLenRatio(t) * [PowInUPrevious(upr) $(ord(t) EQ 1) + PowInU(t-1,upr) $(ord(t) GT 1)]  =L=  +1.01 * min(1.0, 1E-3 + DataU(upr,'RampUp')   * TimeResol(t)) * BLen(t) * PowInUMax(upr) * bOn(t,upr);
#--- EQ_RampDownMax(t,upr) $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampDown') LT (1.0 - tiny)) .. PowInU(t,upr) - BLenRatio(t) * [PowInUPrevious(upr) $(ord(t) EQ 1) + PowInU(t-1,upr) $(ord(t) GT 1)]  =G=  -1.01 * min(1.0, 1E-3 + DataU(upr,'RampDown') * TimeResol(t)) * BLen(t) * PowInUMax(upr) * bOn(t,upr);
EQ_RampUpMax(t,upr)   $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampUp')   LT (1.0 - tiny)) .. PowInU(t,upr) - BLenRatio(t) * [PowInUPrevious(upr) $(ord(t) EQ 1) + PowInU(t-1,upr) $(ord(t) GT 1)]  =L=  +min(1.0, 1E-3 + DataU(upr,'RampUp')   * TimeResol(t)) * BLen(t) * PowInUMax(upr) * bOn(t,upr);
EQ_RampDownMax(t,upr) $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampDown') LT (1.0 - tiny)) .. PowInU(t,upr) - BLenRatio(t) * [PowInUPrevious(upr) $(ord(t) EQ 1) + PowInU(t-1,upr) $(ord(t) GT 1)]  =G=  -min(1.0, 1E-3 + DataU(upr,'RampDown') * TimeResol(t)) * BLen(t) * PowInUMax(upr) * bOn(t,upr);
$OnOrder

*end Produktionsgrænser og varmebalance

*begin Produktionsomkostninger

#--- Equation EQ_FixedDVCostTotal;
#--- Equation EQ_FixedDVCost(upr);
Equation EQ_TaxUpr(tt,upr,tax);
Equation EQ_TaxUpr2(tt,upr,tax);
Equation EQ_TotalTaxUpr(tt,upr);
Equation EQ_FuelCostSR(tt,upsr);
Equation EQ_FuelCost(tt,upr);
Equation EQ_VarDVCostUq(tt,uq);
Equation EQ_VarDVCostKV(tt,kv);
Equation EQ_VarDVCostVAK(tt,vak);
Equation EQ_StartOmkstUpr(tt,upr);
Equation EQ_ElEigen(tt,upr)            'Beregner el-egetforbruget af hver anlæg';
Equation EQ_ElEgbrugOmkst(tt,upr); 
Equation EQ_CO2KvoteOmkst(tt,upr);
Equation EQ_CO2emisUpr(tt,upr,co2kind) 'CO2 emission [kg/h]';
#--- Equation EQ_CO2EmisFuelSum             'Beregner sum af CO2-emission for hvert drivmiddel';
Equation EQ_FuelQty(tt,upr)            'Brændselsmængde [selektiv enhed: L|m3|kg]';

#--- EQ_FixedDVCostTotal ..  FixedDVCostTotal  =E=  sum(u $OnU(t,u), FixedDVCost(u));
#--- EQ_FixedDVCost(upr) ..  FixedDVCost(upr)  =E=  CapQU(upr) * Capex(upr,'fixcost') $OnU(t,upr);

EQ_TotalTaxUpr(t,upr) $(OnU(t,upr)) .. TotalTaxUpr(t,upr)  =E=  sum(tax, TaxProdU(t,upr,tax));

# OBS CO2-kvoteomkostning er ikke en afgift, og håndteres derfor særskilt, også fordi kun samlede anlæg over 20 MWf på samme site er omfattet.
EQ_TaxUpr(t,uq,tax) $(NOT sameas(tax,'ets') AND OnU(t,uq)) ..
              TaxProdU(t,uq,tax)  =E=    sum(f, FuelMix(uq,f) * TaxRateMWh(f,tax,'kedel'))  * PowInU(t,uq) $(NOT hp(uq))
                                       + sum(hp $sameas(hp,uq), TaxRateMWh('Elec',tax,'vp') * PowInU(t,hp)) ;

# Overskudsvarme afgift betales af input-varmen.
EQ_TaxUpr2(t,hp_OV,tax) .. TaxProdU(t,hp_OV,'Oversk') =E= (YS('TaxOverskudsVarme') * 3.6 * PowInU(t,hp_OV) * (COP(t,hp_OV)-1.0)) $OnU(t,hp_OV) ; 


EQ_CO2KvoteOmkst(t,upr) $OnU(t,upr)    ..  CO2KvoteOmkst(t,upr)  =E=  CO2emis(t,upr,'regul') * YS('TaxCO2Kvote') $DataU(upr,'Kvoteomfattet');


# TODO Indsæt bidrag fra overskudsvarmeafgift hvor relevant:  + (YS('TaxOverskudsVarme') * 3.6 * PowInU(t,hp) * (COP(t,hp)-1.0));


# OBS: Variable DV-omkostninger bør beregnes ift. indfyret effekt, som er uafh. af driftsmodus, da fx KV-anlæg har to energi-outputs, men kun ét energi-input. Men her beregnes på basis af varmeproduktionen.
EQ_VarDVCostUq(t,uq)  $(OnU(t,uq))  .. VarDVOmkst(t,uq)   =E=  Q(t,uq) * DataU(uq,'VarDVOmkst');
EQ_VarDVCostVAK(t,vak)                 .. VarDVOmkst(t,vak)  =E=  [DataU(vak,'VAKChargeCost') * QVakAbs(t,vak)]  $OnU(t,vak) ;

# OBS Indført forskel på hvor brændselsprisen hentes. SR-anlæg henter fra Brandsel, mens øvrige termiske anlæg henter prisen fra DataU, fordi prisen kan være anlægsafhængig.

EQ_FuelCostSR(t,upsr) $OnU(t,upsr)     .. FuelCost(t,upsr)   =E=  PowInU(t,upsr) * [sum(f, FuelMix(upsr,f) * (FuelPrice(upsr,f) + TariffFuelMWh(f))       ) $(NOT uelec(upsr))
                                                                                + sum(uelec$sameas(uelec,upsr), TariffElecU(t,uelec) + ElspotActual(t)) $uelec(upsr)   
                                                                                 ];

# OBS Brændselsprisen er angivet på anlægsbasis, da det giver mulighed for at differentiere på brændsels-indkøbsprisen, fx overskudsvarme, hvor prisen er leverandørafhængig.
# Electricitet som drivmiddel omkostningsberegnes på anden vis end brændsler.
# FuelCost har et ekstra bidrag for OV-kilder, idet OV kan være pålagt en pris  DKK/MWhc  per MWh kølevarme.
# Denne kølevarmepris er indsat i tabellen FuelPrice(upr,f) for VP-anlæg, som fødes med OV.
# Dermed kan kølevarmeprisen inddrages, idet den kun gælder for eldrevne anlæg.

# Beregning af kølevarmen fra OV-kilder:  QOV = Q(upr) * (COP - 1) / COP
Positive variable QOV(tt,uov) 'Kølevarme fra OV-kilder';
Equation EQ_QOV(tt,uov)       'Beregning af kølevarme fra OV-kilder';

EQ_QOV(t,uov) $OnU(t,uov) ..  QOV(t,uov)  =E=  Q(t,uov) * sum(hp $sameas(hp,uov), (COP(t,hp) - 1) / COP(t,hp) );


EQ_FuelCost(t,upr) $(OnU(t,upr) AND NOT upsr(upr)) .. FuelCost(t,upr) =E=  PowInU(t,upr) * [ sum(f, FuelMix(upr,f) * (FuelPrice(upr,f) + TariffFuelMWh(f)) ) $(NOT uelec(upr))
                                                                                         + sum(uelec$sameas(uelec,upr), TariffElecU(t,uelec) + ElspotActual(t) ) $uelec(upr) 
                                                                                         ]
                                                                                         + sum(uov $(OnU(t,uov) AND sameas(upr,uov)), sum(f, FuelMix(uov,f) * FuelPrice(uov,f) * QOV(t,uov))) $uov(upr);

EQ_StartOmkstUpr(t,upr) $(OnU(t,upr)) .. StartOmkst(t,upr)   =E=  bStart(t,upr) * DataU(upr,'StartOmkst');

# OBS El-egetforbruget sættes til nul (forsimpling) for små anlæg, og for KV-anlæg antages egetforbruget dækkes af egenproduktion.
#     Der skal betales rådighedstarif af egetforbruget.
#     Det antages for centrale anlæg, at egetforbruget er aktivt, selvom anlægget ikke producerer i en given time, men er til rådighed (startklar).
#     For øvrige anlæg antages, at egetforbruget kun er aktivt, når anlægget er i drift.

EQ_ElEigen(t,upr)       ..  ElEigen(t,upr)        =E=  [BLen(t) * DataU(upr,'ElEig0') * bOn(t,upr) + DataU(upr,'ElEig1') * PowInU(t,upr)] $OnU(t,upr);
EQ_ElEgbrugOmkst(t,upr) ..  ElEgbrugOmkst(t,upr)  =E=  ElEigen(t,upr) * TariffElRaadighedU(upr);

# Regulatorisk og fysisk CO2-emission beregnes for alle produktionsanlæg.
# CO2-indholdet af elektrictet varierer med årsfremskrivningerne.
# TODO Beregning af CO2 emission tager ikke højde for udetid på CC-anlæg.
EQ_CO2emisUpr(t,upr,co2kind) $OnU(t,upr) ..  CO2emis(t,upr,co2kind)   =E=  PowInU(t,upr) * sum(f $(FuelMix(upr,f) GT 0),
                                                                           #--- [FuelMix(upr,f) * Brandsel(f,'CO2EmisMWh') * [Brandsel(f,'FossilAndel') * (1-sum(cc $sameas(upr,cc), uCC(cc))) $sameas(co2kind,'regul') + (1.0 - 0.8 * sum(cc $sameas(upr,cc), uCC(cc))) $sameas(co2kind,'phys')]]  #
                                                                           [FuelMix(upr,f) * Brandsel(f,'CO2EmisMWh') * [Brandsel(f,'FossilAndel') * (1-0) $sameas(co2kind,'regul') + (1.0 - 0.8 * (0)) $sameas(co2kind,'phys')]]  
                                                                           + [YS('CO2ElecMix') $(sameas(f,'elec') AND sameas(co2kind,'phys'))]                  #
                                                                         ) / 1000;

#--- EQ_CO2emisFuelSum(f,co2kind) .. CO2emisFuelSum(f,co2kind)  =E=  sum(upr $OnU(t,upr), sum(t, CO2emis(t,upr,co2kind)) * FuelMix(upr,f) );

#--- EQ_CO2emisFuelSum(f,co2kind) ..  CO2emisFuelSum(f,co2kind)   =E=  sum(upr $(OnU(t,upr) AND (FuelMix(upr,f) GT 0)), sum(t, PowInU(t,upr)) *  
#---                                                                            [FuelMix(upr,f) * Brandsel(f,'CO2EmisMWh') * [Brandsel(f,'FossilAndel') * (1-sum(cc $sameas(upr,cc), uCC(cc))) $sameas(co2kind,'regul') + (1.0 - 0.8 * sum(cc $sameas(upr,cc), uCC(cc))) $sameas(co2kind,'phys')]]  #
#---                                                                            + [YS('CO2ElecMix') $(sameas(f,'elec') AND sameas(co2kind,'phys'))]                  #
#---                                                                          ) / 1000;


# FuelQty er i mængdetype, som er specifik for hvert brændsel: L for olier, m3 for Ngas, kg for faste brændsler, MWh for varme,el.
#--- EQ_FuelQty(t,upr) $OnU(t,upr)  ..  FuelQty(t,upr)  =E=  PowInU(t,upr) / sum(f, FuelMix(upr,f) * Brandsel(f,'LhvMWh')); 
EQ_FuelQty(t,upr) $OnU(t,upr)  ..  FuelQty(t,upr)  =E=  PowInU(t,upr) / sum(f, FuelMix(upr,f) * LhvMWhPerUnitFuel(f)); 

*end Produktionsomkostninger


#--- *begin Solvarme
#--- Equation EQ_Sol(tt,usol);
#--- # TODO Solvarme kan ikke undertrykkes i praksis, kun i en model. Det skal være en =E= restriktion, men det kræver både lager og bortkølingsfacilitet for at undgå infeasibility.
#--- EQ_Sol(t,usol)  $OnU(t,usol)  .. Q(t,usol)  =L=  BLen(t) * Solvarme(t,usol) ;     # Den maksimale solvarmeproduktion i modellen følger tidsserien for den virkelige solvarmeproduktion.
#--- 
#--- *end Solvarme

*begin Ligninger for KV-anlæg

Equation EQ_BypassMax(tt);
Equation EQ_Pbrut(tt,kv);
Equation EQ_Pnet(tt,kv);
Equation EQ_Pback(tt,kv);
Equation EQ_Pbypass(tt,kv);
Equation EQ_QbackMin(tt,kv);
Equation EQ_QbackMax(tt,kv);
Equation EQ_QbypassMin(tt,kv);
Equation EQ_QbypassMax(tt,kv);
#--- Equation EQ_QbypassMaxMin(tt,kv);
#--- Equation EQ_QbypassMaxMax(tt,kv);
Equation EQ_QbypassMaxCost(tt,kv);
Equation EQ_QRgk(tt,kv);
Equation EQ_Qkv(tt,kv);
Equation EQ_QRgk2(tt,kv);

# PQ-punktet modelleres vha. PQ-linjen for modtryk, og mindstelasten fastlægges af Qmin = EtaQ * Fmin.
# Turbine-bypass modelleres som variabelt med en mindstelast på 30 pct.

EQ_BypassMax(t) .. sum(kv $OnU(t,kv), bBypass(t,kv))  =L=  2;

# OBS PQ-diagrammet for KV-anlæggene er givet ved brutto elproduktion Pbrut.

#---EQ_Pbrut(t,kv)           .. Pbrut(t,kv)    =E=  Pback(t,kv) - Pbypass(t,kv) - DataU(kv,'ElEig1') * PowInU(t,kv);  # Proportional-delen af egetforbruget fratrækkes netto-produktionen.
EQ_Pbrut(t,kv)           .. Pbrut(t,kv)    =E=  Pback(t,kv) - Pbypass(t,kv);
EQ_Pnet(t,kv)            .. Pnet(t,kv)     =E=  Pbrut(t,kv) - ElEigen(t,kv);

EQ_Pback(t,kv)           .. Pback(t,kv)    =E=  (BLen(t) * CHP(kv,'a0_PQ') * bOn(t,kv) + CHP(kv,'a1_PQ') * Qback(t,kv)) $OnU(t,kv);
EQ_Pbypass(t,kv)         .. Pbypass(t,kv)  =E=  Qbypass(t,kv);
                         
EQ_QbackMin(t,kv)        .. Qback(t,kv)    =G=  BLen(t) * CHP(kv,'EtaQ') * CHP(kv,'Fmin') * bOn(t,kv) $OnU(t,kv);
EQ_QbackMax(t,kv)        .. Qback(t,kv)    =L=  BLen(t) * CHP(kv,'EtaQ') * CHP(kv,'Fmax') * bOn(t,kv) $OnU(t,kv);
                                                
EQ_QbypassMin(t,kv)      .. Qbypass(t,kv)  =G=  0.20 * BLen(t) * CHP(kv,'Qbypass') * bBypass(t,kv) $OnU(t,kv);
EQ_QbypassMax(t,kv)      .. Qbypass(t,kv)  =L=  1.00 * BLen(t) * CHP(kv,'Qbypass') * bBypass(t,kv) $OnU(t,kv);

EQ_QbypassMaxCost(t,kv)  .. QbypassCost(t,kv) =E= Qbypass(t,kv) * CHP(kv,'DVbypass') $OnU(t,kv);

EQ_QRgk(t,kv) ..  QRgk(t,kv)  =E=  BLen(t) * CHP(kv,'QRGKMax') * bRgk(t,kv) $(OnU(t,kv) AND CHP(kv,'OnRGK'));

# TODO Hvorfor begrænses QRgk af Qback ????
EQ_QRgk2(t,kv) .. QRgk(t,kv) =L= Qback(t,kv);

EQ_Qkv(t,kv)  .. Q(t,kv)  =E= Qback(t,kv) + Qbypass(t,kv) + QRgk(t,kv);

# Synkron drift på eksisterende affaldsanlæg, hvis begge er aktive.
#--- Equation EQ_bOnAffSync(tt)   'Synkron drift på eksist. aff-anlæg';
#--- Equation EQ_QbackAffSync(tt) 'Synkron drift på eksist. aff-anlæg';
#--- Equation EQ_QrgkAffSync(tt)  'Synkron drift på eksist. aff-anlæg';
#--- Equation EQ_QbpAffSync(tt)   'Synkron drift på eksist. aff-anlæg';
#--- 
#--- EQ_bOnAffSync(t)   $(OnU(t,'MaAff1') AND OnU(t,'MaAff2') AND BothAffAvailable(t)) .. bOn(t,'MaAff1')      =E=  bOn(t,'MaAff2');
#--- EQ_QbackAffSync(t) $(OnU(t,'MaAff1') AND OnU(t,'MaAff2') AND BothAffAvailable(t)) .. Qback(t,'MaAff1')    =E=  Qback(t,'MaAff2');
#--- EQ_QrgkAffSync(t)  $(OnU(t,'MaAff1') AND OnU(t,'MaAff2') AND BothAffAvailable(t)) .. Qrgk(t,'MaAff1')     =E=  Qrgk(t,'MaAff2');
#--- EQ_QbpAffSync(t)   $(OnU(t,'MaAff1') AND OnU(t,'MaAff2') AND BothAffAvailable(t)) .. Qbypass(t,'MaAff1')  =E=  Qbypass(t,'MaAff2');

Equation EQ_PowInUCHP(tt,kv);
EQ_PowInUCHP(t,kv)    $(OnU(t,kv))  .. PowInU(t,kv)  =E=  Qback(t,kv) / CHP(kv,'EtaQ');

Equation EQ_ElSales(tt,kv);
EQ_ElSales(t,kv) .. ElSales(t,kv)  =E=  Pnet(t,kv) * (ElspotActual(t) + TariffElSellU(kv)) $ OnU(t,kv);


EQ_VarDVCostKV(t,kv)  $OnU(t,kv)  .. VarDVOmkst(t,kv)   =E=  PowInU(t,kv) * DataU(kv,'VarDVOmkst') + DVOmkstRGK(t,kv);

Equation EQ_TaxProdCHP(tt,kv,tax);
Equation EQ_TaxTotalCHP(tt,kv);
Equation EQ_FuelHeat(tt,kv);

EQ_TaxTotalCHP(t,kv) $(OnU(t,kv))  ..  TotalTaxUpr(t,kv)  =E=  sum(tax, TaxProdU(t,kv,tax));

# Afgiftsberegning for KV-anlæg pånær affaldsanlæg.
EQ_TaxProdCHP(t,kv,tax) $(OnU(t,kv) AND NOT uaff(kv))  ..  TaxProdU(t,kv,tax)   =E=  sum(f, Fuelmix(kv,f) * TaxRateMWh(f,tax,'kv') * PowInU(t,kv)) $taxkv(tax)
                                                                                 + sum(f, Fuelmix(kv,f) * TaxRateMWh(f,tax,'kv') * FuelHeat(t,kv)) $taxkv2(tax);
                                                                                 
#--- E- eller V-formel bruges for KV-anlæg pånær affaldsanlæg.
#--- EQ_FuelHeat(t,kv) $(OnU(t,kv) AND NOT uaff(kv))  .. FuelHeat(t,kv)  =E=  (PowInU(t,kv) - Pnet(t,kv)/0.67) $(TaxEForm(kv) EQ 1) + (Q(t,kv)/1.2) $(TaxEForm(kv) EQ 0);

# E- eller V-formel bruges for KV-anlæg.
EQ_FuelHeat(t,kv) .. FuelHeat(t,kv)  =E=  [(PowInU(t,kv) - Pnet(t,kv)/0.67) $(TaxEForm(kv) EQ 1) + (Q(t,kv)/1.2) $(TaxEForm(kv) EQ 0)] $OnU(t,kv)  ;

Equation EQ_DVOmkstRGK(tt,kv);
EQ_DVOmkstRGK(t,kv) $OnU(t,kv)  .. DVOmkstRGK(t,kv) =E=  QRgk(t,kv) * CHP(kv,'VarDVOmkstRgk');


*begin Gasmotorer
Equation EQ_Taxes1Gm(tt,taxkv,gm);
Equation EQ_Taxes2Gm(tt,gm);
Equation EQ_Taxes3Gm(tt,gm);

EQ_Taxes1Gm(t,taxkv,gm) $OnU(t,gm) ..  TaxProdU(t,gm,taxkv)   =E=  TaxRateMWh('NGas',taxkv,'kv') * PowInU(t,gm);
EQ_Taxes2Gm(t,gm) $OnU(t,gm)       ..  TaxProdU(t,gm,'enr')   =E=  TaxRateMWh('NGas','enr','kv') * sum(kv $sameas(kv,gm), FuelHeat(t,kv));
EQ_Taxes3Gm(t,gm) $OnU(t,gm)       ..  TaxProdU(t,gm,'co2')   =E=  TaxRateMWh('NGas','co2','kv') * sum(kv $sameas(kv,gm), FuelHeat(t,kv));
*end Gasmotorer



*begin Affaldsanlæg

# Afgiftsberegning for affaldsanlæg er mere kompliceret end for øvrige typer produktionsanlæg. Dertil håndteres beregningen særskilt her.
# Der er kun ét affaldsanlæg (SoAffald) i modellen med tilhørende RGK og bortkøleanlæg (SoCool)

Positive variable AffQLev(tt,uaff)                'Leveret varme fra affaldsanlæg';
Positive variable AffQVarmeAfg(tt,uaff)           'Varmemængde som pålægges affaldvarmeafgift';
Positive variable AffQcool(tt,uaff)               'Varmemængde bortkølet fra affaldsanlæg';
Positive variable AffQP(tt,uaff)                  'Sum af varme og elproduktion på affaldsanlæg inkl. RGK-varme';
Positive variable AffF(tt,uaff)                   'Varmemængde hvoraf der skal svares tillægsafgift';
Positive variable AffTaxVarme(tt,uaff)            'Varmeafgift affald';
Positive variable AffTaxTill(tt,uaff)             'Tillægsafgift affald';
Positive variable AffTaxCO2(tt,uaff)              'CO2 afgift affald';
Positive variable AffTaxNOx(tt,uaff)              'NOx afgift affald';
Positive variable AffTaxSOx(tt,uaff)              'SOx afgift affald';
Positive variable AffCO2KvoteOmkst(tt,uaff);
Positive variable AffCO2KvoteOmkstHeat(tt,uaff);
Positive variable FuelQtyHeat(tt,uaff)            'Brændselsmængde til varme [ton/h]';
Positive variable CO2emisHeat(tt,uaff)            'CO2 emission ifm varmeproduktion [ton/h]';
#--- Positive variable CO2emis(tt,uaff);

# Sikring af at hovedanlæg er i drift for tilknyttet RGK-anlæg.
Equation EQ_RGKpremis(tt,kv)  'Sikring af hovedanlæg i drift for RGK';
EQ_RGKpremis(t,kv) $OnU(t,kv) .. bOn(t,kv)  =L=  bOnRGK(t,kv);

#--- Equation EQ_BypassCC(tt,uaff) 'Bypass skal være slukket når CC er tændt';
#--- EQ_BypassCC(t,uaff)  .. bBypass(t,'MaNAff') =L= 1 - sum(cc $sameas(uaff,cc), uCC(cc));


*begin Omkostningsallokering til varme- hhv. affaldssiden.

#HACK
#--- Positive variable AffTaxRabat(tt,uaff)            'Rabat på tillægsafgiften';
#--- Positive variable AffCostShared(tt,uaff)          'Fællesomkostninger varme+affaldssiden';
#--- Positive variable AffTotalCostVarmeSide(tt,uaff)  'Omkostn. allokeret varmesiden';
#--- Positive variable AffTotalCostAffaldSide(tt,uaff) 'Omkostn. allokeret affaldssiden';

#--- Equation EQ_AffCostShared(tt,uaff)             'Fællesomkostninger';
#--- Equation EQ_AffTotalCostVarmeSide(tt,uaff)     'Omkostninger til varmesiden';
#--- Equation EQ_AffTotalCostAffaldSide(tt,uaff)    'Omkostninger til affaldssiden';

#--- Equation EQ_DbEgTransAffald(tt,uaff)           'Energnist, omkostninger ifm transport+omlastning+sæsonlagring af affald';
#--- Equation EQ_DbEgAffald(tt,uaff)                'Energnist, indtægt fra affald';


Equation EQ_AffTotalTax(tt,uaff)               'Total afgifter for Egn';
Equation EQ_AffTax(tt,uaff,tax)                'Afgiftselementer for affaldsanlæg';

EQ_AffTotalTax(t,uaff) $OnU(t,uaff)  .. TotalTaxUpr(t,uaff)    =E=  [AffTaxVarme(t,uaff) + AffTaxTill(t,uaff) + AffTaxCO2(t,uaff) + AffTaxNOx(t,uaff) + AffTaxSOx(t,uaff)];

EQ_AffTax(t,uaff,tax) $OnU(t,uaff) .. TaxProdU(t,uaff,tax)  =E=  AffTaxVarme(t,uaff) $sameas(tax,'afv') +
                                                               AffTaxTill(t,uaff)  $sameas(tax,'atl') +
                                                               AffTaxCO2(t,uaff)   $sameas(tax,'co2') +
                                                               AffTaxNOx(t,uaff)   $sameas(tax,'nox') +
                                                               AffTaxSOx(t,uaff)   $sameas(tax,'sox') ;


#--- EQ_AffCostShared(t,uaff) $OnU(t,uaff) ..  AffCostShared(t,uaff)  =E= [ VarDVOmkst(t,uaff) + StartOmkst(t,uaff)   #---  + ElEgbrugOmkst(t,uaff)  - ElEgbrugOmkstRGK(t,uaff)
#---                                                                   + CO2KvoteOmkst(t,uaff) + AffTaxNOx(t,uaff) + AffTaxSOx(t,uaff) ];  #---  + TransCostAffald(t,uaff)
#--- EQ_AffTotalCostVarmeSide(t,uaff) $OnU(t,uaff) ..  AffTotalCostVarmeSide(t,uaff)  =E= [ DataAff('AndelVarmeSiden',uaff) * AffCostShared(t,uaff)
#---                                                                                     + AffTaxVarme(t,uaff) + DVOmkstRGK(t,uaff)   #---   + ElEgbrugOmkstRGK(t,uaff) + AffAfgiftogElTabRGK(t,uaff)
#---                                                                                    ] ;
#--- EQ_AffTotalCostAffaldSide(t,uaff)  $OnU(t,uaff) .. AffTotalCostAffaldSide(t,uaff) =E= [DataAff('AndelAffaldSiden',uaff) * AffCostShared(t,uaff)
#---                                                                                    + AffTaxTill(t,uaff) + AffTaxCO2(t,uaff)
#---                                                                                    ];

*end

Equation EQ_QAffLev(tt,uaff);
Equation EQ_QAffTaxVarme(tt,uaff);
Equation EQ_AffTaxVarme(tt,uaff);
Equation EQ_AffQcool(tt,uaff);
Equation EQ_AffQP(tt,uaff);
Equation EQ_AffF(tt,uaff);
Equation EQ_QCoolMax(tt,ucool);

EQ_QAffLev(t,uaff) $OnU(t,uaff)      .. AffQLev(t,uaff)       =E=  Q(t,uaff) - AffQcool(t,uaff);
EQ_QAffTaxVarme(t,uaff) $OnU(t,uaff) .. AffQVarmeAfg(t,uaff)  =E=  AffQLev(t,uaff) - DataAff('FrakAux',uaff) * 0.85 * AffAux(uaff) * PowInU(t,uaff);

EQ_AffQcool(t,uaff) $OnU(t,uaff)     .. AffQcool(t,uaff)      =E=  sum(ucool $(OnU(t,ucool) AND aff2cool(uaff,ucool)), QCool(t,ucool));
EQ_QCoolMax(t,ucool) $OnU(t,ucool)   .. QCool(t,ucool)        =L=  BLen(t) * CapQU(ucool) $OnU(t,ucool);

EQ_AffQP(t,uaff) $OnU(t,uaff)        .. AffQP(t,uaff)         =E=  Q(t,uaff) + Pnet(t,uaff); # remove  + sum(urgk $aff2rgk(uaff,urgk), Q(t,urgk));
EQ_AffF(t,uaff)  $OnU(t,uaff)        .. AffF(t,uaff)          =E=  Q(t,uaff) * (1 - DataAff('FrakAux',uaff));                                          # Tillægsafgift beregnes kun af Q, hvorimod rabat regnes på Q+Pbrut (EY).
EQ_AffTaxVarme(t,uaff) $OnU(t,uaff)  .. AffTaxVarme(t,uaff)   =E=  AffQVarmeAfg(t,uaff) * TaxRateMWh('Affald','afv','kv');

# OBS Tillægsafgiften refererer til brutto-elproduktion. I nærværende model beregnes kun netto elproduktion, idet egetforbruget ignoreres.
# OBS I denne forenklede model antages rabatten at kunne oppebæres i alle måneder.
# Beregning af tillægsafgiften og rabat på RGK-varmens tillægsafgift.

Equation EQ_AffTaxTill(tt,uaff);

EQ_AffTaxTill(t,uaff) $OnU(t,uaff)  .. AffTaxTill(t,uaff)   =E=  AffF(t,uaff) * DataAff('FrakTLafgift',uaff) * TaxRateMWh('Affald','atl','kv') * (1 - YS('TaxAffaldRGKRabat'));

Equation EQ_AffTaxCO2(tt,uaff);
Equation EQ_AffTaxNOx(tt,uaff);
Equation EQ_AffTaxSOx(tt,uaff);
Equation EQ_AffCO2emisHeat(tt,uaff);
Equation EQ_AffFuelQtyHeat(tt,uaff);
Equation EQ_AffCO2KvoteOmkst(tt,uaff);
Equation EQ_AffCO2KvoteOmkstHeat(tt,uaff);

EQ_AffTaxCO2(t,uaff) $OnU(t,uaff)  .. AffTaxCO2(t,uaff)  =E=  YS('TaxAffaldCO2') * CO2emisHeat(t,uaff) * DataAff('FrakCO2Afgift',uaff);
EQ_AffTaxNOx(t,uaff) $OnU(t,uaff)  .. AffTaxNOx(t,uaff)  =E=  YS('TaxNOx') * FuelQty(t,uaff) / 1000 * DataAff('NOxEmission',uaff) * DataAff('FrakNOxAfgift',uaff);
EQ_AffTaxSOx(t,uaff) $OnU(t,uaff)  .. AffTaxSOx(t,uaff)  =E=  YS('TaxSOx') * FuelQty(t,uaff) / 1000 * DataAff('SOxEmission',uaff) * DataAff('FrakSOxAfgift',uaff);

EQ_AffCO2emisHeat(t,uaff) $OnU(t,uaff) .. CO2emisHeat(t,uaff)  =E=  FuelHeat(t,uaff) * Brandsel('Affald','CO2EmisMWh') / 1000;  # Omregning fra kgCO2/MWf til tonCO2/MWf.
EQ_AffFuelQtyHeat(t,uaff) $OnU(t,uaff) .. FuelQtyHeat(t,uaff)  =E=  FuelHeat(t,uaff) / [Brandsel('Affald','LHV') / 3.6];  # FuelQtyHeat er ton affald medgået til varmeproduktion.

* Beregning af CO2-kvoteomkostninger pålagt ved indvejning af affaldet.
EQ_AffCO2KvoteOmkst(t,uaff) $OnU(t,uaff)     .. AffCO2KvoteOmkst(t,uaff)      =E=  YS('TaxCO2Kvote') * CO2emis(t,uaff,'regul');
EQ_AffCO2KvoteOmkstHeat(t,uaff) $OnU(t,uaff) .. AffCO2KvoteOmkstHeat(t,uaff)  =E=  YS('TaxCO2Kvote') * CO2emisHeat(t,uaff) $OnU(t,uaff);

*end Affaldsanlæg

*end Ligninger for KV-anlæg

*begin Ligninger for VAK

Equation EQ_QVakAbs1(tt,vak);
Equation EQ_QVakAbs2(tt,vak);
Equation EQ_QvakMinSR(tt,netq,vak);
Equation EQ_VakLoss(tt,vak);
Equation EQ_LVak(tt,vak);
Equation EQ_LoadMinVak(tt,vak);
Equation EQ_LoadMaxVak(tt,vak);
Equation EQ_MinVak(tt,vak);
Equation EQ_MaxVak(tt,vak);
#remove Equation EQ_FixVak(tt,vak);

Equation EQ_LVakMax(tt,vak);
Equation EQ_dLVakMax(tt,vak);

* Først beregnes den absolutte laderate QVakAbs.
EQ_QVakAbs1(t,vak) ..   Q(t,vak)  =L=  QVakAbs(t,vak) $(OnU(t,vak));
EQ_QVakAbs2(t,vak) ..  -Q(t,vak)  =L=  QVakAbs(t,vak) $(OnU(t,vak));

# Forebyg opladning af decentrale tanke, når spidslastanlæg er aktive.
EQ_QvakMinSR(t,netq,vak) $(OnNet(netq) AND OnU(t,vak) AND vaknet(vak,netq)) .. Q(t,vak)  =G=  - BLen(t) * CapQU(vak) * (1 - bOnSR(t,netq));

* Beregning af Q lagret i VAK
$OffOrder

EQ_VakLoss(t,vak) $(OnU(t,vak))  .. VakLoss(t,vak)  =E=  BLen(t) * DataU(vak,'VakLossRate') * DataU(vak,'LossGain') * LVak(t,vak);
EQ_LVak(t,vak)    $(OnU(t,vak))  .. LVak(t,vak)     =E=  [LVakPrevious(vak) $(ord(t) EQ 1) + LVak(t--1,vak) $(ord(t) GT 1)] - Q(t,vak) - VakLoss(t,vak);

$OnOrder

* Max/min lade-/afladegradient i VAK
EQ_LoadMinVak(t,vak) $OnU(t,vak)  .. Q(t,vak)   =G=  - BLen(t) * CapQU(vak) * DataU(vak,'LoadRateVak')  $(OnU(t,vak))  ;
EQ_LoadMaxVak(t,vak) $OnU(t,vak)  .. Q(t,vak)   =L=    BLen(t) * CapQU(vak) * DataU(vak,'LoadRateVak')  $(OnU(t,vak))  ;

* Max VAK-energiindhold
EQ_MaxVak(t,vak)  $(OnU(t,vak))   .. LVak(t,vak)  =L=  CapQU(vak) * DataU(vak,'VakMax');
EQ_MinVak(t,vak)  $(OnU(t,vak))   .. LVak(t,vak)  =G=  CapQU(vak) * DataU(vak,'VakMin');

# Bestemmelse af hvem der må lade på tanken:
# Settet upr2vak fastlægger hvilke anlæg som kan lade på hvilke vak.
# Settet tr2vak  fastlægger hvilke T-ledninger som kan lade på hvilke vak.

#--- EQ_LVakMax(t,vak)  $OnU(t,vak)  ..  QMaxVak(t,vak)  =E=  sum(upr2vak(upr,vak) $OnU(t,upr), Q(t,upr));

# OBS Hver T-ledning kan kun lade på een vak jf. nedenstående ligning:
EQ_LVakMax(t,vak)  $OnU(t,vak)  ..  QMaxVak(t,vak)  =E=  sum(upr2vak(upr,vak) $OnU(t,upr),    Q(t,upr)) + 
                                                         sum(tr2vak(tr,vak)   $OnTrans(tr), QT(t,tr));
$OffOrder

# VAK-beholdningens tilvækst er begrænset af den maksimale laderate.
EQ_dLVakMax(t,vak) $(OnU(t,vak))  ..  LVak(t,vak)  =L=  [LVakPrevious(vak) $(ord(t) EQ 1) + LVak(t--1,vak) $(ord(t) GT 1)] + QMaxVak(t,vak);

$OnOrder

*end Ligninger for VAK

*begin Transmission

# Struers ejerandel er aktiv øvre grænse, når Holstebro har aktive SR-anlæg.
# Reglen er, at Struer må trække mere transmissionsvarme end ejerandelen tilsiger,
# hvis Holstebro ikke udnytter sin andel.
# Hvis Holstebros SR-anlæg er aktiv, så tolkes det som at Holstebro udnytter sin andel. 
# Modtryksvarme og røggasvarme og bypassvarme medregnes i grundlastvarmen.
# Men også afladet effekt fra BHP-tanke kan tælles med.
# Hvis det i stedet for overlades til at være en omkostningsstyret balancering,
# svarende til et fælles ejerskab, så behøves ingen begrænsning ift. ejerandelen.
# Men der er netop 2 ejere, så derfor skal grænsen kunne aktiveres.
# Hvis Holstebros SR-anlæg aktiveres, så indebærer det, at tanke ikke kan levere varme nok til Holstebro (cost-drevet).
# Dermed er det et rimeligt kriterium, at Struers T-varme i den situation begrænses til ejerandelen.
# Men ejerandels-begrænsningen skal være symmetrisk så Holstebro må heller ikke overtrække på grundlastvarmen.
# Så hvis Struers SR-anlæg er aktiveret, må Holstebro heller ikke overskride sin andel af grundlastvarmen.
# Grundlastvarmen er den øjeblikkelige sum af KV-anlæggenes modtryks-, røggas- og bypass-varme.
# Grundlastvarmen erdynamisk, og dermed påvirkelig, så den kan øges fx ved aktivering af bypass.
#
# ERRATUM:
# Hvis SR er aktiv i Struer, men ikke i Holstebro, så må Struer trække mere på T-ledningen.
# Hvis SR er aktiv i Holstebro, men ikke i Struer, så er der ikke varme på BHP-tankene (idet SR ellers ikke ville være nødvendigt),
# og så skal Struer begrænses til sin ejerandel af grundlastvarmen.
# Hvis SR er aktiv i begge byer, så skal begge byer begrænses til deres respektive ejerandel.
# Andelene tages i så fald af den maksimalt rådige grundlastvarme. 
# Hvis SR er aktiv kun i Holstebro, så har Struer varme på tanken, og omvendt.

Equation EQ_bOnSRHoMin(tt)    'Bestem SR-aktivitet i Ho';
Equation EQ_bOnSRStMin(tt)    'Bestem SR-aktivitet i St';
Equation EQ_bOnSRHoMax(tt)    'Bestem SR-aktivitet i Ho';
Equation EQ_bOnSRStMax(tt)    'Bestem SR-aktivitet i St';
Equation EQ_QTmaxHo(tt)       'Holstebros ejerandel begrænset når SR er aktiv i Struer';
Equation EQ_QTmaxSt(tt)       'Struers ejerandel begrænset når SR er aktiv i Holstebro';
Equation EQ_QTmin(tt,tr)      'Min. transmitteret effekt [MWq]';
Equation EQ_QTmax(tt,tr)      'Max. transmitteret effekt [MWq]';

# Bestem om der er SR-aktivitet i de reale forsyningsområder.
EQ_bOnSRHoMin(t) $(card(urHo) GT 0)   .. bOnSR(t,'netHo')  =G=  sum(urHo $OnU(t,urHo), bOn(t,urHo)) / card(urHo);
EQ_bOnSRStMin(t) $(card(urSt) GT 0)   .. bOnSR(t,'netSt')  =G=  sum(urSt $OnU(t,urSt), bOn(t,urSt)) / card(urSt);
EQ_bOnSRHoMax(t)                      .. bOnSR(t,'netHo')  =L=  sum(urHo $OnU(t,urHo), bOn(t,urHo));
EQ_bOnSRStMax(t)                      .. bOnSR(t,'netSt')  =L=  sum(urSt $OnU(t,urSt), bOn(t,urSt));


Equation EQ_Qbase(tt)                    'Beregner Grundlastvarmeproduktion';
Equation EQ_Qbase_bOnSr_2_Min(tt,netq)   'Bruges til at danne produktet Qbase * bOnSR';
Equation EQ_Qbase_bOnSr_2_Max(tt,netq)   'Bruges til at danne produktet Qbase * bOnSR';
Equation EQ_Qbase_bOnSr_1_Max(tt,netq)   'Bruges til at danne produktet Qbase * bOnSR';

# Qbase har en øvre grænse QbaseMaxAll.
EQ_Qbase(t)                   ..  Qbase(t)                       =E=  sum(uprbase $(OnU(t,uprbase) AND DataU(uprbase,'Omraade') EQ NetId('netMa')), Q(t,uprbase));
EQ_Qbase_bOnSr_1_Max(t,netq)  ..  QbasebOnSR(t,netq)             =L=  BLen(t) * QbaseMaxAll * bOnSR(t,netq);
EQ_Qbase_bOnSr_2_Min(t,netq)  ..  0                              =L=  Qbase(t) - QbasebOnSR(t,netq);
EQ_Qbase_bOnSr_2_Max(t,netq)  ..  Qbase(t) - QbasebOnSR(t,netq)  =L=  BLen(t) * QbaseMaxAll * (1 - bOnSR(t,netq));

# TODO Feature med OnTrans (se nedenfor) skal indlægges her.
# QT ved aktive SR-anlæg er begrænset af ejerandel af grundlastvarmeproduktion tillagt afladeraten fra tilsluttede tanke.
# Derudover er der en flowbetinget grænse og begge grænser skal være aktive.

EQ_QTmaxHo(t) $OnOwnerShare   ..  QT(t,'tr2')  =L=  (1 - Diverse('StruerAndel')) * QbasebOnSR(t,'netSt') 
                                                    + BLen(t) * sum(vak $(OnU(t,vak) AND vak2tr(vak,'tr2')), CapQU(vak) * DataU(vak,'LoadRateVak')) 
                                                    + BLen(t) * QTmax('tr2') * (1 - bOnSR(t,'netSt'));
                                                    
EQ_QTmaxSt(t) $OnOwnerShare   ..  QT(t,'tr1')  =L=  (    Diverse('StruerAndel')) * QbasebOnSR(t,'netHo') 
                                                    + sum(vak $(OnU(t,vak) AND vak2tr(vak,'tr1')), CapQU(vak) * DataU(vak,'LoadRateVak')) 
                                                    + QTmax('tr1') * (1 - bOnSR(t,'netHo'));

# OBS En T-ledning hvor OnTrans er forskellig fra 1.0 (én), skal anvende tallet i OnTrans som nedre kapacitetsgrænse [MWq].
EQ_QTmin(t,tr) $(OnTrans(tr) NE 1.0)   .. QT(t,tr)  =G=  BLen(t) * min(OnTrans(tr), QTmin(tr)) * bOnT(t,tr);
EQ_QTmax(t,tr) $(OnTrans(tr) EQ 1.0)   .. QT(t,tr)  =L=  BLen(t) * QTmax(tr) * bOnT(t,tr) $OnTrans(tr);


# Rådig grundlastvarme gøres afhængig af SR-aktivitet og ejerandel.
#--- Positive variable Qbase(tt)      'Grundlastvarme fra KV-anlæg';
#--- Positive variable QbaseHo(tt)    'Grundlastvarme til rådighed for Holstebro';
#--- Positive variable QbaseSt(tt)    'Grundlastvarme til rådighed for Struer';
#--- Equation EQ_Qbase(tt)            'Bestem fælles rådig grundlastvarme';
#--- Equation EQ_QbaseHo(tt)          'Bestem loft for rådig grundlastvarme for Ho';
#--- Equation EQ_QbaseSt(tt)          'Bestem loft for rådig grundlastvarme for St';
#--- Equation EQ_QbaseMaxHo(tt)       'Begræns rådig grundlastvarme hvis SR-aktive i St';
#--- Equation EQ_QbaseMaxSt(tt)       'Begræns rådig grundlastvarme hvis SR-aktive i Ho';
#--- EQ_Qbase(t)      ..  Qbase(t)       =E=  sum(kv $OnU(t,kv), Q(t,kv));
#--- EQ_QbaseHo(t)    ..  QbaseMaxHo(t)  =L=  (1 - Diverse('StruerAndel')) * Qbase(t); 
#--- EQ_QbaseSt(t)    ..  QbaseMaxSt(t)  =L=  Diverse('StruerAndel') * Qbase(t); 
#--- EQ_QbaseMaxHo(t) ..  QbaseMaxHo(t)  =L=  QbaseMaxAll * bOnSR(t,'netSt');
#--- EQ_QbaseMaxSt(t) ..  QbaseMaxSt(t)  =L=  QbaseMaxAll * bOnSR(t,'netHo');
#--- EQ_QTmaxHo(t)    ..  QT(t,'tr2')    =L=  QbaseMaxHo(t) + QTmax('tr2') * (1 - bOnSR(t,'netSt'));
#--- EQ_QTmaxSt(t)    ..  QT(t,'tr1')    =L=  QbaseMaxSt(t) + QTmax('tr1') * (1 - bOnSR(t,'netHo'));


Equation EQ_varmetabT(tt,tr)  'Varmetab i T-ledning';
Equation EQ_CostPump(tt,tr)   'Pumpeomkostninger [DKK]';
#remove Equation EQ_CapexTrans(tr);
#remove Equation EQ_CapexPump(tr);

# Varmetabs-eksempel på Aa til Ha med DN250: Cirka 0,43 MW for fremløb og 0,17 MW for retur.
# Varmetabet er domineret af temperaturer, flowets indflydelse er af 2. orden og negligeres her.
EQ_varmetabT(t,tr)  $(OnTrans(tr)) .. QTloss(t,tr)   =E=  BLen(t) * ([1.0 - exp(-alphaT(t,tr,'frem'))] * QTmax(tr) +  [1.0 - exp(-alphaT(t,tr,'retur'))] * QTmax(tr));

#OBS  Pumpearbejdet er reelt proportionalt med QT^2, hvis modstandsfaktoren fD antages konstant (forudsætter højt minimum på QT).
#HACK Linearisering af pumpeomkostninger: WpumpActual(t,tr) := Wpump(tr) * CostElecT(t) * QT(t,tr) / QTmax(tr);
EQ_CostPump(t,tr)   $OnTrans(tr)   .. CostPump(t,tr)  =E=  Wpump(tr) * [ ElspotActual(t) + TariffEigenPump(t) ] * QT(t,tr) / QTmax(tr);   # [DKK]

*end




*begin Slave model declaration

model modelSlave / all /;

*end Slave model declaration




#)


