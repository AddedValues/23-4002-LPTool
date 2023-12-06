$log Entering file: %system.incName%
#(
$OnText
Projekt:    23-4002 LP MEC BHP - Fremtidens fjernvarmeproduktion
Filnavn:    DeclareSlave.gms
Scope:      Definerer fælles / tværgående sets, parameters, variables, equations for slavemodellen.
Kaldes af:  gams.exe
Dato:       2020-01-18 13:09
Inkluderes af:  MecLpMain.gms
$OffText
    

*begin Sets og parametre.


*begin Variables

Free     variable       zSlave                       'Slave objective';
Positive variable       QSales(tt)                   'Varmesalg [DKK]';
Positive variable       QeInfeas(tt,net,InfeasDir)    'Virtuelle varmekilder og -dræn [MW]';
                        
Positive variable       TotalCO2Emis(tt,net,co2kind) 'Samlede regulatoriske CO2-emission [ton/h]';
Positive variable       TotalCO2EmisSum(net,co2kind) 'Sum af regulatorisk CO2-emission [ton]';
Positive variable       CO2KvoteOmkst(tt,upr)        'CO2 kvote omkostning [DKK]';

# TODO For samme type flow, fx Qf, VarDVOmkst, skal der ikke skelnes mellem produktionsanlæg og KV-anlæg på variabel-siden.

Free variable           Qe(tt,u)                     'Heat energy from unit u [MWhq]';
Free variable           Qf(tt,u)                     'Heat flow from unit u [MWq]';
Free variable           FuelCost(tt,upr)             'Fuel cost til el bliver negativ, hvis elprisen gaar i negativ';
Free variable           TariffCost(tt,upr)           'Fuel tarif cost';
Free variable           TotalCostU(tt,u);        
Free variable           TotalElIncome(tt,kv);    
Free variable           ElSales(tt,kv)               'Indtægt fra elsalg';
# REMOVE Positive variable       TariffEl(tt,upr)             'Eltarif på elektrisk drevne anlæg';
# REMOVE Free variable           ElTilskud(tt,kv);   

*begin Transmission

Positive variable       QTe(tt,tr)                  'Transmitteret varmeenergi [MWhq]';
Positive variable       QTf(tt,tr)                  'Transmitteret varmeeffekt [MWq]';
Positive variable       QTeLoss(tt,tr)               'Transmissionsvarmetab [MWq]';
# remove Positive variable       QTransOmkst(tt,netF,netT);

Free     variable       CostPump(tt,tr)             'Pumpeomkostninger';
Binary   variable       bOnT(tt,tr)                 'On/off timetilstand for T-ledninger';
Binary   variable       bOnTAll(tr)                 'On/off årstilstand for T-ledninger';

*end

Positive variable       Fe(tt,upr)                 'Indgivet energi [MWhf]';
Positive variable       Ff(tt,upr)                 'Indgivet effekt [MWf]';
Positive variable       StartOmkst(tt,upr)         'Startomkostning [DKK]';

Positive variable       CostPurchaseOV(tt,uov)     'Købsomkostning OV [DKK]';
Free     variable       ElEgbrugOmkst(tt,upr)      'Egetforbrugsomkostning [DKK]';
Positive variable       VarDVOmkst(tt,u);
Positive variable       DVOmkstRGK(tt,kv)          'D&V omkostning relateret til RGK [DKK]';
Positive variable       DVOmkstBypass(tt,kv)       'D&V omkostning relateret til bypass [DKK]';
Positive variable       CostInfeas(tt,net)         'Infeasibility omkostn. [DKK]';
Positive variable       CostSrPenalty(tt,net)      'Penalty paa SR-varme [DKK]';
Positive variable       RewardBurnWaste(tt)        'Belønning for afbrændt affald [DKK]';
Positive variable       TaxProdU(tt,upr,tax);
Positive variable       TotalTaxUpr(tt, upr);
Positive variable       CO2Emis(tt,upr,co2kind)    'CO2 emission [kg]';

Positive variable       FuelQty(tt,upr)            'Drivmiddelmængde [ton]';
Positive variable       FeHeat(tt,kv)            'Brændselsenergi knyttet til varmeproduktion i KV-anlæg [MWhf]';
Positive variabLe       ElEigenE(tt,upr)            'El-egetforbrug for hvert anlæg';

Positive variable       PfBrut(tt,kv)              'Brutto elproduktion på kraftvarmeværker [MWhe]';
Positive variable       PfNet(tt,kv)               'Netto elproduktion på kraftvarmeværker [MWe]';
Positive variable       PfBack(tt,kv);
Positive variable       PfBypass(tt,kv);
Positive variable       QfBack(tt,kv);
Positive variable       QfBypass(tt,kv);
Positive variable       QfRgk(tt,kv);
Positive variable       QeBack(tt,kv);
Positive variable       QeBypass(tt,kv);
Positive variable       QeRgk(tt,kv);
Positive variable       QbypassCost(tt,kv);

binary   variable       bBypass(tt,kv);
binary   variable       bRgk(tt,kv);
Binary   variable       bOn(tt,upr)                'On/off variable for all units';
Binary   variable       bStart(tt,upr)             'Indikator for start af prod unit';
Binary   variable       bOnRGK(tt,kv)              'Angiver om RGK-anlæg er i drift';
Binary   variable       bOnSR(tt,netq)             'On/off på SR-anlæg i reale forsyningsområder';

# Overskudsvarme
Positive variable QfOV(tt,uov) 'Kølevarmeeffekt fra OV-kilder [MWqo]';
Positive variable QeOV(tt,uov) 'Kølevarmeenergi fra OV-kilder [MWhqo]';

# VAK
Positive variable       Evak(tt,vak)               'Ladning på vak [MWh]';
Positive variable       EvakLoss(tt,vak)           'Storage loss per hour';
Positive variable       QfMaxVak(tt,vak)           'Øvre grænse på opladningseffekt';
Positive variable       QfVakAbs(tt,vak)            'Absolut laderate for beregning af ladeomkostninger [MW]';
#--- Positive variable       QUpr2Vak(tt,vak)           'Indfødet varme fra alle prod-anlæg til vak';
#--- Positive variable       QT2Vak(tt,tr,vak)          'Indfødet varme fra hver T-ledning til vak';

# Begrænsning på ejerandel af grundlastvarmen.
Positive variable       QeBase(tt)                  'Grundlastvarmeproduktion energi';
Positive variable       QfBase(tt)                  'Grundlastvarmeproduktion effekt';
Positive variable       QfBasebOnSR(tt,netq)        'Product af QfBase og bOnSR';



*begin Kapacitetsallokeringer
Positive variable       CapEAlloc(tt,uelec,dirResv)    'Kapacitetsallokeringer på anlægsbasis';
Positive variable       CapESlack(tt,dirResv)          'Kapacitetsallokerings slack ift. diskret størrelse';
Positive variable       CapEAllocSumU(tt,dirResv)      'Kapacitetsallokering summeret over anlæg';
Positive variable       CostCapESlack(tt,dirResv)      'Penalty cost på CapESlack';

Equation EQ_CapEAllocConsDown(tt,uelcons) 'Reserverer nedregul. kapac. for elforbrug. anlæg';
Equation EQ_CapEAllocConsUp(tt,uelcons)   'Reserverer opregul.  kapac. for elforbrug. anlæg';
Equation EQ_CapEAllocProdDown(tt,uelprod) 'Reserverer nedregul. kapac. for elprod. anlæg';
Equation EQ_CapEAllocProdUp(tt,uelprod)   'Reserverer opregul.  kapac. for elprod. anlæg';

