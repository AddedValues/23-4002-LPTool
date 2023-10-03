$log Entering file: %system.incName%
$OnText
Projekt:    23-4002 MEC LP Lastplanlægning
Filnavn:    PrepareSlave.gms
$OffText
#(
*begin Overførsel og validering af master scenarie.

DumpPeriodsToGdx = ActScen('DumpPeriodsToGdx');
if (DumpPeriodsToGdx LT 0 OR DumpPeriodsToGdx GT 2, execute_unload "MecLpMain.gdx"; abort 'DumpPeriodsToGdx skal være 0, 1 eller 2'; );

*begin Rolling Horizon

LenRHhoriz       = ActScen('LenRollHorizon');
LenRHstep        = ActScen('StepRollHorizon');
LenRHoverhang    = ActScen('LenRollHorizonOverhang');
CountRollHorizon = ActScen('CountRollHorizon');  # Antal ønskede inddelinger af rullende horisont inkl. sidste trin.
display LenRHhoriz, LenRHstep, CountRollHorizon;

if (LenRHstep  LT 1 OR LenRHstep  GT LenRHhoriz, execute_unload "MecLpMain.gdx"; abort 'LenRHstep er mindre end 1 eller større end LenRHhoriz.'; ); 
if (LenRHhoriz LT 1 OR LenRHhoriz GT 8760,       execute_unload "MecLpMain.gdx"; abort 'LenRHhoriz er mindre end 1 eller større end 8760.'; ); 

LenRHhorizSave = LenRHhoriz;
LenRHstepSave  = LenRHstep;

*end Rolling Horizon


*begin Tidsinterval
    
OnCapacityReservation  = ActScen('OnCapacityReservation');
DurationPeriod         = ActScen('DurationPeriod');
HourBegin              = ActScen('HourBegin');
HourEnd                = ActScen('HourEnd');
HourBeginBidDay        = ActScen('HourBeginBidDay');
HoursBidDay            = ActScen('HoursBidDay');
OnTimeAggr             = ActScen('OnTimeAggr');         
AggrKind               = ActScen('AggrKind');      
     
UseTimeAggr            = (OnTimeAggr NE 0);

TimeResolution('Default')  = ActScen('TimeResolutionDefault');
TimeResolution('Bid')      = ActScen('TimeResolutionBid');
TimeScale(planZone)        = 60 / TimeResolution(planZone);
TimeScaleInv(planZone)     = 1.0 / TimeScale(planZone);
UseTimeExpansion(planZone) = (TimeResolution(planZone) NE 60);
UseTimeExpansionAny        = UseTimeExpansion('Default') OR UseTimeExpansion('Bid');
HourEndBidDay              = HourBeginBidDay + HoursBidDay - 1;
TimeIndexBeginBidDay       = (HourBeginBidDay - 1) * TimeScale('Default') + 1;
TimeIndexEndBidDay         = TimeIndexBeginBidDay + HoursBidDay * TimeScale('Bid') - 1;
  
# Check at set tt kan rumme planperioden med de givne tidsopløsninger.
Ntime = TimeScale('Default') * (DurationPeriod - HoursBidDay ) + TimeScale('Bid') * HoursBidDay;
display Ntime;
if (Ntime GT card(tt),
    execute_unload "MecLpMain.gdx";
  display "ERROR: Der er ikke reserveret plads til planperiodens tidspunkter, idet Ntime > card(tt)", Ntime;
  abort   "ERROR: Der er ikke reserveret plads til planperiodens tidspunkter, idet Ntime > card(tt)";
);  
  
# Check at TimeResolution opdeler en time i et helt antal tidspunkter.

loop (planZone,                                   
  if (mod(60, TimeResolution(planZone)) NE 0.0,
    display 'TimeResolution(planZone) opdeler IKKE en time i et helt antal tidspunkter', TimeResolution;
    abort   'TimeResolution(planZone) opdeler IKKE en time i et helt antal tidspunkter';
  );
                                   
  if (UseTimeAggr AND UseTimeExpansion(planZone), 
    execute_unload "MecLpMain.gdx";
    display 'Tidsaggregering og Tidsekspandering kan ikke begge være aktive i mindst én planZone', OnTimeAggr, TimeResolution;
    abort   'Tidsaggregering og Tidsekspandering kan ikke begge være aktive i mindst én planZone';
  );
);

# REMOVE PeriodFrac = DurationPeriod / card(tt);  

*end Tidsinterval


