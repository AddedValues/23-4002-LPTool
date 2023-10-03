$log Entering file: %system.incName%
#(
$OnText
Projekt:    23-4002 MEC LP Lastplanlægning
Scope:      Definerer fælles / tværgående sets, parameters, variables, equations for slavemodellen.
Filnavn:    DeclareGlobalSets.gms
$OffText

*begin SET ERKLÆRINGER

option strictSingleton = 0;

Set bound           'lblBounds'               / min, max /;

*begin Tidsmæssige sets og parametre.

Set             rhStep    'Rolling Horizon RHstep'  / s1 * s52 /;
Set             beginend                            / begin, end, endstep, len, lenstep, nhourhoriz, nhourstep /;
Set             begend     'Indikator start- slut'  / begin, end /;
Set             startslut  'Indikator start- slut'  / start, slut /;
Singleton set   actRHstep(rhStep);
alias (rhStep, rhStepAlias);

Set aggr      'Tidsblok-skemaer'                  / aggr1 * aggr6 /;         # En aggr udtrykker kombi af aggr-parametre, varmebehovsprofil og elprisfremskrivning.
Singleton set  actBlock(aggr) 'Aktuelt blokskema' / system.empty /;

# OBS Vedr. sets for tidspunkter:
#     set tt  er den basale tidsopløsning fx timeniveau.
#     set t   er den aktuelle tidsopløsning, som kan være aggregeret. set t bruges til at afgrænse tidsområdet for optimeringen.
#     set tRH er tidspunkterne i den aktuelle rullende horisont, og matcher tidsopløsningen i set t, dvs. tRH kan være et aggregeret tidspunkt.
#     Bemærk at set tt og set t begge anvender 't' som indeksnavn.

# TODO Set tt  shall be included $Include to allow for flexible time range.
Set tt         'Time intervals available at any resolution' / t1*t2016 /;  # Accomodates for 7 days at 5 min resolution.
Set t(tt)      'Actual time intervals';
Set tRH(tt)    'Time intervals for actual rolling horizon';
Set tbid       'Hours in bidding day' / t1 * t24 /;
#--- Set th         'Hours in planning period' / t1 * t500 /;
alias (tta, tt);
alias (ttb, tt);
alias (ta, t);

Singleton set actt(tt)            'Aktuelt tidspkt.'         / system.empty /;
Singleton set actb(tt)            'Aktuelt aggr. tidspkt.'   / system.empty /;

# OBS : Dette stmt: [ t(tt) = yes; ] er nødvendigt for senere at slukke for elementer i set t.
t(tt) = yes;

set tt2tbid(tt,tbid) 'Kobling mellem tt og tbid';
set tt2hh(tt,tta)    'Kobling mellem tt og timer';
set thh(tt)          'Subset af th';

tt2tbid(tt,tbid) = no;
tt2hh(tt,tta)    = no;


#--- Parameter MonthDays(mo)            'Antal døgn i hver måned' / mo1 31, mo2 28, mo3 31, mo4 30, mo5 31, mo6 30, mo7 31, mo8 31, mo9 30, mo10 31, mo11 30, mo12 31 /;
#--- Parameter MonthDaysAccum(mo)       'Akkum. antal døgn i måned';
#--- Parameter MonthHoursAccum(mo)      'Akkum. antal timer i måned';
#--- Parameter MonthTimeAccumAggr(mo)   'Akkum. antal tidspunkter i måned';   # Beregnes senere, når tidsaggregering er kendt.
#--- Parameter MonthFraction(mo)        'Månedens andel af året';
#--- MonthDaysAccum('mo1') = MonthDays('mo1');
#--- loop (mo $(ord(mo) GT 1), MonthDaysAccum(mo) = MonthDaysAccum(mo-1) + MonthDays(mo); );
#--- MonthHoursAccum(mo) = MonthDaysAccum(mo) * 24;
#--- tmp = sum(mo, MonthDays(mo));
#--- MonthFraction(mo) = MonthDays(mo) / tmp;
#--- display MonthDaysAccum, MonthHoursAccum, MonthFraction;

*end Tidsmæssige sets og parametre.

*begin Scenarier
Set scmas                      'Masterscenarier'         / scmas1 * scmas3 /;
Singleton Set actSc(scmas)     'Aktive masterscenarie'   / scmas1 /;

*end

Set dso                        'DSO typer '              / Alow, Ahigh, Blow, Bhigh, A0 /;
Set loadDSO                    'Ellast niveauer'         / low,  high, peak/;
Singleton set actDso(dso)      'Aktuel DSO type';


*begin Define label Set for ScenMaster
Set lblScenMas 'ScenMaster labels' /
              ActualMasterScen,
              # Tracking info
                  SaveTimestamp, ScenarioID, 
              # Controls for optimization
                  DumpPeriodsToGdx,
                # Tidsområde
                  LenRollHorizon, StepRollHorizon, LenRollHorizonOverhang, CountRollHorizon, 
                  OnCapacityReservation, DurationPeriod, HourBegin, HourEnd, HourBeginBidDay, HoursBidDay, 
                  TimeResolutionDefault, TimeResolutionBid, OnTimeAggr, AggrKind, 
              # Misc. controls.
                  QInfeasMax, OnVakStartFix, OnStartCostSlk, OnRampConstraints, ElspotYear, QdemandYear,
                  BottomLineScenMaster /;

*end Define label Set for ScenMaster

*begin Define label Set for ScenYear