# CapEU er den øjeblikkelige max. kapacitet: FinFMax / COP for elforbrugende anlæg, og PfNet(t) for elproducerende anlæg
# remove EQ_CapEAllocConsUp(t,uelcons)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'up'))   .. Ff(t,uelcons)                            =G=  BLen(t) * CapEAlloc(t,uelcons,'up');
# remove EQ_CapEAllocConsDown(t,uelcons) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'down')) .. Ff(t,uelcons)                            =L=  BLen(t) * (CapEU(t,uelcons) - CapEAlloc(t,uelcons,'down'));
# remove EQ_CapEAllocProdUp(t,uelprod)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'up'))   .. sum(kv $sameas(kv,uelprod), PfNet(t,kv))  =L=  BLen(t) * (CapEU(t,uelprod) - CapEAlloc(t,uelprod,'up'));
# remove EQ_CapEAllocProdDown(t,uelprod) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'down')) .. sum(kv $sameas(kv,uelprod), PfNet(t,kv))  =G=  BLen(t) * CapEAlloc(t,uelprod,'down');

EQ_CapEAllocConsUp(t,uelcons)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'up'))   .. Ff(t,uelcons)                           =G=  CapEAlloc(t,uelcons,'up');
EQ_CapEAllocConsDown(t,uelcons) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'down')) .. Ff(t,uelcons)                           =L=  (CapEU(t,uelcons) - CapEAlloc(t,uelcons,'down'));
EQ_CapEAllocProdUp(t,uelprod)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'up'))   .. sum(kv $sameas(kv,uelprod), PfNet(t,kv))  =L=  (CapEU(t,uelprod) - CapEAlloc(t,uelprod,'up'));
EQ_CapEAllocProdDown(t,uelprod) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'down')) .. sum(kv $sameas(kv,uelprod), PfNet(t,kv))  =G=  CapEAlloc(t,uelprod,'down');

Equation EQ_CapEAllocSum(tt,dirResv)       'Beregner CapEAllocSumU';
EQ_CapEAllocSum(t,dirResv) $(OnCapacityReservation AND IsBidDay(t)) .. CapEAllocSumU(t,dirResv)  =E=  sum(uelec $OnU(t,uelec), CapEAlloc(t,uelec,dirResv));

Equation EQ_AllocReservMatch(tbid,tt,dirResv)  'Sikrer match mellem allok. og reservation';
# TODO CHECK om skalering med BLen er korrekt her.
EQ_AllocReservMatch(tbid,tt,dirResv) $(OnCapacityReservation AND ord(tbid) LE HoursBidDay AND IsBidDay(tt) AND tt2tbid(tt,tbid)) .. 
                                         CapEAllocSumU(tt,dirResv) + CapESlack(tt,dirResv)  =E=  BLen(tt) * sum(elmarket $DataElMarket('Active',elmarket), CapEResv(tbid,elmarket,dirResv));

Equation EQ_CostCapESlack(tt,dirResv)      'Beregner penalty på CapESlack';
EQ_CostCapESlack(t,dirResv) $(OnCapacityReservation AND IsBidDay(t)) .. CostCapESlack(t,dirResv)  =E=  CapESlackPenalty * CapESlack(t,dirResv);

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
Equation EQ_RewardBurnWaste(tt);
Equation EQ_TotalCostU(tt,u);
Equation EQ_TotalElIncome(tt,kv);
Equation EQ_CO2EmisSum(net,co2kind);
Equation EQ_TotalCO2Emis(tt,net,co2kind);
#--- Equation EQ_CO2EmitLimit(net,co2kind);

#OBS Genberegning af slave objective efter hver rullende horisont skal opdateres hvis EQ_ObjSlave opdateres.

EQ_ObjSlave .. zSlave  =E=  ( GainCapETotal
                              + sum (t,
                                + QSales(t)
                                + sum (tr  $OnTrans(tr),    -CostPump(t,tr))
                                + sum (u   $OnU(t,u),       -TotalCostU(t,u))
                                + sum (kv  $OnU(t,kv),      +TotalElIncome(t,kv))
                                + sum (net $OnNet(net),     -CostInfeas(t,net))
                                + sum (net $OnNet(net),     -CostSrPenalty(t,net))
                                + sum (dirResv,             -CostCapESlack(t,dirResv))
                                +                            RewardBurnWaste(t)
                                )
                             ) / PeriodObjScale;      # Total cost in MDKK.

EQ_CostInfeas(t,net) $OnNet(net) .. CostInfeas(t,net)  =E=  sum(infeasDir, QeInfeas(t,net,infeasDir)) * QInfeasPenalty;   #---  + sum(netq $OnNet(netq), sum(t, bOnSR(t,netq))) * bOnSRPenalty;

# remove EQ_CostSrPenalty(t,net) .. CostSrPenalty(t,net)  =E=  sum(upsr $(OnU(t,upsr) AND AvailUNet(upsr,net)), Qf(t,upsr) * QSrPenalty) $OnNet(net);
EQ_CostSrPenalty(t,net) .. CostSrPenalty(t,net)  =E=  sum(upsr $(OnU(t,upsr) AND AvailUNet(upsr,net)), Qe(t,upsr) * QSrPenalty) $OnNet(net);

EQ_RewardBurnWaste(t)   .. RewardBurnWaste(t)  =E=  RewardWaste * sum(uaff $OnU(t,uaff), FuelQty(t,uaff));

EQ_QSales(t) ..  QSales(t)  =E=  sum(net $(OnNet(net) AND QSalgspris(net) GT 0.0), QSalgspris(net) * QeDemandActual(t,net));

$OffOrder
# bStart gøres ikke-cirkulær ifm. rolling horizon og itererer over tt fremfor t.
EQ_Start(t,upr) $(OnU(t,upr) AND ord(t) GE 2)    .. (bOn(t,upr) - bOn(t-1,upr))  =L=  bStart(t,upr);
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
                                                            + sum(uov $(OnU(t,uov) AND sameas(upr,uov)), CostPurchaseOV(t,uov))
                                                           ])
                                                            + VarDVOmkst(t,u);


#--- EQ_TotalElIncome(t,kv) $(OnU(t,kv)) .. TotalElIncome(t,kv)    =E=  [ElSales(t,kv) + ElTilskud(t,kv)] $OnU(t,kv);
EQ_TotalElIncome(t,kv) $(OnU(t,kv)) .. TotalElIncome(t,kv)    =E=  [ElSales(t,kv)] $OnU(t,kv);

*end Overordnede equations


*begin Produktionsgrænser og varmebalance.
Equation EQ_PowInProdU(tt,upr)    'Indgiven effekt [MW]';
Equation EQ_QProdUqMin(tt,uq)      'Min. varmeproduktion for rent varmeproduc. units [MWq]';
Equation EQ_QProdUqMax(tt,uq)      'Max. varmeproduktion for rent varmeproduc. units [MWq]';
Equation EQ_QProdKVmin(tt,kv)      'Min. modtryks-varmeproduktion for KV-anlaeg [MWq]';
Equation EQ_QProdKVmax(tt,kv)      'Max. modtryks-varmeproduktion for KV-anlaeg [MWq]';
#--- Equation EQ_FinSum(upr)        'Sum af indgivet effekt [MWhf]';

# Indgiven effekt afledes af varmeeffekten, som er den styrende variabel, som igen er underlagt kapacitetsgrænser.
# Denne ligning gælder kun for rene varmeproducerende anlæg, ikke KV-anlæg.
EQ_PowInProdU(t,upr) $(OnU(t,upr) AND uq(upr)) .. Ff(t,upr)  =E= (Qf(t,upr) / EtaQU(upr)) $(NOT hp(upr)) + sum(hp $sameas(hp,upr), (Qf(t,hp) / COP(t,hp)));