*begin Overfør scenarieparametre fælles for anlæg.

QInfeasMax        = ActScen('QInfeasMax');
OnVakStartFix     = ActScen('OnVakStartFix');
OnStartCostSlk    = ActScen('OnStartCostSlk');
OnRampConstraints = ActScen('OnRampConstraints');
ElspotYear        = ActScen('ElspotYear');
QDemandYear       = ActScen('QDemandYear');

*end


*begin CHECK Fordeling af DataU på forbrugsområder.

OnTrans(tr)   = DataTransm(tr,'On');
OnNet(net)    = OnNetGlobal(net);
OnUNet(u,net) = (DataU(u,'Omraade') EQ OmrCode(net)) AND OnNet(net);  # Angiver at anlæg u tilhører et givet net.

Scalar Found 'Angiver at forbrugsområde blev fundet for DataU-unit';
loop (u, 
  Found = 0;
  actU(u) = yes;
  loop (net,
    if (OmrCode(net) EQ DataU(u,'Omraade'),
      AvailUNet(u,net) = OnNetGlobal(net) AND OnUGlobal(u);
      Found = 1;
    );
  );
  if (NOT Found, 
    execute_unload "MecLpMain.gdx"; 
    display "ERROR: Fejl i Område-angivelse for mindst et anlæg (se actU) i tabellen DataU.", actU, AvailUNet, OnNetGlobal, OmrCode, DataU;
    abort "Fejl i Område-angivelse for mindst et anlæg i tabellen DataU."; 
  );
);                                

*begin Check at mindst eet anlæg tilknyttet en VAK er aktivt.
Scalar NActiveUpr "Tæller antal aktive anlæg knyttet til given VAK";
Loop (vak $OnUGlobal(vak),
  actVak(vak) = yes;
  NActiveUpr = 0;
  Found = FALSE;
  Loop (upr $OnUGlobal(upr),
    If (upr2vak(upr,vak), 
      Found = TRUE;
      NActiveUpr = NActiveUpr + 1 $OnUGlobal(upr); 
    );
  );
  If (Found AND NActiveUpr EQ 0,
    display "WARNING: VAK actVak har ingen aktive tilknyttede anlæg. VAK deaktiveres.", actVak;
    OnUGlobal(actVak) = FALSE;
    AvailUNet(actVak,net) = FALSE;
  );
);

#--- RealRente     = InterestRate - InflationRate + 1E-7;    # Adderes med 1E-7 for at undgå division by zero hvis realrenten er 0.
#--- PmtTransmPipe = (RealRente) / (1-(1+RealRente)**(-InvLenTransmPipe));
#--- PmtTransmPump = (RealRente) / (1-(1+RealRente)**(-InvLenTransmPump));

*end 

display AvailUNet;



*begin Aktive anlæg

setOnNetGlobal(net) = OnNetGlobal(net);
setOnUGlobal(u)     = (OnUGlobal(u) GT 0 AND NOT vak(u));

uActive(u) = no;
loop (net $OnNetGlobal(net),
  loop (u $(AvailUNet(u,net) AND NOT vak(u)),
    uActive(u) = yes;
  );
);

unewActive(unew) = no;
loop (net $OnNetGlobal(net),
  loop (unew $(AvailUNet(unew,net)),
    unewActive(unew) = yes;
  );
);
display uActive, setOnNetGlobal, setOnUGlobal, unewActive;

*end

*end Fordeling af DataU på forbrugsområder.

*end Overførsel og validering af master scenarie.

*begin Anlægsspecifikationer

*begin Sikre at at alle definerede produktionsanlæg også har en linje i tabellen DataU.

tmp = 0;
loop (upr $(NOT kv(upr)),
  if (DataU(upr,'Omraade') EQ 0,
    tmp = 1;
    actUpr(upr) = yes;
    display 'Dette anlæg mangler i tabellen DataU:', actUpr;
  );
);
if (tmp > 0, abort 'Mindst eet produktionsanlæg upr mangler i tabellen DataU. Se navnene i listing.')  ;
*end

*begin Virkningsgrader

TaxEForm(kv) = CHP(kv,'EFormel');

EtaPU(u) = DataU(u,'EtaP');
EtaQU(u) = DataU(u,'EtaQ');
EtaTU(u) = EtaPU(u) + EtaQU(u);

loop (upr,
     StartCost(upr) = DataU(upr,'StartOmkst') + DataU(upr,'StopOmkst');
     PnetMin(upr)   = 0.0;
     );