Set lblScenYear 'Markedspriser, tariffer og afgifter' /
                  CalYear,
                # CO2 emission af el
                  CO2ElecMix,
                # Skatter og afgifter
                  TaxCO2Kvote, TaxNOx, TaxSOx, TaxBioElProd, TaxAffaldCO2, TaxAffaldVarmeBrutto, TaxAffaldTillaegBrutto, TaxAffaldVarmeNetto,
                  TaxAffaldTillaegNetto, TaxAffaldRGKRabat, TaxAffaldRGKRabatKrit, TaxCH4Kedel, TaxCH4Motor, TaxCH4RefusionPctKedel,
                  TaxCH4RefusionPctMotor, TaxCO2BioOlieKedel, TaxCO2FGOKedel, TaxCO2NGasKedel, TaxCO2NGasMotor, TaxCO2Biomasse, TaxCO2NGasKedelMax, TaxEnergiBioOlieKedel,
                  TaxEnergiFGOKedel, TaxEnergiNGasKedel, TaxEnergiNGasMotor, TaxEnergiBiomasse, TaxEnergiNGasKedelMax, TaxEnergiElQMax, TaxEnergiEl, TaxEnergiElReduc,
                  TaxNOxFlisKedel, TaxNOxPelletKedel, TaxNOxHalm, TaxNOxFGOKedel, TaxNOxBioOlieKedel, TaxNOxNGasKedel, TaxNOxNGasMotor, TaxNOxRefusionPctNGasKedel, TaxNOxRefusionPctNGasMotor,
                  TaxSOxFlis, TaxSOxPellet, TaxSOxHalm, TaxSOxBioOlie, TaxSOxFGO, TaxOverskudsVarme, TaxSOxAffald,
                # Tariffer på drivmidler
                  TariffDsoAlowLoadLow,  TariffDsoAlowLoadHigh,  TariffDsoAlowLoadPeak,                        # Tids-afhængige DSO-tariffer
                  TariffDsoAhighLoadLow, TariffDsoAhighLoadHigh, TariffDsoAhighLoadPeak,
                  TariffDsoBlowLoadLow,  TariffDsoBlowLoadHigh,  TariffDsoBlowLoadPeak,
                  TariffDsoBhighLoadLow, TariffDsoBhighLoadHigh, TariffDsoBhighLoadPeak,
                  TariffElFeedIn, TariffElFeedInAHigh, TariffElFeedInALow, TariffElFeedInBHigh, TariffElFeedInBLow, 
                  TariffElRaadighedAHigh, TariffElRaadighedALow, TariffElRaadighedBHigh, TariffElRaadighedBLow, 
                  TariffElEffektAHigh, TariffElEffektALow, TariffElEffektBHigh, TariffElEffektBLow,
                  TariffElTrade, TariffElTSO, TariffElProcess,
                  TariffOil, TariffNGas, TariffNGasSLK,
                  BottomLineYearScen /;

*end Define label Set for ScenYear

*end   Scenarier


*begin Prognoser og Raadigheder

set lblPrognoses      'Prognoser' /
                # Efterspørgsel og OV-effektgrænser
                  QdemHo, QdemSt, QmaxPtX, 
                # Elpriser og -tariffer
                  Elspot, TariffDsoLoad, 
                # Temperaturer
                  Tfrem, Tretur, Tamb, TSoil, MECBioE, 
                  TAir, TGround, TSea, TSewage, TDC, TArla, TBirn, TPtX
               /;

set lblThpSource(lblPrognoses) 'VP kildetemperaturer ' /
                  TAir, TGround, TSea, TSewage, TDC, TArla, TBirn, TPtX
               /;

set hpSource 'VP kildetyper' /
                  Air, Ground, Sea, Sewage, DC, Arla, Birn, PtX
               /;
               
set hpMapT(hpSource, lblThpSource) 'Korrespondance VP-type til VP-kildetemperatur' /
               Air.TAir, Ground.TGround, Sea.TSea, Sewage.TSewage, DC.TDC, Arla.TArla, Birn.TBirn, PtX.TPtx
               /; 

*end Prognoser og Raadigheder


*begin Nets, Plants and fuels

Set Owner               'Anlægsejere'              / MEC /;
set actor               'Aktører'                  / netHo, netSt, netMa /;
set net(actor)          'Forsyningsområder'        / netHo, netSt, netMa /;
set netq(net)           'Reale forsyningsområder'  / netHo, netSt /;
Set Produc(Actor)       'Producenter Alle'         / netHo, netSt, netMa /;   
alias (net, anet);

parameter NetId(net) 'Ordinal af element i set net';
NetId(net) = ord(net);

# TODO Overskudsvarme leverandører defineres her:
Set produExtR(Produc)   'Producenter eksterne+SV1' / system.empty /;
Set produExt(produExtR) 'Producenter eksterne'      / system.empty /;  # Producenter eksterne til forsyningsselskaberne.
Set producNet(produExt,net); #                      / system.empty /;  # Placering af eksist. eksterne producenter i områder.


Set fall              'Drivmidler og energikilder' / BioOlie, FGO, Ngas, Flis, Pellet,   Halm, Affald, HPA, 
                                                     Elec, Varme, Sol, Gratis, Stenkul, 
                                                     OV-Arla, OV-Arla2, OV-Birn, OV-PtX,
                                                     fossilFuel, biogenFuel, elecDrive, surplusHeat, ambientHeat /;