# Hensyntagen til modulstørrelse i beregning af mindstelast (kun for rene varmeproducerende anlaeg, ikke KV-anlaeg): EQ_QProdUmin:     
# BUGFIX : Nye KV-anlaeg var udelukket fra EQ_QProdUmin/-max, og dermed ville marginalen blive nul for disse og dermed igen en nulvaerdi for GradUMarg.    
# OBS Graenserne er for KV-anlaeg baseret på modtryksproduktion, da Qf kan indeholde RGK-varme og bypass-varme.
# remove EQ_QProdUqmin(t,uq) $(OnU(t,uq)) .. Qf(t,uq)  =G=  BLen(t) * DataU(uq,'Fmin') * CapQU(uq) * DataU(uq,'ModuleSize') * [1 $(not hp(uq)) + sum(hp $sameas(hp,uq), QhpYield(t,hp))] * bOn(t,uq);
# remove EQ_QProdUqmax(t,uq) $(OnU(t,uq)) .. Qf(t,uq)  =L=  BLen(t) * DataU(uq,'Fmax') * CapQU(uq) * [1 $(not hp(uq)) + sum(hp $sameas(hp,uq), QhpYield(t,hp))] * bOn(t,uq);
EQ_QProdUqMin(t,uq) $(OnU(t,uq)) .. Qf(t,uq)  =G=  DataU(uq,'Fmin') * CapQU(uq) * DataU(uq,'ModuleSize') * [1 $(not hp(uq)) + sum(hp $sameas(hp,uq), QhpYield(t,hp))] * bOn(t,uq);
EQ_QProdUqMax(t,uq) $(OnU(t,uq)) .. Qf(t,uq)  =L=  DataU(uq,'Fmax') * CapQU(uq) * [1 $(not hp(uq)) + sum(hp $sameas(hp,uq), QhpYield(t,hp))] * bOn(t,uq);

# remove EQ_QProdKVmin(t,kv) $(OnU(t,kv) AND NOT uaff(kv)) .. QfBack(t,kv)  =G=  BLen(t) * DataU(kv,'Fmin') * CapQU(kv) * bOn(t,kv); 
# remove EQ_QProdKVmax(t,kv) $(OnU(t,kv) AND NOT uaff(kv)) .. QfBack(t,kv)  =L=  BLen(t) * DataU(kv,'Fmax') * CapQU(kv) * bOn(t,kv);
EQ_QProdKVmin(t,kv) $(OnU(t,kv) AND NOT uaff(kv)) .. QfBack(t,kv)  =G=  DataU(kv,'Fmin') * CapQU(kv) * bOn(t,kv); 
EQ_QProdKVmax(t,kv) $(OnU(t,kv) AND NOT uaff(kv)) .. QfBack(t,kv)  =L=  DataU(kv,'Fmax') * CapQU(kv) * bOn(t,kv);

# TODO marginaler skal nu skaleres med Blen(t), hvis det er relevant at bruge dem.
                      
Equation EQ_QfBack2QeBack(tt,kv)     'Beregning af modtryksvarmeenergi fra unit kv [MWhq]';
Equation EQ_QfRgk2QeRgk(tt,kv)       'Beregning af RGK varmeenergi fra unit kv [MWhq]';
Equation EQ_QfBypass2QeBypass(tt,kv) 'Beregning af bypass varmeenergi fra unit kv [MWhq]';
Equation EQ_QF2QE(tt,u)              'Beregning af varmeenergi fra unit u [MWhq]';
Equation EQ_QTF2QTE(tt,tr)           'Beregning af transmitteret energi i ledning tr [MWhq]';
Equation EQ_FinF2FinE(tt,upr)        'Beregning af indgivet energi til unit upr [MWhf]';
Equation EQ_HeatBalance(tt,net);

EQ_QF2QE(t,u)              $(OnU(t,u))   .. Qe(t,u)         =E=  BLen(t) * Qf(t,u);
EQ_FinF2FinE(t,upr)        $(OnU(t,upr)) .. Fe(t,upr)       =E=  BLen(t) * Ff(t,upr);
EQ_QfRgk2QeRgk(t,kv)       $(OnU(t,kv))  .. QeRgk(t,kv)     =E=  BLen(t) * QfRgk(t,kv);
EQ_QfBypass2QeBypass(t,kv) $(OnU(t,kv))  .. QeBypass(t,kv)  =E=  BLen(t) * QfBypass(t,kv);
EQ_QfBack2QeBack(t,kv)     $(OnU(t,kv))  .. QeBack(t,kv)    =E=  BLen(t) * QfBack(t,kv);
EQ_QTF2QTE(t,tr)           $(OnT(t,tr))  .. QTe(t,tr)       =E=  BLen(t) * QTf(t,tr);

# TODO Varmetabet i retur-retningen bæres reelt af netF i modsætning til tabet i frem-retningen. Brug trkind til at skelne og revidere EQ_Heat_Balance.

# TODO QeDemandActual skal være på energibasis.

EQ_HeatBalance(t,net) $OnNet(net) .. QeDemandActual(t,net) =E=
                                     sum(uq $(OnUNet(uq,net)),              Qe(t,uq))
                                   + sum(kv $(OnUNet(kv,net)),              Qe(t,kv))
                                   + sum(vak $OnUNet(vak,net),              Qe(t,vak))
                                   - sum(cool2net(ucool,net) $OnU(t,ucool), Qe(t,ucool))
                                   
                                   # DirTrans er +1 for nominel flowretning og -1 for modsat flowretning.
                                   + sum(netT $OnNet(netT),
                                         - sum(tr $OnTransNet(tr,net,netT), DirTrans(tr) * [QTe(t,tr) - QTeLoss(t,tr) * (DirTrans(tr) - 1) / 2 ])    # Varme nominelt afsendt  til netT.
                                         + sum(tr $OnTransNet(tr,netT,net), DirTrans(tr) * [QTe(t,tr) - QTeLoss(t,tr) * (DirTrans(tr) + 1) / 2 ])    # Varme nominelt modtaget fra netT.
                                         )
                                   + (QeInfeas(t,net,'source') - QeInfeas(t,net,'drain')) $(QeInfeasMax GT 0);

# Restriktioner på rampetid. Ramperestriktioner er effektbaseret.

Equation EQ_RampUpMax(tt,upr)   'RampUp begrænsning';
Equation EQ_RampDownMax(tt,upr) 'RampDown begrænsning';

$OffOrder    
# OBS FfInPrevious er ligesom Ff angivet i foregående tidspunkts tidsopløsning
#     Tilstande i tidspunktet før planperioden angives på timebasis. BLenRatio(t) afspejler dette, hvor BLenRatio(t) = BLen(t) / BLen(t-1).
#--- EQ_RampUpMax(t,upr)   $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampUp')   LT (1.0 - tiny)) .. Ff(t,upr) - BLenRatio(t) * [FfInPrevious(upr) $(ord(t) EQ 1) + Ff(t-1,upr) $(ord(t) GT 1)]  =L=  +1.01 * min(1.0, 1E-3 + DataU(upr,'RampUp')   * TimeResol(t)) * BLen(t) * FinFMax(upr) * bOn(t,upr);
#--- EQ_RampDownMax(t,upr) $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampDown') LT (1.0 - tiny)) .. Ff(t,upr) - BLenRatio(t) * [FfInPrevious(upr) $(ord(t) EQ 1) + Ff(t-1,upr) $(ord(t) GT 1)]  =G=  -1.01 * min(1.0, 1E-3 + DataU(upr,'RampDown') * TimeResol(t)) * BLen(t) * FinFMax(upr) * bOn(t,upr);