AffAux(uaff) = EtaQU(uaff) / (EtaPU(uaff) + EtaQU(uaff));

*end


*begin Aktive brændsler

fActive(f) = no;
OnFuel(f) = 0;
loop (upr $OnUGlobal(upr),
  actUpr(upr) = yes;
  loop (f, 
    if (FuelMix(upr,f) GT 0.0, OnFuel(f) = TRUE; ); 
  );
);
fActive(f) = OnFuel(f);
display OnFuel, fActive;


* Opstil parm FuelMix og omdan brændselsdata til MWh basis.
* FuelMix er nødvendig for at håndtere afgifter på en struktureret måde.
loop (f,
  If (FuelCode(f) LE 0 OR FuelCode(f) GT card(f), execute_unload "MecLpMain.gdx"; abort "PrepareSlave: At least one fuel member is not valid");
  LhvMWhPerUnitFuel(f)    = Brandsel(f,'LhvMWh');  # LHV pr brændselsenhed 
  CO2ProdTonMWh(f) = Brandsel(f,'CO2emisMWh') / 1000;  # Fra kg/MWh til ton/MWh.
);

* Test af vægtet LHV.
Parameter LhvProdU(upr) 'Temporær beregning af DataU brændværdi';
LhvProdU(upr) = sum(f, FuelMix(upr,f) * LhvMWhPerUnitFuel(f));

Parameter SumFuelMix(upr);
SumFuelMix(upr) = sum(f,FuelMix(upr,f));
display SumFuelMix;
display FuelMix, LhvMWhPerUnitFuel, CO2ProdTonMWh, LhvProdU;

loop (upr $OnUGlobal(upr), 
  tmp = sum(f,FuelMix(upr,f));
  If (sum(f,FuelMix(upr,f)) NE 1, execute_unload "MecLpMain.gdx"; abort "Fuel fractions do not all sum to one."; );
);
*end
                 

*begin Sikring at en rådig VAK har mindst eet rådigt produktionsanlæg tilknyttet. 

display OnUGlobal, upr2vak;
loop (vak $OnUGlobal(vak),
  actVak(vak) = yes;
  nuprOn = 0;
  loop (upr $OnUGlobal(upr),
    if (upr2vak(upr,vak), nUprOn = nUprOn + 1;  );
    actUpr(upr) = yes;
  );
  nTrOn = 0;
  loop (tr $OnTransGlobal(tr),
     if (tr2vak(tr,vak), nTrOn = nTrOn + 1; );
  );
  if (nUprOn EQ 0 AND nTrOn EQ 0,
    execute_unload "MecLpMain.gdx"; 
    display "ERROR: Ingen af de tilknyttede anlæg eller transmissionslinjer til den rådige VAK (actVak) er aktive. :", actVak;
    abort "ERROR: Ingen af de tilknyttede anlæg eller transmissionslinjer til den rådige VAK (actVak) er aktive.";
  );
);

*end 


*begin VAK parametre

#--- loop (vak,
#---   If (DataU(vak,'FracFixVak') < 0 OR DataU(vak,'FracFixVak') > 1, execute_unload "MecLpMain.gdx"; abort "DataU(vak,'FracFixVak') out-of-range"; );
#--- );

LVak.L(tt,vak) = 0.0;

*end VAK parametre


*begin Raadigheder

# Revisionsperioder overtrumfer raa raadigheder.
# Revision_hh == 0 angiver ingen revision.
# OnURevision == 0 angiver, at Revision_hh skal ignoreres.

OnU_hh(tt,u)  = Availability_hh(tt,u) $OnUGlobal(u);
OnU_hh(tt,cp) = Availability_hh(tt,cp) $(OnUGlobal(cp) AND (NOT Revision_hh(tt,cp) OR NOT OnURevision(cp)));

# Initialisering af periodens nominelle Raadigheder.
OnUNet(u,net) = OnUGlobal(u) AND OnNetGlobal(net) AND AvailUNet(u,net);

# SR-status
urHo(upr) = OnUNet(upr,'netHo') AND DataU(upr,'SR') GT 0;
urSt(upr) = OnUNet(upr,'netSt') AND DataU(upr,'SR') GT 0;

# MBL: Bortkølere skal deaktiveres, hvis de(t) tilkoblede affaldsanlæg ikke er aktive.
loop (ucool $OnUGlobal(ucool),
  loop (tt,
    tmp = 0;
    loop (uaff,
      tmp = tmp + 1 $(OnU_hh(tt,uaff) AND aff2cool(uaff,ucool));
    );
    OnU_hh(tt,ucool) = 1 $(tmp);
  );
);