Set fPrimary(fall)    'Primaerenergier'             / fossilFuel, biogenFuel, elecDrive, surplusHeat, ambientHeat /;

Set f(fall)           'Drivmidler'                 / BioOlie, FGO, Ngas, Flis, Pellet, Halm, Affald, HPA, 
                                                     Elec, Varme, Sol, Gratis, Stenkul, 
                                                     OV-Arla, OV-Arla2, OV-Birn, OV-PtX /;
Set fbio(f)           'Biobraendsler'              / Flis, Pellet, Halm, HPA /;
Set fflis(f)          'Flisbraendsler'             / Flis, HPA /;
Set fmatr(f)          'Materielle drivmidler'      / BioOlie, FGO, NGas, Flis, Pellet, Halm, HPA, Affald, Stenkul /;
Set fov(f)            'Overskudsvarme'             / OV-Arla, OV-Arla2, OV-Birn, OV-PtX /;
Set fsto(f)           'Lagerbare brændsler'        / BioOlie, FGO, Flis, Pellet, Halm, HPA, Affald /;
Set fActive(f)        'Aktive fuels';
Singleton set actF(f) 'Aktuelt fuel';

Set co2kind           'Typer af CO2-emission'    / phys, regul /;
Set modseg            'Modelsegmenter'           / prod, lager, network /;

Alias(net,netT);
Alias(net,netF);


set uall 'Units (produktionsanlaeg inkl. VAK) og statistik'  /
    HoGk, HoOk, 
    StGk, StOk, StEk, 
    MaAff1, MaAff2, MaBio, MaCool, MaCool2, MaEk,  
    HoNhpAir, HoNhpSew, HoNEk, HoNFlis, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir, StNFlis, StNEk, 
    MaNbk, MaNEk, MaNhpAir, MaNbKV1, MaNhpPtX, 
    HoNVak, StVak, MaVak, MaNVak1, MaNVak2, 
    uaggr      # uaggr sammenfatter statistik for alle anlaeg.
   /;

set u(uall) 'Units (produktionsanlaeg inkl. VAK)'  /
    HoGk, HoOk, 
    StGk, StOk, StEk, 
    MaAff1, MaAff2, MaBio, MaCool, MaCool2, MaEk,  
    HoNhpAir, HoNhpSew, HoNEk, HoNFlis, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir,  StNFlis, StNEk, 
    MaNbk, MaNEk, MaNhpAir, MaNbKV1, MaNhpPtX, 
    HoNVak, StVak, MaVak, MaNVak1, MaNVak2
   /;
                      
set upr(u)  'Produktionsanlaeg excl. VAK' /
    HoGk, HoOk, 
    StGk, StOk, StEk, 
    MaAff1, MaAff2, MaBio, MaCool, MaCool2, MaEk,  
    HoNhpAir, HoNhpSew, HoNEk, HoNFlis, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir,  StNFlis, StNEk, 
    MaNbk, MaNEk, MaNhpAir, MaNbKV1, MaNhpPtX
   /;

set uBioKVV(upr) 'BioKVV'                    / MaNbKV1 /;
set uov(upr)     'Overskudsvarme VP'         / HoNhpArla, HoNhpArla2, HoNhpBirn, MaNhpPtX /;
set uptx(uov)    'VP knyttet til OV fra PtX' / MaNhpPtX /;
set upsr(upr)    'SR-produktionsanlaeg'      /
    HoGk, HoOk,
    StGk, StOk
   /;
   
set ugas(upsr) 'Gasfyrede anlaeg' / HoGk, StGk /;

set urHo(upr) 'Holstebro SR-produktionsanlaeg';    #---  / HoGk, HoOk /;   #---, HoNEk, MaEk, MaNEk  /;
set urSt(upr) 'Struer SR-produktionsanlaeg'   ;    #---  / StGk, StOk /;   #---, StEk,  StNEk  /;

                  
# OBS Elkedler kan ikke kun karakteriseres som spidslast efter Tarifmodel 3.0 er trådt i kraft pga. delvis omlægning til effektbetaling.
set urHo(upr) 'Holstebro SR-produktionsanlæg'  / system.empty /;  #--- / HoGk, HoOk /;   #---, HoNEk, MaEk  /;
set urSt(upr) 'Struer SR-produktionsanlæg'     / system.empty /;  #--- / StGk, StOk /;   #---, StEk,  StNEk  /;

   
set uq(upr) 'Varmeproducerende anlaeg (ikke KV)'  /
    HoGk, HoOk,  
    StGk, StOk, StEk,
    MaEk, 
    # NYE ANLaeG
    HoNhpAir, HoNhpSew, HoNEk, HoNFlis, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir, StNFlis, StNEk,
    MaNbk, MaNEk, MaNhpAir, MaNhpPtX 
   /;

set forcedOnUpr(upr) 'Tvangskoerte anlaeg hvis raadige' / MaAff1, MaAff2 /;

set usol(u)         'Solvarmeanlaeg'         / system.empty /;
                    
set cp(upr)         'Centrale anlaeg'        / MaAff1, MaAff2, MaBio, MaNbKV1 /;
set kv(upr)         'Kraftvarmeanlaeg'       / MaAff1, MaAff2, MaBio, MaNbKV1 /;
set kvaff(kv)       'Affaldsanlaeg'          / MaAff1, MaAff2 /;
set kvexist(kv)     'Eksist. KV-anlaeg'      / MaAff1, MaAff2, MaBio /;
set uaff(kv)        'Affaldsanlaeg'          / MaAff1, MaAff2 /;
set uaffupr(upr)    'Affaldsanlaeg'          / MaAff1, MaAff2 /;
set uaffexist(upr)  'Eksist. affaldsanlaeg'  / MaAff1, MaAff2 /;
set urgk(upr)       'RGK-anlaeg'             / system.empty /;
Set gm(upr)         'Gasmotorer'             / system.empty /;
Set gt(upr)         'Gasturbiner'            / system.empty /;