# TODO CHECK AT BLenRatio er korrekt anvendt her:
#--- EQ_RampUpMax(t,upr)   $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampUp')   LT (1.0 - tiny)) 
#---                .. Ff(t,upr) - BLenRatio(t) * [FfInPrevious(upr) $(ord(t) EQ 1) + Ff(t-1,upr) $(ord(t) GT 1)]  =L=  +min(1.0, 1E-3 + DataU(upr,'RampUp')   * TimeResol(t)) * BLen(t) * FinFMax(upr) * bOn(t,upr);
#--- EQ_RampDownMax(t,upr) $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampDown') LT (1.0 - tiny)) 
#---                .. Ff(t,upr) - BLenRatio(t) * [FfInPrevious(upr) $(ord(t) EQ 1) + Ff(t-1,upr) $(ord(t) GT 1)]  =G=  -min(1.0, 1E-3 + DataU(upr,'RampDown') * TimeResol(t)) * BLen(t) * FinFMax(upr) * bOn(t,upr);

EQ_RampUpMax(t,upr)   $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampUp')   LT (1.0 - tiny)) 
               .. Ff(t,upr)  =L=  [FfInPrevious(upr) $(ord(t) EQ 1) + Ff(t-1,upr) $(ord(t) GT 1)] + min(1.0, 1E-4 + DataU(upr,'RampUp')   * TimeResol(t)) * FinFMax(upr) * bOn(t,upr);

EQ_RampDownMax(t,upr) $(OnU(t,upr) AND OnRampConstraints AND DataU(upr,'RampDown') LT (1.0 - tiny)) 
               .. Ff(t,upr)  =G=  [FfInPrevious(upr) $(ord(t) EQ 1) + Ff(t-1,upr) $(ord(t) GT 1)] - min(1.0, 1E-4 + DataU(upr,'RampDown') * TimeResol(t)) * FinFMax(upr) * bOn(t,upr);
$OnOrder

# TODO Skift ved ramper mv. skal checkes for tidsskalering.

*end Produktionsgrænser og varmebalance

*begin Produktionsomkostninger

Equation EQ_TaxUpr(tt,upr,tax);
Equation EQ_TaxUpr2(tt,upr,tax);
Equation EQ_TotalTaxUpr(tt,upr);
Equation EQ_FuelCostSR(tt,upsr);
Equation EQ_FuelCost(tt,upr);
Equation EQ_TariffCost(tt,upr);
Equation EQ_VarDVCostUq(tt,uq);
Equation EQ_VarDVCostKV(tt,kv);
Equation EQ_DVOmkstRGK(tt,kv);
Equation EQ_DVOmkstBypass(tt,kv);
Equation EQ_VarDVCostVAK(tt,vak);
Equation EQ_StartOmkstUpr(tt,upr);
Equation EQ_ElEigenE(tt,upr)            'Beregner el-egetforbruget af hver anlæg [MWhe]';
Equation EQ_ElEgbrugOmkst(tt,upr); 
Equation EQ_CO2KvoteOmkst(tt,upr);
Equation EQ_CO2emisUpr(tt,upr,co2kind) 'CO2 emission [kg/h]';
Equation EQ_FuelQty(tt,upr)            'Brændselsmængde [selektiv enhed: L|m3|kg]';


EQ_TotalTaxUpr(t,upr) $(OnU(t,upr)) .. TotalTaxUpr(t,upr)  =E=  sum(tax, TaxProdU(t,upr,tax));

# OBS CO2-kvoteomkostning er ikke en afgift, og håndteres derfor særskilt, også fordi kun samlede anlæg over 20 MWf på samme site er omfattet.
EQ_TaxUpr(t,uq,tax) $(NOT sameas(tax,'ets') AND OnU(t,uq)) ..
              TaxProdU(t,uq,tax)  =E=    sum(f, FuelMix(uq,f) * TaxRateMWh(f,tax,'kedel'))  * Fe(t,uq) $(NOT hp(uq))
                                       + sum(hp $sameas(hp,uq), TaxRateMWh('Elec',tax,'vp') * Fe(t,hp)) ;

# Overskudsvarme afgift betales af input-varmen.
EQ_TaxUpr2(t,hp_OV,tax) .. TaxProdU(t,hp_OV,'Oversk') =E= (YS('TaxOverskudsVarme') * 3.6 * Ff(t,hp_OV) * (COP(t,hp_OV)-1.0)) $OnU(t,hp_OV) ; 


EQ_CO2KvoteOmkst(t,upr) $OnU(t,upr)    ..  CO2KvoteOmkst(t,upr)  =E=  CO2emis(t,upr,'regul') * YS('TaxCO2Kvote') $DataU(upr,'Kvoteomfattet');


# TODO Indsæt bidrag fra overskudsvarmeafgift hvor relevant:  + (YS('TaxOverskudsVarme') * 3.6 * Ff(t,hp) * (COP(t,hp)-1.0));


# OBS: Variable DV-omkostninger bør beregnes ift. indfyret effekt, som er uafh. af driftsmodus, da fx KV-anlæg har to energi-outputs, men kun ét energi-input. Men her beregnes på basis af varmeproduktionen.
EQ_VarDVCostUq(t,uq)  $(OnU(t,uq))  .. VarDVOmkst(t,uq)   =E=  Qe(t,uq) * DataU(uq,'VarDVOmkst');
EQ_VarDVCostVAK(t,vak)              .. VarDVOmkst(t,vak)  =E=  [DataU(vak,'VAKChargeCost') * BLen(t) * QfVakAbs(t,vak)]  $OnU(t,vak) ;

# OBS Indført forskel på hvor brændselsprisen hentes. SR-anlæg henter fra Brandsel, mens øvrige termiske anlæg henter prisen fra DataU, fordi prisen kan være anlægsafhængig.

EQ_FuelCostSR(t,upsr) $OnU(t,upsr)     .. FuelCost(t,upsr)   =E=  Fe(t,upsr) * [sum(f, FuelMix(upsr,f) * (FuelPriceU(upsr,f) + TariffFuelMWh(f))       ) $(NOT uelec(upsr))
                                                                                + sum(uelec$sameas(uelec,upsr), TariffElecU(t,uelec) + ElspotActual(t)) $uelec(upsr)   
                                                                                 ];

# OBS Brændselsprisen er angivet på anlægsbasis, da det giver mulighed for at differentiere på brændsels-indkøbsprisen, fx overskudsvarme, hvor prisen er leverandørafhængig.
# Electricitet som drivmiddel omkostningsberegnes på anden vis end brændsler.
# FuelCost har et ekstra bidrag for OV-kilder, idet OV kan være pålagt en pris  DKK/MWhc  per MWh kølevarme.
# Denne kølevarmepris er indsat i tabellen FuelPriceU(upr,f) for VP-anlæg, som fødes med OV.
# Dermed kan kølevarmeprisen inddrages, idet den kun gælder for eldrevne anlæg.

# Beregning af kølevarmen fra OV-kilder:  QeOV = Qf(upr) * (COP - 1) / COP
# Overskudsvarmen QfOV er før opgradering til FJV-niveau.
Equation EQ_QfOV(tt,uov)       'Beregning af kølevarmeeffekt fra OV-kilder';
Equation EQ_QeOV(tt,uov)       'Beregning af kølevarmeenergi fra OV-kilder';
Equation EQ_bOnOV(tt,uov)      'Øvre graense for bOn af OV-anlæg';
Equation EQ_QfOvMax(tt,uov)    'Max. last paa OV';