*end Raadigheder

*end Anlægsspecifikationer

*begin Overførsel og validering af årsscenarier.


*end Overførsel og validering af årsscenarier.

*begin Overførsel fra tabellen Prognoses

QDemandActual_hh(tt,'netHo') = Prognoses_hh(tt,'QdemHo');
QDemandActual_hh(tt,'netSt') = Prognoses_hh(tt,'QdemSt');
QmaxPtx_hh(tt)               = Prognoses_hh(tt,'QmaxPtX');
                       
ElspotActual_hh(tt)          = Prognoses_hh(tt,'Elspot');
TariffDsoLoad_hh(tt)         = Prognoses_hh(tt,'TariffDsoLoad');

THeatSource_hh(tt,'air')    = Prognoses_hh(tt,'Tair');
THeatSource_hh(tt,'Ground') = Prognoses_hh(tt,'TGround');
THeatSource_hh(tt,'Sea')    = Prognoses_hh(tt,'TSea');
THeatSource_hh(tt,'Sewage') = Prognoses_hh(tt,'TSewage');
THeatSource_hh(tt,'DC')     = Prognoses_hh(tt,'TDC');
THeatSource_hh(tt,'Arla')   = Prognoses_hh(tt,'TArla');
THeatSource_hh(tt,'Birn')   = Prognoses_hh(tt,'TBirn');
THeatSource_hh(tt,'PtX')    = Prognoses_hh(tt,'TPtX');

#--- TNet_hh(tt,'Tfrem')   = Prognoses_hh(tt,'Tfrem');
#--- TNet_hh(tt,'Tretur')  = Prognoses_hh(tt,'Tretur');
#--- TNet_hh(tt,'Tamb')    = Prognoses_hh(tt,'Tamb');

*end Overførsel fra tabellen Prognoses

*begin Overførsel fra tabellen Diverse

OwnerShare('tr1') = Diverse('StruerAndel');
OwnerShare('tr2') = 1 - Diverse('StruerAndel');
      
*end Overførsel fra tabellen Diverse

*begin Beregning af COP- og varmeydelses-profiler.

# Tilknyt en varmekildetype til hver VP.
DataHp(hp_Air,  lblHpCop, lblCopYield) = DataHpKind(lblHpCop, 'Air',    lblCopYield);
#--- DataHp(hp_Gw,   lblHpCop, lblCopYield) = DataHpKind(lblHpCop, 'Ground', lblCopYield);
#--- DataHp(hp_Sea,  lblHpCop, lblCopYield) = DataHpKind(lblHpCop, 'Sea',    lblCopYield);
#--- DataHp(hp_DC,   lblHpCop, lblCopYield) = DataHpKind(lblHpCop, 'DC',     lblCopYield);
DataHp(hp_Sew,  lblHpCop, lblCopYield) = DataHpKind(lblHpCop, 'Sewage', lblCopYield);
DataHp(hp_Arla, lblHpCop, lblCopYield) = DataHpKind(lblHpCop, 'Arla',   lblCopYield);
DataHp(hp_Birn, lblHpCop, lblCopYield) = DataHpKind(lblHpCop, 'Birn',   lblCopYield);
DataHp(hp_PtX,  lblHpCop, lblCopYield) = DataHpKind(lblHpCop, 'PtX',    lblCopYield);

Parameter TempHp(tt,hp);
#---- Loop (hp,   
#----   #--- TempHp(tt,hp) = DataHp(hp,'Tsupply','COP') - Timeseries(tt,'Tfrem') + Timeseries(tt,'Tamb');
#----   TempHp(tt,hp)      = sum(mapHp2Source(hp,hpSource), THeatSource_hh(tt,hpSource));
#----   COP_hh(tt,hp)      = (DataHp(hp,'2nd','COP') * TempHp(tt,hp) + DataHp(hp,'1st','COP')) * TempHp(tt,hp) + DataHp(hp,'intcp','COP');
#----   QhpYield_hh(tt,hp) = min( DataHp(hp,'max','Yield') , [(DataHp(hp,'2nd','Yield') * TempHp(tt,hp) + DataHp(hp,'1st','Yield')) * TempHp(tt,hp) + DataHp(hp,'intcp','Yield')] ); 
#----   YieldMin(hp)       = smin(tt, QhpYield_hh(tt,hp));
#----   COPmin(hp)         = smin(tt, COP_hh(tt,hp));
#---- ); 