Set upraff(upr)  'Produktionsanlaeg som er affaldsanlaeg'  / MaAff1, MaAff2 /;
Set uprmaff(upr) 'Produktionsanlaeg paanaer affaldsanlaeg';
uprmaff(upr)    = yes;
uprmaff(upraff) = no;

Set uprbase(upr) 'Grundlastanlaeg' /
    MaAff1, MaAff2, MaBio, 
    MaNbk, MaNhpAir, MaNbKV1, MaNhpPtX, 
    HoNhpAir, HoNhpSew, HoNFlis, 
    HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir, StNFlis 
    /;

set ucool(u)             'Bortkoeleanlaeg'                              / MaCool, MaCool2 /;
set cool2net(ucool,net)  'Hvilke bortkoeleanlaeg i hvilket net'         / (MaCool, MaCool2).netHo /;
set aff2cool(uaff,ucool) 'Hvilke affaldsanlaeg til hvilket koeleanlaeg' / MaAff1.MaCool, MaAff2.MaCool2 /;

set uek(upr)   'El-kedler'            / HoNEk, MaEk, StEk, StNEk, MaNEk /;

Set hp(upr)    'Varmepumper (VP)'     /
    HoNhpAir, HoNhpSew, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir, 
    MaNhpAir, MaNhpPtX 
    /;

Set uelec(upr)      'Elkoblede anlæg'       / MaAff1, MaAff2, MaBio, MaEk, MaNEk, MaNhpAir, MaNbKV1, MaNhpPtx,
                                              HoNEk, HoNhpAir, HoNhpSew, HoNhpArla, HoNhpArla2, HoNhpBirn,  
                                              StEk, StNEk, StNhpAir
                                            /;

set uelprod(uelec) 'Elproducerende anlæg'   / MaAff1, MaAff2, MaBio, MaNbKV1 /;  


set uelcons(uelec) 'Elforbrugende anlæg'    / HoNEk, MaEk, StEk, StNEk, 
                                              HoNhpAir, HoNhpSew, HoNhpArla, HoNhpArla2, HoNhpBirn, 
                                              StNhpAir, 
                                              MaNhpPtx 
                                            /;


Set hp_air(hp)     'Luft-VP'                / HoNhpAir, StNhpAir, MaNhpAir /;
Set hp_sew(hp)     'Spildevands-VP'         / HoNhpSew /;
Set hp_Arla(hp)    'OV-Arla-VP'             / HoNhpArla, HoNhpArla2 /;
Set hp_Birn(hp)    'OV-Birn-VP'             / HoNhpBirn/;
Set hp_PtX(hp)     'PtX overskudsvarme'     / MaNhpPtX /;
Set hp_OV(hp)      'VP med OV-afgift'       / system.empty /;


Set unonco2(u)     'Anlaeg u. CO2-emission'      / MaBio, MaNbk, MaNbKV1, HoNFlis, StNFlis /;
Set uregulco2(u)   'Anlaeg m.regulat. CO2-emis'  /
    HoGk, HoOk, 
    StGk, StOk,
    MaAff1, MaAff2
    /;

Set uexist(u)         'Eksist. anlaeg'            /
    HoGk, HoOk, MaAff1, MaAff2, MaBio, MaCool, MaCool2,
    StGk, StOk, StEk,  
    MaEk, 
    HoNVak, StVak, MaVak, MaNVak1, MaNVak2
    /;

Set hpexist(u)         'Eksist. varmepumper'       /
    system.empty
    /;

Set unew(u)    'Nye anlaeg'   /
    HoNhpAir, HoNhpSew, HoNEk, HoNFlis, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    #--- HoNVak,  MaNVak1, MaNVak2, 
    StNhpAir,  StNFlis, StNEk,
    #--- StVak, 
    MaNbk, MaNEk, MaNhpAir, MaNbKV1, MaNhpPtX 
    /;
Set unewupr(unew)    'Nye produktionsanlaeg'   /
    HoNhpAir, HoNhpSew, HoNEk, HoNFlis, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir, StNFlis, StNEk,
    MaNbk, MaNEk, MaNhpAir, MaNbKV1, MaNhpPtX 
    /;
Set unewuq(unew) 'Nye varmeanlaeg' /
    HoNhpAir, HoNhpSew, HoNEk, HoNFlis, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir, StNFlis, StNEk,
    MaNbk, MaNEk, MaNhpAir, MaNhpPtX
    /;
Set unewhp(unew) 'Nye varmepumper'  /
    HoNhpAir, HoNhpSew, HoNhpArla, HoNhpArla2, HoNhpBirn, 
    StNhpAir,  
    MaNhpAir, MaNhpPtX
   /;

Set uopt(unew)       'Nye anlaeg som skal kapacitetsoptimeres';   
set unonopt(unew)    'Nye anlaeg som ikke skal kapacitetsoptimeres.';

set vakexist(uexist) 'Eksist. varmetanke' / MaVak, HoNVak, MaNVak1, MaNVak2, StVak /;
Set vaknew(u)        'Nye varmetanke'     / system.empty /;