# OBS Restriktionerne herunder tillader at aftage ingen OV, selvom den er til rådighed.
#     QeOV beregnes indirekte fra aftaget af den opgraderede OV.
# remove EQ_QOV(t,uov) ..  Qf(t,uov)    =E=  QeOV(t,uov) * sum(hp $sameas(hp,uov), COP(t,hp) / (COP(t,hp) - 1) ) $OnU(t,uov) ;
EQ_QfOV(t,uov)  $OnU(t,uov) ..  Qf(t,uov)   =E=  QfOV(t,uov) * sum(hp $sameas(hp,uov), COP(t,hp) / (COP(t,hp) - 1) ) $OnU(t,uov) ;
EQ_QeOV(t,uov)  $OnU(t,uov) ..  Qe(t,uov)   =E=  BLen(t) * QfOV(t,uov);
EQ_bOnOV(t,uov) $OnU(t,uov) ..  bOn(t,uov)  =L=  OnU(t,uov);
EQ_QfOvMax(t,uov) $OnU(t,uov) ..  QfOV(t,uov)  =L=  QfOVmax(t,uov) * DataU(uov,'Fmax') * bOn(t,uov) ;   # Partielle aktiv-status tillades ifm. tidsaggregering.


# OBS Prioritering er overflødig, idet affaldslinjer har en meget lav marginalpris.
#--- # Pri     af OV efter affaldslinjer og foer oevrige anlaeg. uother er alle produktionsanlaeg paanaer OV og affaldslinjer.
#--- Equation EQ_PriorityOV(tt,uov) 'Prioritering af OV';
#--- EQ_PriorityOV(t,uov) $OnU(uov) .. bOn(t,uov) * card(uother)  =G=  sum(uother $OnU(uother), bOn(t,uother)) $OnU(t,uov);

# Beregn koebspris for overskudsvarme
Equation EQ_CostPurchaseOV(tt,uov) 'koebsomkostning OV';
EQ_CostPurchaseOV(t,uov) $OnU(t,uov) .. CostPurchaseOV(t,uov)  =E=  sum(fov $uov2fov(uov,fov), FuelMix(uov,fov) * FuelPriceU(uov,fov) * QeOV(t,uov)) $uov(uov);

EQ_FuelCost(t,upr) $(OnU(t,upr) AND NOT upsr(upr)) .. FuelCost(t,upr) =E=  Fe(t,upr) * [ sum(f, FuelMix(upr,f) * (FuelPriceU(upr,f) + TariffFuelMWh(f)) ) $(NOT uelec(upr))
                                                                                       + sum(uelec $sameas(uelec,upr), TariffElecU(t,uelec) + ElspotActual(t) ) $uelec(upr)
                                                                                       ]
                                                                           + sum(uov $(OnU(t,uov) AND sameas(upr,uov)), CostPurchaseOV(t,uov)) $uov(upr);

EQ_StartOmkstUpr(t,upr) $(OnU(t,upr)) .. StartOmkst(t,upr)   =E=  bStart(t,upr) * DataU(upr,'StartOmkst');
           
# TariffCost beregnes for alle anlaeg og anvendes kun til StatsMecU.
EQ_TariffCost(t,upr) $(OnU(t,upr))    .. TariffCost(t,upr) =E=  Fe(t,upr) * [sum(f, FuelMix(upr,f) * TariffFuelMWh(f)) $(NOT uelec(upr)) + sum(uelec $sameas(uelec,upr), TariffElecU(t,uelec))];

# OBS El-egetforbruget sættes til nul (forsimpling) for små anlæg, og for KV-anlæg antages egetforbruget dækkes af egenproduktion.
#     Der skal betales rådighedstarif af egetforbruget.
#     Det antages for centrale anlæg, at egetforbruget er aktivt, selvom anlægget ikke producerer i en given time, men er til rådighed (startklar).
#     For øvrige anlæg antages, at egetforbruget kun er aktivt, når anlægget er i drift.

EQ_ElEigenE(t,upr)      ..  ElEigenE(t,upr)       =E=  [BLen(t) * DataU(upr,'ElEig0') * bOn(t,upr) + DataU(upr,'ElEig1') * Fe(t,upr)] $OnU(t,upr);
EQ_ElEgbrugOmkst(t,upr) ..  ElEgbrugOmkst(t,upr)  =E=  ElEigenE(t,upr) * TariffElRaadighedU(upr);

# Regulatorisk og fysisk CO2-emission beregnes for alle produktionsanlæg.
# CO2-indholdet af elektrictet varierer med årsfremskrivningerne.
EQ_CO2emisUpr(t,upr,co2kind) $OnU(t,upr) ..  CO2emis(t,upr,co2kind)   =E=  Fe(t,upr) * sum(f $(FuelMix(upr,f) GT 0),
                                                                           [FuelMix(upr,f) * Brandsel(f,'CO2EmisMWh') * [Brandsel(f,'FossilAndel') * (1-0) $sameas(co2kind,'regul') + (1.0 - 0.8 * (0)) $sameas(co2kind,'phys')]]  
                                                                           + [YS('CO2ElecMix') $(sameas(f,'elec') AND sameas(co2kind,'phys'))]                  #
                                                                         ) / 1000;

# FuelQty er i mængdetype, som er specifik for hvert brændsel: L for olier, m3 for Ngas, kg for faste brændsler, MWh for varme,el.
EQ_FuelQty(t,upr) $OnU(t,upr)  ..  FuelQty(t,upr)  =E=  Ff(t,upr) / sum(f, FuelMix(upr,f) * LhvMWhPerUnitFuel(f)); 

*end Produktionsomkostninger


#--- *begin Solvarme
#--- Equation EQ_Sol(tt,usol);
#--- # TODO Solvarme kan ikke undertrykkes i praksis, kun i en model. Det skal være en =E= restriktion, men det kræver både lager og bortkølingsfacilitet for at undgå infeasibility.
#--- EQ_Sol(t,usol)  $OnU(t,usol)  .. Qf(t,usol)  =L=  BLen(t) * Solvarme(t,usol) ;     # Den maksimale solvarmeproduktion i modellen følger tidsserien for den virkelige solvarmeproduktion.
#--- 
#--- *end Solvarme

*begin Ligninger for KV-anlæg

Equation EQ_BypassMax(tt);
Equation EQ_Pbrut(tt,kv);
Equation EQ_Pnet(tt,kv);
Equation EQ_PfBack(tt,kv);
Equation EQ_PfBypass(tt,kv);
#--- Equation EQ_QfBackMin(tt,kv);
#--- Equation EQ_QfBackMax(tt,kv);
Equation EQ_QfBackMin(tt,uaff);  # Nedre graense haandteres af EQ_QProdKVmax.
Equation EQ_QfBackMax(tt,uaff);  # Oevre graense haandteres af EQ_QProdKVmax.
Equation EQ_QfBypassMin(tt,kv);
Equation EQ_QfBypassMax(tt,kv);
#--- Equation EQ_QfBypassMaxMin(tt,kv);
#--- Equation EQ_QfBypassMaxMax(tt,kv);
Equation EQ_QBypassMaxCost(tt,kv);
Equation EQ_QfRgk(tt,kv);
Equation EQ_Qkv(tt,kv);

# PQ-punktet modelleres vha. PQ-linjen for modtryk, og mindstelasten fastlægges af Qmin = EtaQ * Fmin.
# Turbine-bypass modelleres som variabelt med en mindstelast på 30 pct.