Parameter TKildeInd(tt)  'Kildetemperatur indgående i Kelvin';
Parameter TKildeUd(tt)   'Kildetemperatur udgående i Kelvin';
Parameter TDraenInd(tt)  'Draentemperatur indgående i Kelvin';
Parameter TDraenUd(tt)   'Draentemperatur udgående i Kelvin';
Parameter TlmKilde(tt)   'Log. middel kildetemperatur (varmekilde)';
Parameter TlmDraen(tt)   'Log. middel draentemperatur (FJV)';

Loop (hp,   
  TempHp(tt,hp)      = sum(mapHp2Source(hp,hpSource), sum(lblThpSource, THeatSource_hh(tt,hpSource) $hpMapT(hpSource,lblThpSource) ) );
  #--- TkildeInd(tt)      = TKelvin + TempHp(tt,hp);
  #--- TKildeUd(tt)       = TKildeInd(tt) - DataHp(hp,'dTkilde','COP');  # Antagelse: VP drives med konstant temperaturfald på varmekilden
  #--- TDraenInd(tt)      = TKelvin + DataHp(hp,'Tretur','COP');
  #--- TDraenUd(tt)       = TKelvin + DataHp(hp,'Tfrem', 'COP');
  #--- TlmKilde(tt)       = (TKildeInd(tt) - TKildeUd(tt)) / log(TKildeInd(tt) / TKildeUd(tt));
  #--- TlmDraen(tt)       = (TDraenUd(tt) - TDraenInd(tt)) / log(TDraenUd(tt)  / TDraenInd(tt));
  #--- COP_hh(tt,hp)      = DataHp(hp,'EtaHp','COP') * (TlmDraen(tt) / (TlmDraen(tt) - TlmKilde(tt))); 
  
  COP_hh(tt,hp)      = (DataHp(hp,'2nd','COP') * TempHp(tt,hp) + DataHp(hp,'1st','COP')) * TempHp(tt,hp) + DataHp(hp,'intcp','COP');
  
  QhpYield_hh(tt,hp) = min( DataHp(hp,'max','Yield') , [(DataHp(hp,'2nd','Yield') * TempHp(tt,hp) + DataHp(hp,'1st','Yield')) * TempHp(tt,hp) + DataHp(hp,'intcp','Yield')] ); 
  YieldMin(hp)       = smin(tt, QhpYield_hh(tt,hp));
  COPmin(hp)         = smin(tt, COP_hh(tt,hp));
); 

*end 

*begin Kapacitetsallokeringer

CapEReservationSum(tbid,updown)  = sum(elmarket, CapEReservation(tbid,elmarket, updown));


*end Kapacitetsallokeringer

execute_unload "MecLpMain.gdx";


*begin Initialisering af max. indfyret effekt.
CapQU(u)       = DataU(u,'CapacQ');
PowInUMax(upr) = DataU(upr,'CapacQ') / EtaQU(upr) * 1 $OnUGlobal(upr);  # Indlæst EtaQU er sat til 1.0 for VP.
PowInUMax(kv)  = CHP(kv,'Fmax') $OnUGlobal(kv);
PowInUMax(hp)  = PowInUMax(hp) / COPmin(hp) * 1 $OnUGlobal(hp);   

*end Initialisering af max. indfyret effekt.

# HACK Carbon capture anlæg ikke aktuelt i modellen (endnu).
#--- uCC(cc) = 0.0;
                   
*begin Struers ejerandel af grundlastvarmen.

# Reglen er, at Struer må trække mere transmissionsvarme end ejerandelen tilsiger,
# hvis Holstebro ikke udnytter sin andel.
# Hvis Holstebros SR-anlæg er aktiv, så tolkes det som at Holstebro udnytter sin andel. 
# Modtryksvarme og røggasvarme og bypassvarme medregnes i grundlastvarmen.
# Men også afladet effekt fra BHP-tanke kan tælles med.
# Hvis det i stedet for overlades til at være en omkostningsstyret balancering,
# svarende til et fælles ejerskab, så behøves ingen begrænsning ift. ejerandelen.
# Men der er netop 2 ejere, så derfor skal grænsen kunne aktiveres.
# Hvis Holstebros SR-anlæg aktiveres, så indebærer det, at tanke ikke kan levere varme nok til Holstebro.
# Dermed er det et rimeligt kriterium, at Struers T-varme i den situation begrænses til ejerandelen.
# Men ejerandels-begrænsningen skal være symmetrisk så Holstebro må heller ikke overtrække på grundlastvarmen.
# Så hvis Struers SR-anlæg er aktiveret, må Holstebro heller ikke overskride sin andel af grundlastvarmen.
# Grundlastvarmen er den øjeblikkelige sum af KV-anlæggenes modtryks-, røggas- og bypass-varme.
# Grundlastvarmen dynamisk, og dermed påvirkelig, så den kan øges fx ved aktivering af bypass.