set ucoolexist(uexist)   'Eksisterende bortkoeleanlaeg'    / MaCool, MaCool2 /;
set ucoolnew(unew)       'Nye bortkoeleanlaeg'             / system.empty /;

set uother(upr)          'Anlaeg som prioriteres efter OV' / system.empty /;
uother(upr) = not uaffupr(upr) and not uov(upr);



#--- set usol(u)       'Solvarmeanlæg'         / system.empty /;
#--- set cp(upr)       'Centrale anlæg'        / MaAff1, MaAff2, MaBio /;
#--- set kv(upr)       'Kraftvarmeanlæg'       / MaAff1, MaAff2, MaBio /;
#--- set kvaff(kv)     'Affaldsanlæg KV'       / MaAff1, MaAff2 /;
#--- set uaff(kv)      'Affaldsanlæg'          / MaAff1, MaAff2 /;
#--- set uaffupr(upr)  'Affaldsanlæg'          / MaAff1, MaAff2 /;
#--- set urgk(upr)     'RGK-anlæg'             / MaAff1, MaAff2 /;
#--- Set gm(upr)       'Gasmotorer'            / system.empty /;
#--- Set gt(upr)       'Gasturbiner'           / system.empty /;
#--- 
#--- Set upraff(upr)  'Produktionsanlæg som er affaldsanlæg'  / MaAff1, MaAff2 /;
#--- Set uprmaff(upr) 'Produktionsanlæg pånær affaldsanlæg';
#--- uprmaff(upr)    = yes;
#--- uprmaff(upraff) = no;
#--- 
#--- Set uprbase(upr) 'Grundlastanlæg' /
#---     MaAff1, MaAff2, MaBio, 
#---     MaNbk, MaNbKV1, MaNhpPtx,
#---     # NYE ANLÆG
#---     HoNhpAir, HoNhpSew, 
#---     HoNhpArla, HoNhpArla2, HoNhpBirn, 
#---     StNhpAir, StNFlis 
#---     /;
#--- 
#--- set ucool(u)   'Bortkøleanlæg'         / MaCool, MaCool2 /;
#--- set cool2net(ucool,net)  'Hvilke bortkøleanlæg i hvilket net'            / (MaCool, MaCool2).netHo /;
#--- set aff2cool(uaff,ucool) 'Hvilke affaldsanlæg til hvilket køleanlæg'     / MaAff1.MaCool, MaAff2.MaCool2 /;
#--- 
#--- set uek(upr)   'El-kedler'            / HoNEk, MaEk, StEk, StNEk /;
#--- 
#--- Set hp(upr)    'Varmepumper (VP)'     /
#---     HoNhpAir, HoNhpSew, HoNhpArla, HoNhpArla2, HoNhpBirn, 
#---     StNhpAir, MaNhpPtx
#---     /;
#--- 
#--- Set uelec(upr)      'Elkoblede anlæg'       / MaAff1, MaAff2, MaBio, MaNbKV1,  
#---                                               HoNEk, StEk, StNEk, MaEk, 
#---                                               HoNhpAir, HoNhpSew, HoNhpArla, HoNhpArla2, HoNhpBirn,  
#---                                               StNhpAir, 
#---                                               MaNhpPtx
#---                                             /; 
#--- 
#---                                             
#--- set uelprod(uelec) 'Elproducerende anlæg'   / MaAff1, MaAff2, MaBio, MaNbKV1 /;  
#--- 
#--- Set hp_air(hp)     'Luft-VP'                / HoNhpAir, StNhpAir /;
#--- Set hp_gw(hp)      'Grundvands-VP'          / System.empty /;
#--- Set hp_sew(hp)     'Spildevands-VP'         / HoNhpSew /;
#--- Set hp_DC(hp)      'Datacenter - VP'        / system.empty /; 
#--- Set hp_Arla(hp)    'OV-Arla-VP'             / HoNhpArla, HoNhpArla2 /;
#--- Set hp_Birn(hp)    'OV-Birn-VP'             / HoNhpBirn/;
#--- Set hp_PtX(hp)     'PtX overskudsvarme'     / MaNhpPtx /;
#--- Set hp_OV(hp)      'VP med OV-afgift'       / system.empty /;
#--- 
#--- 
#--- Set unonco2(u)     'Anlæg u. CO2-emission'      / MaBio /; 
#--- Set uregulco2(u)   'Anlæg m.regulat. CO2-emis'  /
#---     HoGk, HoOk, 
#---     StGk, StOk,
#---     MaAff1, MaAff2
#---     /;
#--- 
#--- # OBS MaNAff håndteres som et eksisterende anlæg, idet dets kapacitet er fikseret.
#--- Set uexist(u)         'Eksist. anlæg'            /
#---     HoGk, HoOk, MaAff1, MaAff2, MaBio, MaCool, MaCool2, 
#---     StGk, StOk, StEk, StVak, 
#---     MaEk, 
#---     MaVak, HoNVak, MaNVak1, MaNVak2
#---     /;
#--- 
#--- Set hpexist(u)         'Eksist. varmepumper'       /
#---     system.empty
#---     /;
#--- 
#--- Set unew(u)    'Nye anlæg'   /
#---     HoNhpAir, HoNhpSew, HoNEk, HoNhpArla, HoNhpArla2, HoNhpBirn, 
#---     #--- HoNVak,  MaNVak1, MaNVak2, 
#---     StNhpAir,  StNFlis, StNEk,
#---     #--- StVak, 
#---     MaNbk, MaNbKV1, MaNhpPtx
#---     /;
#--- Set unewuq(unew) 'Nye varmeanlæg' /
#---     HoNhpAir, HoNhpSew, MaNbk, HoNEk, HoNhpArla, HoNhpArla2, HoNhpBirn, MaNhpPtx,
#---     StNhpAir,  StNFlis, StNEk
#---     /;
#--- Set unewhp(unew) 'Nye varmepumper'  /
#---     HoNhpAir, HoNhpSew, HoNhpArla, HoNhpArla2, HoNhpBirn, MaNhpPtx,
#---     StNhpAir /;
#--- 
#--- set vakexist(uexist) 'Eksist. varmetanke' / MaVak, HoNVak, MaNVak1, MaNVak2, StVak /;
#--- Set vaknew(u)        'Nye varmetanke'     / system.empty /;
#--- 
#--- set ucoolexist(uexist)   'Eksisterende bortkøleanlæg'    / MaCool, MaCool2 /;
#--- set ucoolnew(unew)       'Nye bortkøleanlæg'             / system.empty /;