EQ_BypassMax(t) .. sum(kv $OnU(t,kv), bBypass(t,kv))  =L=  2;

# OBS PQ-diagrammet for KV-anlæggene er givet ved brutto elproduktion PfBrut.

#---EQ_Pbrut(t,kv)           .. PfBrut(t,kv)    =E=  PfBack(t,kv) - PfBypass(t,kv) - DataU(kv,'ElEig1') * Ff(t,kv);  # Proportional-delen af egetforbruget fratrækkes netto-produktionen.
EQ_Pbrut(t,kv)           .. PfBrut(t,kv)    =E=  PfBack(t,kv) - PfBypass(t,kv);
EQ_Pnet(t,kv)            .. PfNet(t,kv)     =E=  PfBrut(t,kv) - ElEigenE(t,kv);

# remove EQ_PfBack(t,kv)           .. PfBack(t,kv)    =E=  (BLen(t) * DataU(kv,'a0_PQ') * bOn(t,kv) + DataU(kv,'a1_PQ') * QfBack(t,kv)) $OnU(t,kv);
EQ_PfBack(t,kv)          .. PfBack(t,kv)    =E=  (DataU(kv,'a0_PQ') * bOn(t,kv) + DataU(kv,'a1_PQ') * QfBack(t,kv)) $OnU(t,kv);
EQ_PfBypass(t,kv)        .. PfBypass(t,kv)  =E=  QfBypass(t,kv);
            
# Back pressure (modtryk) for Affaldsanlaeg er opadtil begraenset af braendselsmaengden typisk affaldstonnagen.             
# remove EQ_QfBackMin(t,uaff)      .. QfBack(t,uaff)  =G=  BLen(t) * DataU(uaff,'EtaQ') * DataU(uaff,'Fmin') * bOn(t,uaff) $OnU(t,uaff);
# remove EQ_QfBackMax(t,uaff)      .. QfBack(t,uaff)  =L=  BLen(t) * DataU(uaff,'EtaQ') * DataU(uaff,'Fmax') * bOn(t,uaff) $OnU(t,uaff);
EQ_QfBackMin(t,uaff)      .. QfBack(t,uaff)  =G=  DataU(uaff,'Fmin') * CapQU(uaff) * bOn(t,uaff) $OnU(t,uaff);
EQ_QfBackMax(t,uaff)      .. QfBack(t,uaff)  =L=  DataU(uaff,'Fmax') * CapQU(uaff) * bOn(t,uaff) $OnU(t,uaff);
                                                
# remove EQ_QfBypassMin(t,kv)      .. QfBypass(t,kv)  =G=  0.20 * BLen(t) * DataU(kv,'Qbypass') * bBypass(t,kv) $OnU(t,kv);
# remove EQ_QfBypassMax(t,kv)      .. QfBypass(t,kv)  =L=  1.00 * BLen(t) * DataU(kv,'Qbypass') * bBypass(t,kv) $OnU(t,kv);
EQ_QfBypassMin(t,kv)     .. QfBypass(t,kv)  =G=  0.20 * DataU(kv,'Qbypass') * bBypass(t,kv) $OnU(t,kv);
EQ_QfBypassMax(t,kv)     .. QfBypass(t,kv)  =L=  1.00 * DataU(kv,'Qbypass') * bBypass(t,kv) $OnU(t,kv);

EQ_QBypassMaxCost(t,kv)  .. QbypassCost(t,kv) =E= QeBypass(t,kv) * DataU(kv,'VarDVomkstBypass') $OnU(t,kv);

EQ_QfRgk(t,kv) ..  QfRgk(t,kv)  =L=  DataU(kv,'QRgkMax') * bRgk(t,kv) $(OnU(t,kv));

# TODO QfBack -> QbackF, QfBypass -> QbypassF, QRgk -> QRgkF (effekter)

# remove EQ_Qkv(t,kv)  .. Qf(t,kv)  =E= QfBack(t,kv) + QfBypass(t,kv) + QRgk(t,kv);
EQ_Qkv(t,kv)  .. Qf(t,kv)  =E= QfBack(t,kv) + QfRgk(t,kv) + QfBypass(t,kv) ;

Equation EQ_FfInCHP(tt,kv);
EQ_FfInCHP(t,kv) $(OnU(t,kv))  .. Ff(t,kv)  =E=  QfBack(t,kv) / DataU(kv,'EtaQ');

Equation EQ_ElSales(tt,kv);
EQ_ElSales(t,kv) .. ElSales(t,kv)  =E=  PfNet(t,kv) * (ElspotActual(t) + TariffElSellU(kv)) $ OnU(t,kv);

EQ_VarDVCostKV(t,kv)   $OnU(t,kv)  .. VarDVOmkst(t,kv)    =E=  Fe(t,kv) * DataU(kv,'VarDVOmkst') + DVOmkstRGK(t,kv) + DVOmkstBypass(t,kv);
EQ_DVOmkstRGK(t,kv)    $OnU(t,kv)  .. DVOmkstRGK(t,kv)    =E=  QeRgk(t,kv)    * DataU(kv,'VarDVomkstRgk');
EQ_DVOmkstBypass(t,kv) $OnU(t,kv)  .. DVOmkstBypass(t,kv) =E=  QeBypass(t,kv) * DataU(kv,'VarDVomkstBypass');


Equation EQ_TaxProdCHP(tt,kv,tax);
Equation EQ_TaxTotalCHP(tt,kv);
Equation EQ_FeHeat(tt,kv) 'Brændsel medgået til varmeproduktion [MWhf]';

EQ_TaxTotalCHP(t,kv) $(OnU(t,kv))  ..  TotalTaxUpr(t,kv)  =E=  sum(tax, TaxProdU(t,kv,tax));

# Afgiftsberegning for KV-anlæg pånær affaldsanlæg.
EQ_TaxProdCHP(t,kv,tax) $(OnU(t,kv) AND NOT uaff(kv))  ..  TaxProdU(t,kv,tax)  =E=  sum(f, Fuelmix(kv,f) * TaxRateMWh(f,tax,'kv') * Fe(t,kv)) $taxkv(tax)
                                                                                  + sum(f, Fuelmix(kv,f) * TaxRateMWh(f,tax,'kv') * FeHeat(t,kv)) $taxkv2(tax);
                                                                                 
# E- eller V-formel bruges for KV-anlæg.
EQ_FeHeat(t,kv) .. FeHeat(t,kv)  =E=  [(Fe(t,kv) - BLen(t) * PfNet(t,kv)/0.67) $(TaxEForm(kv) EQ 1) + (Qe(t,kv) / 1.2) $(TaxEForm(kv) EQ 0)] $OnU(t,kv);


*begin Gasmotorer
Equation EQ_Taxes1Gm(tt,taxkv,gm);
Equation EQ_Taxes2Gm(tt,gm);
Equation EQ_Taxes3Gm(tt,gm);

EQ_Taxes1Gm(t,taxkv,gm) $OnU(t,gm) ..  TaxProdU(t,gm,taxkv)   =E=  TaxRateMWh('NGas',taxkv,'kv') * Ff(t,gm);
EQ_Taxes2Gm(t,gm) $OnU(t,gm)       ..  TaxProdU(t,gm,'enr')   =E=  TaxRateMWh('NGas','enr','kv') * sum(kv $sameas(kv,gm), FeHeat(t,kv));
EQ_Taxes3Gm(t,gm) $OnU(t,gm)       ..  TaxProdU(t,gm,'co2')   =E=  TaxRateMWh('NGas','co2','kv') * sum(kv $sameas(kv,gm), FeHeat(t,kv));
*end Gasmotorer