QbaseMaxAll = sum(kv $OnUGlobal(kv), CHP(kv,'Qmax') + CHP(kv,'QRgkMax') + CHP(kv,'Qbypass')) 
              + sum(upr $(uprbase(upr) AND NOT kv(upr)), DataU(upr,'Fmax') * DataU(upr,'EtaQ'));       

*end 


*begin Kapacitet af eksisterende transmissioner til forbrugsområder.

*begin Aktive Transmissionsledninger.

trActive(tr) = (OnTransGlobal(tr) GT 0);
display trActive;

*end

# HACK Retning låses til udgangssituationen angivet i TransmConfig.
DirTrans(tr)  = 1;

*begin Varmetab og pumpearbejde i transmissionsledninger

# Transmissionsparametre, som er uafhængige af flowretning på T-ledning rørpar.
loop (tr $OnTransGlobal(tr),
  Area(tr)        = pi / 4 * DiT(tr)**2;
  Tavg(tr)        = sum(trkind, TinletT(tr,trkind)) / 2;
#BUG RhoW(tr)        = (-3.159E-3 * (Tavg(tr) - 1.0767E-1) * Tavg(tr) + 1001.1);
  RhoW(tr)        = (-3.2267E-3 * Tavg(tr) - 1.01108E-1) * Tavg(tr) + 1000.9;
  QTmax(tr)       = RhoW(tr) * Area(tr) * VelocMax(tr) * Cpp * (TinletT(tr,'frem') - TinletT(tr,'retur')) / 1E6 ; # [MWq]
  QTmin(tr)       = DataTransm(tr,'MinFlow') * QTmax(tr);


  # Pumperelaterede parametre.
  ViscDyn(tr)    = [(((1.9717E-8*Tavg(tr) - 6.5643E-6) * Tavg(tr) + 8.3217E-4)*Tavg(tr) - 5.2243E-2)*Tavg(tr) + 1.77] / 1000;  # [Pa s]
  Re(tr)         = RhoW(tr) / ViscDyn(tr) * VelocMax(tr) * DiT(tr);
  RoughRel(tr)   = Roughness(tr) / DiT(tr);
  fD(tr)         = 0.25 / power[(Log10(RoughRel(tr) / 3.7 + 5.74 / (Re(tr) ** 0.9))),2];
  dP(tr)         = L(tr) * fD(tr) * RhoW(tr) / 2 * VelocMax(tr)**2 / DiT(tr);   # [Pa]  HUSK at trykfaldet skal tælles med for begge rør.
  NPump(tr)      = ceil(dP(tr) / 25E+5);
  Wpump(tr)      = 2 * dP(tr) * Area(tr) * VelocMax(tr) / etaPump / 1E6;

  # Transmissionsparametre, som afhænger af flowretning på T-ledning rørpar.
  Loop (trkind,
    # Parametre, som er uafhængige af det aktuelle tidspunkt.
    Beta(tr,trkind) = (lamG / lamI) * log(DyiT(tr,trkind) / DiT(tr));
    h1(tr,trkind)   = 1 / [Beta(tr,trkind) + log(4 * H / DyiT(tr,trkind))];

    # Parametre til varmetabsberegning i T-ledning, som afhænger af det aktuelle tidspunkt.
    kT(t,tr,trkind)     = 2 * Pi * lamG * h1(tr,trkind) * (TinletT(tr,trkind) - Prognoses_hh(t,'TSoil')) / 1E6;
    alphaT_hh(t,tr,trkind) = kT(t,tr,trkind) * L(tr) / QTmax(tr);
  );
);  # Loop (tr)
*end

#--- CapexTrans(tr) = ((18300 * DN(tr) + 950) * L(tr) / 1E6) * PmtTransmPipe;  # DN har enheden [m].
#--- CapexPump(tr)  = InvCostPump * PmtTransmPump * NPump(tr) / 1E6;

*end
                              

#)