*begin Sets for transmissionsledninger.

set tr            'T-ledninger'        / tr1 * tr3 /;
set trkind        'Transmission kind'  / frem, retur /;
set trActive(tr)  'Aktive T-ledninger';

# Transmissionsledninger
set pipe              'Used DN pipe sizes'      / DN100, DN125, DN150, DN200, DN250, DN300, DN400, DN500, DN600, DN700, DN800, DN900, DN1000, DN1100, DN1200 /;
set lblpipe                                     / DN, Di, InsulDiam1, InsulDiam3, Roughness /;
set lblDataTransm     'T-ledning attributter'   / On, netF, netT, Lkm, DNmm, TFone, TRtwo, VelocMax, MinFlow, QTmax, Capex /;
set lblTrConfig       'T-ledning opsætning'     / netF, netT /;

singleton set actpipe(pipe) 'Aktuel rørdimension for given T-ledning';
singleton set acttr(tr)     'Aktuel T-ledning';

*end

Singleton set actU(u)     'Aktuelt anlæg';
Singleton set actUpr(upr) 'Aktuelt produktionsanlæg';
Set uActive(u)            'Aktive units u';
Set setOnUGlobal(u)       'Aktive units u';
Set setOnNetGlobal(net)   'Aktive net';
Set unewActive(unew)      'Aktive nye units';

alias(u,ualias);

*begin VAK sets

set vak(u)    'Varmetanke'  / MaVak, HoNVak, MaNVak1, MaNVak2, StVak /;

Singleton set actVak(vak) 'Aktuel VAK';

set vaknet(vak,net)      'Hvilke vak hører til hvilket net' /
   (MaVak, MaNVak1, MaNVak2).netMa, HoNVak.netHo, StVak.netSt 
   /;

set upr2vak(upr,vak)     'Hvilke prod-anlæg kan lade på vak' /
   (HoNEk).HoNVak, 
   (StNhpAir,  StNFlis, StNEk).StVak,
   (MaAff1, MaAff2, MaBio, MaEk, MaNbk, MaNbKV1, MaNhpPtx).(MaVak, MaNVak1, MaNVak2)
   /;
    
set tr2vak(tr,vak)       'Hvilke T-ledninger kan lade på vak' / tr1.StVak, tr2.HoNVak /;

set vak2tr(vak,tr)      'Hvilke tanke kan indføde på hvilke T-ledninger' /
   (MaVak, MaNVak1, MaNVak2).(tr1, tr2)
   /;

set tr2net(tr,net)      'Hvilke T-ledning til hvilke net' / (tr1.netSt), (tr2.netHo) /;
set net2tr(net,tr)      'Hvilke net til hvilke T-ledning' / netMa.(tr1,tr2) /;
set net2net(netF,netT)  'NetF kan forsynes netT'          / (netMa).(netHo, netSt)   /;


*begin Validering af set medlemsskab for anlæg u.
FoundError = FALSE;
loop (u,
  actU(u) = yes;
  if (uexist(u) AND unew(u),
    FoundError = TRUE;
    display "ERROR: actU er medlem af både unew og uexist.";
  elseif (NOT uexist(u) AND NOT unew(u) AND NOT vak(u)),
    FoundError = TRUE;
    display actU, "ERROR: actU er ikke medlem af hverken unew eller uexist.";
  );
);
if (FoundError,
  execute_unload "MecLpMain.gdx"; 
  display "ERROR: Inkonsistente set medlemsskaber for uexist og unew er fundet. Se display listings herover.";
  abort "ERROR: Inkonsistente set medlemsskaber for uexist og unew er fundet. Se display listings herover.";
);
*end

*begin Validering af set medlemsskab for VAK,

Scalar nUprOn     'Antal rådige prod.-anlæg';
Scalar nTrOn      'Antal rådige transm.ledninger';