*begin Affaldsanlæg

# Afgiftsberegning for affaldsanlæg er mere kompliceret end for øvrige typer produktionsanlæg. Dertil håndteres beregningen særskilt her.
# Der er kun ét affaldsanlæg (SoAffald) i modellen med tilhørende RGK og bortkøleanlæg (SoCool)

Positive variable AffQLev(tt,uaff)                'Leveret varme fra affaldsanlæg [MWhq]';
Positive variable AffQVarmeAfg(tt,uaff)           'Varmemængde som pålægges affaldvarmeafgift';
# remove Positive variable AffQcool(tt,uaff)               'Varmeflow bortkølet fra affaldsanlæg [MWq]';
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
# remove Equation EQ_AffQcool(tt,uaff);
Equation EQ_AffQP(tt,uaff);
Equation EQ_AffF(tt,uaff);
Equation EQ_QCoolMax(tt,ucool);

# remove EQ_QAffLev(t,uaff) $OnU(t,uaff)      .. AffQLev(t,uaff)       =E=  Qf(t,uaff) - AffQcool(t,uaff);
# remove EQ_QAffTaxVarme(t,uaff) $OnU(t,uaff) .. AffQVarmeAfg(t,uaff)  =E=  AffQLev(t,uaff) - DataAff('FrakAux',uaff) * 0.85 * AffAux(uaff) * Ff(t,uaff);
# remove EQ_QAffLev(t,uaff) $OnU(t,uaff)      .. AffQLev(t,uaff)       =E=  Qe(t,uaff) - AffQcool(t,uaff);
EQ_QAffLev(t,uaff) $OnU(t,uaff)      .. AffQLev(t,uaff)       =E=  Qe(t,uaff) - sum(ucool $(OnU(t,ucool) AND aff2cool(uaff,ucool)), Qe(t,ucool));
EQ_QAffTaxVarme(t,uaff) $OnU(t,uaff) .. AffQVarmeAfg(t,uaff)  =E=  AffQLev(t,uaff) - DataAff('FrakAux',uaff) * 0.85 * AffAux(uaff) * Fe(t,uaff);

# TODO Qcool flyttes over i Q

# remove EQ_AffQcool(t,uaff) $OnU(t,uaff)     .. AffQcool(t,uaff)      =E=  sum(ucool $(OnU(t,ucool) AND aff2cool(uaff,ucool)), Qe(t,ucool));
# remove EQ_AffQcool(t,uaff) $OnU(t,uaff)     .. AffQcool(t,uaff)      =E=  sum(ucool $(OnU(t,ucool) AND aff2cool(uaff,ucool)), Qe(t,ucool));
EQ_QCoolMax(t,ucool) $OnU(t,ucool)   .. Qf(t,ucool)           =L=  CapQU(ucool) $OnU(t,ucool);

EQ_AffQP(t,uaff) $OnU(t,uaff)        .. AffQP(t,uaff)         =E=  Qf(t,uaff) + PfNet(t,uaff);        # remove  + sum(urgk $aff2rgk(uaff,urgk), Qf(t,urgk));
EQ_AffF(t,uaff)  $OnU(t,uaff)        .. AffF(t,uaff)          =E=  Qf(t,uaff) * (1 - DataAff('FrakAux',uaff));                                          # Tillægsafgift beregnes kun af Qf, hvorimod rabat regnes på Qf+PfBrut (EY).
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

EQ_AffCO2emisHeat(t,uaff) $OnU(t,uaff) .. CO2emisHeat(t,uaff)  =E=  FeHeat(t,uaff) * Brandsel('Affald','CO2EmisMWh') / 1000;  # Omregning fra kgCO2/MWf til tonCO2/MWf.
EQ_AffFuelQtyHeat(t,uaff) $OnU(t,uaff) .. FuelQtyHeat(t,uaff)  =E=  FeHeat(t,uaff) / [Brandsel('Affald','LHV') / 3.6];  # FuelQtyHeat er ton affald medgået til varmeproduktion i tidsrum t.

* Beregning af CO2-kvoteomkostninger pålagt ved indvejning af affaldet.
EQ_AffCO2KvoteOmkst(t,uaff) $OnU(t,uaff)     .. AffCO2KvoteOmkst(t,uaff)      =E=  YS('TaxCO2Kvote') * CO2emis(t,uaff,'regul');
EQ_AffCO2KvoteOmkstHeat(t,uaff) $OnU(t,uaff) .. AffCO2KvoteOmkstHeat(t,uaff)  =E=  YS('TaxCO2Kvote') * CO2emisHeat(t,uaff) $OnU(t,uaff);

*end Affaldsanlæg

*end Ligninger for KV-anlæg

*begin Ligninger for VAK

Equation EQ_QfVakAbs1(tt,vak);
Equation EQ_QfVakAbs2(tt,vak);
Equation EQ_QvakMinSR(tt,netq,vak);
Equation EQ_EvakLoss(tt,vak);
Equation EQ_Evak(tt,vak);
Equation EQ_LoadMinVak(tt,vak);
Equation EQ_LoadMaxVak(tt,vak);
Equation EQ_MinVak(tt,vak);
Equation EQ_MaxVak(tt,vak);
#remove Equation EQ_FixVak(tt,vak);

Equation EQ_EvakMax(tt,vak);
Equation EQ_dEvakMax(tt,vak);

* Først beregnes den absolutte laderate QfVakAbs.
EQ_QfVakAbs1(t,vak) ..   Qf(t,vak)  =L=  QfVakAbs(t,vak) $(OnU(t,vak));
EQ_QfVakAbs2(t,vak) ..  -Qf(t,vak)  =L=  QfVakAbs(t,vak) $(OnU(t,vak));

# Forebyg opladning af decentrale tanke, når spidslastanlæg er aktive.
# remove EQ_QvakMinSR(t,netq,vak) $(OnNet(netq) AND OnU(t,vak) AND vaknet(vak,netq)) .. Qf(t,vak)  =G=  - BLen(t) * CapQU(vak) * (1 - bOnSR(t,netq));
EQ_QvakMinSR(t,netq,vak) $(OnNet(netq) AND OnU(t,vak) AND vaknet(vak,netq)) .. Qf(t,vak)  =G=  -CapQU(vak) * (1 - bOnSR(t,netq));

* Beregning af Qf lagret i VAK
$OffOrder

EQ_EvakLoss(t,vak) $(OnU(t,vak))  .. EvakLoss(t,vak)  =E=  BLen(t) * DataU(vak,'EvakLossRate') * DataU(vak,'LossGain') * Evak(t,vak);
EQ_Evak(t,vak)     $(OnU(t,vak))  .. Evak(t,vak)      =E=  [EvakPrevious(vak) $(ord(t) EQ 1) + Evak(t--1,vak) $(ord(t) GT 1)] - Qe(t,vak) - EvakLoss(t,vak);

$OnOrder

* Max/min lade-/afladegradient i VAK
EQ_LoadMinVak(t,vak) $OnU(t,vak)  .. Qf(t,vak)   =G=  - CapQU(vak) * DataU(vak,'LoadRateVak')  $(OnU(t,vak))  ;
EQ_LoadMaxVak(t,vak) $OnU(t,vak)  .. Qf(t,vak)   =L=    CapQU(vak) * DataU(vak,'LoadRateVak')  $(OnU(t,vak))  ;

* Max VAK-energiindhold
EQ_MaxVak(t,vak)  $(OnU(t,vak))   .. Evak(t,vak)  =L=  CapQU(vak) * DataU(vak,'VakMax');
EQ_MinVak(t,vak)  $(OnU(t,vak))   .. Evak(t,vak)  =G=  CapQU(vak) * DataU(vak,'VakMin');