FoundError = FALSE;
loop (vak,
  actVak(vak) = yes;
  tmp = 0;
  tmp = sum(upr $upr2vak(upr,vak), 1);
  if (tmp EQ 0,
    display actVak, tmp, "WARNING: actVak er ikke tilknyttet nogen produktionsanlæg.";
    
    # Check først om en vak uden indfødende prod.-anlæg kan oplades fra en T-ledning, inden der meldes fejl.
    nTrOn = 0;
    loop (tr,
       if (tr2vak(tr,vak), nTrOn = nTrOn + 1; );
    );
    if (nTrOn EQ 0,
      FoundError = TRUE;
      display actVak, "ERROR: actVak ovenfor er hverken tilknyttet indfødende produktionsnlæg eller T-ledning";
    );
  );
);
if (FoundError,
  display actVak, "ERROR: Inkonsistente set medlemsskaber af upr2vak hhv. tr2vak er fundet. Se display listings herover.";
  abort "ERROR: Inkonsistente set medlemsskaber af upr2vak hhv. tr2vak er fundet. Se display listings herover.";
);
*end


*end VAK sets


set tax               'tax kinds'               / afv, atl, ch4, co2, nox, sox, ets, enr, VE, Oversk /;  # aff-varme, aff-tillæg, metan, co2, nox, sox, kvote, energi, tilskud, Overskudsvarmeafgift.

Set taxaff(tax)       'taxes for waste'         / afv, atl /;
Set taxs(tax)         'taxes but enr'           / ch4, co2, nox, sox/;                           # afgifter pånær kvote samt energi- og affaldsafgifter.
Set taxkv(tax)        'taxes but enr,co2'       / ch4, nox, sox /;                               # afgifter pånær kvote samt energi- og affaldsafgifter.
Set taxkv2(tax)       'taxes based on fuelheat' / enr, co2 /;                                    # afgifter, som pålægges brændsel til varmeproduktion i KV-anlæg.
Set m                 'Machine kind'            / kedel, motor, kv, vp /;

Set lblDataU          'Labels for DataU'        / Idriftsat, Omraade, KvoteOmfattet, Aggregat, CapacQ, ModuleSize, Fmin, Fmax, EtaQ, EtaP, ElEig0, ElEig1, 
                                                  DSO, RampUp, RampDown, StartOmkst, StopOmkst, VarDVOmkst, 
                                                  LoadRateVak, VAKChargeCost, VAKLossRate, LossGain, DoFixVak, FracFixVAK, VakMin, VakMax, SR /;

Set lblDataAff        'Labels for DataAff'      / FrakAux, FrakBio, FrakTLafgift, FrakCO2Afgift, FrakNOxAfgift, FrakSOxAfgift, FrakVETilskud,
                                                  CO2Emission, NOxEmission, SOxEmission, HKCO2vsLHV, KstCO2vsLHV,
                                                  QRgasKond, QmaxModtryk, Pmax, EtaBoil, EtaHeat, EtaPower, PowInMax, EtaRGK,
                                                  AndelVarmeSiden, AndelAffaldSiden, DVOmkstRGK, TransAffaldOmkst /;

# REMOVE Set lblTimeseries     'Labels for time series'   / Tfrem, Tamb, Tsoil /;

Set lblTaxes          'Labels for afgifter'      / TaxNoxFlis, TaxNOxHalm, TaxNOxFGO, TaxCO2FGO, TaxEnergiFGO, TaxElvarme, TariffDSO, TariffTSO, TariffTrade,
                                                   TaxQEl, TaxNOxAffald, TaxCO2Affald, TaxEnergiAffald, TaxtillaegAffald, TaxtillaegRabat,TaxCO2KvoteNgas /;
set lblCHP                                       / a1_PQ, a0_PQ, Pmax, Pmin, Eformel, EtaQ, Fmin, Fmax, EtaP, Qbypass, OnRGK, QRGKMax, VarDVOmkstRgk, Qmax, DVBypass /;

Set lblBrandsel       'Drivmiddel parms'         / PrisEnhed, PrisGJ, PrisMWh, Densitet, LHV, FossilAndel, CO2emis, SOXemis, CO2emisMWh, LhvMWh /;

Set pipeDataSet       'Pipe data elements'       / PowerMax, Cost, DNnumber /;

Set lblDiverse        'Diverse labels'           / LhvNgasMJm3, StruerAndel, DKKUSD, DKKEUR, 
                                                   Infla15to19, Infla15to21, Infla15to20, Infla21to22, Infla20to22, Infla15to22, Infla15to23, Infla20to23, Infla21to23, Infla22to23 /;


set InfeasDir          'Infeas direction'  / source, drain /;

$OffOrder

set unonkv(u) 'Non KV produktionsanlæg';
unonkv(upr) = NOT kv(upr);

$OnOrder

*end Plants and fuels


*begin Capacity allocations

set updown            'Up-Down regulation'            / up, down /;
set elmarket          'Electricy markets'             / FCR, aFRR, mFRR /;
set planZone          'Planning zone: Bid or default' / Default, Bid /;
set planPhase         'Planning phase'                / FCR, aFRR, mFRR, dayAhead, intraDay /;
set lblElMarket       'Elmarkeds egenskaber'          / Active, Symmetric, Up, Down, PriceAvail, PriceUp, PriceDown, BidMin, TimeToFull /;

*end Capacity allocations

*begin Other sets
Set onoff             'on-off markør'                              / on, off /;
Set startstop                                                      / start, stop /;
Set other             'Other items, plants' / ucool /;
Set secondOrderFcn    'Coefficients for a second order function'   / intercept, 1st, 2nd /;
Set lineSet           'Parameters for the line equation'           / intercept, slope /;
Set COPSet            'Different COP sets'                         / 70_out, 50_out, flexCOP /;
Set lblHpCop           / Tdesign, dTkilde, Tfrem, Tretur, EtaHp, intcp, 1st, 2nd, min, max /;
Set lblCOPyield        / COP, Yield /;
Set traCapacOthersSet  / Existing, NewMax /;

Set mapHp2Source(hp,hpSource) 'Map VP til varmekildetype';

mapHp2Source(hp,hpSource) = no;
mapHp2Source(hp_air,  'air')    = yes;
mapHp2Source(hp_sew,  'sewage') = yes;
mapHp2Source(hp_Arla, 'Arla')   = yes;
mapHp2Source(hp_Birn, 'Birn')   = yes;
mapHp2Source(hp_PtX,  'PtX')    = yes;

*end Other sets

*begin Sets for statistics

# NB: Disse sets til statistik skal defineres før alle andre, som indeholder medlemmer med samme navn.
#     En besynderlighed ved GAMS er, at rækkefølgen af Set-members fastlægges i den rækkefølge, hvori de defineres på tværs af sets.
#     Og dermed bliver rækkefølge af udskrivning af stats vha. GDXXRW afhængig af rækkefølgen for definition af sets.

Set cpStatType 'Stats typer for centrale anlæg' / QRGK, Pbrut, Pnet, Q, QRGKShare /;

Set topicAll 'Overall statistics' /
    ElspotPrice, SlaveObj, VPO, 
    HeatProduced, HeatDelivered, SrHeatHo, SrHeatSt, ViolateHo, ViolateSt
    /;

Set topicSolver 'GAMS Solver stats' /
    DateTime, ModelStat, SolveStat, TimeSolve, TimeSolverOnly,
    NIteration, NVar, NDiscrVar, NEquation, NInfeas,
    Objective, ObjectiveBest, Gap, SumInfeas
    /;
    
Set topicU     'Prod unit stats' /
    FullLoadHours, OperHours, BypassHours, RGKhours,
    NStart, CO2QtyPhys, CO2QtyRegul, PowInU, FuelQty,
    FuelConsumed, PowerGen, PowerNet, HeatGen, HeatCool, HeatBypass, HeatRGK,
    RGKshare,
    ElEgbrug,
    HeatMargPrice,
    SalesPower, #--- ElTilskud,
    CO2Kvote, TotalElIncome,
    FuelCost, DVCost, StartCost, ElCost, TotalCost, TotalTax,
    EtaPower, EtaHeat, PowInMax, ElSpotIncome,
    CapEAllocMWhUp, CapEAllocMWhDown     /;

Set topicMecU     'MEC anlægs-stats' /
    OperHours, BypassHours, Rgkhours,
    TurnOver, RealPowerPriceBuy, RealPowerPriceSell,
    NStart, CO2QtyPhys, CO2QtyRegul, PowInU, FuelQty,
    PowerNet, HeatGen, HeatCool, HeatSent, HeatBackPressure, HeatBypass, HeatRGK, HeatMargPrice,
    PowerSales,
    FixCostTotal, FixCostElTariff, DeprecCost,
    TotalCost, FuelCost, DVCost, StartCost, ElCost, TotalMargCost, TotalTax, CO2KvoteCost,
    CapacCost, ContribMargin, HeatCapacPrice, HeatTotalPrice
    /;
    
Set topicMecF 'MEC Brændsels-stats' / Qty, Pris, CO2QtyPhys, CO2QtyRegul /;

#--- Set topicMecF     'MEC brændsels-stats' /    
#---    ElspotPris, AffaldsPris, HalmPris, FlisPris, HpaPris, GasPris, OliePris, OV-ArlaPris, OV-Arla2Pris, OV-BirnPris, OV-PtXPris, 
#---    CO2KvotePris
#---    /;

Set topicT        'Transmission stats' / QSent, QLost, CostPump /;
Set topicWind     'Prod unit stats'    / TotalDbElWind, TotalPWindHp, TotalPWindActual /;
Set topicVak      'Vak stat topics'    / MMax, QLoss, Turnover /;  # MMax er højeste værdi af nyttemassen (toplag for varm/lunken tank, bundlag for kold tank).
Set topicOther    'Other topics'       / HeatVented /;
Set topicFuel     'Fuel topics'        / Qty, CO2QtyPhys, CO2QtyRegul /;

Set topicMasOvwPer      'Master overview topics for periods'    / MargObjOptim, HeatGenNewOptim, HeatGenAllOptim, HeatVentedOptim,
                                                                  HeatMargCostAllOptim, HeatCapCostAllOptim, HeatMargCostNewOptim, HeatCapCostNewOptim,
                                                                  HeatCostAllOptim, HeatCostNewOptim, HeatSentOptim /;
Set topicMasOvwNet      'Master overview topics for nets'       / QDemandAnnual, QDemandPeak, QDemandAvg, NProjNet, CapUExcess /;
Set topicMasOvwUNew     'Master overview topics for units unew' / CapU, dCapU, dCapUOfz, NProjU, bOnInvestU /;
Set topicMasOvwU        'Master overview topics for units u'    / CapUCost, HeatCapCostU, HeatMargCostU, HeatCostU, HeatGenU, FLH, PowInU, OperHours,
                                                                  FuelQtys, CO2QtyPhys, CO2QtyRegul, Power, ElEgbrug /;
Set topicMasOvwT        'Master overview topics for T-lines'    / HeatSent, HeatLost,CostPump /;
Set topicMasOvwFuel     'Master overview topics for periods'    / CO2QtyPhys, CO2QtyRegul /;



*end Sets for statistics

*end SET ERKLÆRINGER

$If not errorfree $exit

#)