# Bestemmelse af hvem der må lade på tanken:
# Set upr2vak fastlægger hvilke anlæg som kan lade på hvilke vak.
# Set tr2vak  fastlægger hvilke T-ledninger som kan lade på hvilke vak.

#--- EQ_EvakMax(t,vak)  $OnU(t,vak)  ..  QfMaxVak(t,vak)  =E=  sum(upr2vak(upr,vak) $OnU(t,upr), Qf(t,upr));

# OBS Hver T-ledning kan kun lade på een vak jf. nedenstående ligning:
EQ_EvakMax(t,vak)  $OnU(t,vak)  ..  QfMaxVak(t,vak)  =E=  sum(upr2vak(upr,vak) $OnU(t,upr),  Qf(t,upr)) + 
                                                          sum(tr2vak(tr,vak)   $OnTrans(tr), QTf(t,tr));
$OffOrder

# VAK-beholdningens tilvækst er begrænset af den maksimale laderate.
EQ_dEvakMax(t,vak) $(OnU(t,vak))  ..  Evak(t,vak)  =L=  [EvakPrevious(vak) $(ord(t) EQ 1) + Evak(t--1,vak) $(ord(t) GT 1)] + BLen(t) * QfMaxVak(t,vak);

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


Equation EQ_QeBase(tt)                    'Beregner Grundlastvarmeproduktion energi';
Equation EQ_QfBase(tt)                    'Beregner Grundlastvarmeproduktion effekt';
Equation EQ_QfBase_bOnSr_2_Min(tt,netq)   'Bruges til at danne produktet QfBase * bOnSR';
Equation EQ_QfBase_bOnSr_2_Max(tt,netq)   'Bruges til at danne produktet QfBase * bOnSR';
Equation EQ_QfBase_bOnSr_1_Max(tt,netq)   'Bruges til at danne produktet QfBase * bOnSR';

# QfBase har en øvre grænse QfBaseMaxAll.
EQ_QeBase(t)                   ..  QeBase(t)                        =E=  BLen(t) * QfBase(t);
EQ_QfBase(t)                   ..  QfBase(t)                        =E=  sum(uprbase $(OnU(t,uprbase) AND DataU(uprbase,'Omraade') EQ NetId('netMa')), Qf(t,uprbase));
EQ_QfBase_bOnSr_1_Max(t,netq)  ..  QfBasebOnSR(t,netq)              =L=  QfBaseMaxAll * bOnSR(t,netq);
EQ_QfBase_bOnSr_2_Min(t,netq)  ..  0                                =L=  QfBase(t) - QfBasebOnSR(t,netq);
EQ_QfBase_bOnSr_2_Max(t,netq)  ..  QfBase(t) - QfBasebOnSR(t,netq)  =L=  QfBaseMaxAll * (1 - bOnSR(t,netq));

# remove EQ_QfBase_bOnSr_1_Max(t,netq)  ..  QfBasebOnSR(t,netq)              =L=  BLen(t) * QfBaseMaxAll * bOnSR(t,netq);
# remove EQ_QfBase_bOnSr_2_Max(t,netq)  ..  QfBase(t) - QfBasebOnSR(t,netq)  =L=  BLen(t) * QfBaseMaxAll * (1 - bOnSR(t,netq));


# TODO Feature med OnTrans (se nedenfor) skal indlægges her.
# QTf ved aktive SR-anlæg er begrænset af ejerandel af grundlastvarmeproduktion tillagt afladeraten fra tilsluttede tanke.
# Derudover er der en flowbetinget grænse og begge grænser skal være aktive.

# remove EQ_QTmaxHo(t) $OnOwnerShare   ..  QTf(t,'tr2')  =L=  (1 - Diverse('StruerAndel')) * QfBasebOnSR(t,'netSt') 
# remove                                                     + BLen(t) * sum(vak $(OnU(t,vak) AND vak2tr(vak,'tr2')), CapQU(vak) * DataU(vak,'LoadRateVak')) 
# remove                                                     + BLen(t) * QTfMax('tr2') * (1 - bOnSR(t,'netSt'));

EQ_QTmaxHo(t) $OnOwnerShare   ..  QTf(t,'tr2')  =L=  (1 - Diverse('StruerAndel')) * QfBasebOnSR(t,'netSt') 
                                                    + sum(vak $(OnU(t,vak) AND vak2tr(vak,'tr2')), CapQU(vak) * DataU(vak,'LoadRateVak')) 
                                                    + QTfMax('tr2') * (1 - bOnSR(t,'netSt'));
                                                    
EQ_QTmaxSt(t) $OnOwnerShare   ..  QTf(t,'tr1')  =L=  (    Diverse('StruerAndel')) * QfBasebOnSR(t,'netHo') 
                                                    + sum(vak $(OnU(t,vak) AND vak2tr(vak,'tr1')), CapQU(vak) * DataU(vak,'LoadRateVak')) 
                                                    + QTfMax('tr1') * (1 - bOnSR(t,'netHo'));

# OBS En T-ledning hvor OnTrans er forskellig fra 1.0 (én), skal anvende tallet i OnTrans som nedre kapacitetsgrænse [MWq].
# remove EQ_QTmin(t,tr) $(OnTrans(tr) NE 1.0)   .. QTf(t,tr)  =G=  BLen(t) * min(OnTrans(tr), QTmin(tr)) * bOnT(t,tr);
# remove EQ_QTmax(t,tr) $(OnTrans(tr) EQ 1.0)   .. QTf(t,tr)  =L=  BLen(t) * QTfMax(tr) * bOnT(t,tr) $OnTrans(tr);
EQ_QTmin(t,tr) $(OnTrans(tr) NE 1.0)   .. QTf(t,tr)  =G=  min(OnTrans(tr), QTmin(tr)) * bOnT(t,tr);
EQ_QTmax(t,tr) $(OnTrans(tr) EQ 1.0)   .. QTf(t,tr)  =L=  QTfMax(tr) * bOnT(t,tr) $OnTrans(tr);

Equation EQ_varmetabT(tt,tr)  'Varmetab i T-ledning';
Equation EQ_CostPump(tt,tr)   'Pumpeomkostninger [DKK]';
#remove Equation EQ_CapexTrans(tr);
#remove Equation EQ_CapexPump(tr);

# Varmetabs-eksempel på Aa til Ha med DN250: Cirka 0,43 MW for fremløb og 0,17 MW for retur.
# Varmetabet er domineret af temperaturer, flowets indflydelse er af 2. orden og negligeres her.
EQ_varmetabT(t,tr)  $(OnTrans(tr)) .. QTeLoss(t,tr)   =E=  BLen(t) * ([1.0 - exp(-alphaT(t,tr,'frem'))] * QTfMax(tr) +  [1.0 - exp(-alphaT(t,tr,'retur'))] * QTfMax(tr));

#OBS  Pumpearbejdet er reelt proportionalt med QTf^2, hvis modstandsfaktoren fD antages konstant (forudsætter højt minimum på QTf).
#HACK Linearisering af pumpeomkostninger: WpumpActual(t,tr) := Wpump(tr) * CostElecT(t) * QTf(t,tr) / QTfMax(tr);
EQ_CostPump(t,tr)   $OnTrans(tr)   .. CostPump(t,tr)  =E=  Wpump(tr) * [ ElspotActual(t) + TariffEigenPump(t) ] * QTf(t,tr) / QTfMax(tr);   # [DKK]

*end




*begin Slave model declaration

model modelSlave / all /;

*end Slave model declaration




#)


