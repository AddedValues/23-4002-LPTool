$log Entering file: %system.incName%
#(
$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        ReadScenarios.gms
Scope:          Indlæser scenarier fra Excel og prompter for aktuelt master scenarie.
Inkluderes af:  MecLpMain.gms
Argumenter:     <endnu ikke defineret>

$OffText

Scalar scenMasNo 'Master scenario number';



$onUNDF

*begin Indlæs scenarier fra Excel.

Parameter OnNetGlobalScen(net,scmas)              'Aktiv forsyningsnet 0/1';
parameter DataTransmScen(tr,lblDataTransm,scmas)  'Bruges til indlæsning fra ScenMaster arket.';
Parameter OnUGlobalScen(u,scmas)                  'Aktive anlæg 0/1';
Parameter OnURevisionScen(u,scmas)                'Anlægsrevision aktiv 0/1';

$onecho > MecLPinput.txt
par=Scenarios              rng=ScenMaster!C9:F45         rdim=1 cdim=1
par=OnNetGlobalScen        rng=ScenMaster!C47:F50        rdim=1 cdim=1
par=OnUGlobalScen          rng=ScenMaster!C51:F86        rdim=1 cdim=1
par=OnURevisionScen        rng=ScenMaster!C87:F93        rdim=1 cdim=1
par=YS                     rng=ScenYear!A9:B106          rdim=1 cdim=0
par=Brandsel               rng=Brandsel!B2:L21           rdim=1 cdim=1
par=DataU                  rng=DataU!A3:AD33             rdim=1 cdim=1
par=FuelCode               rng=DataU!A42:B60             rdim=1 cdim=0
par=OmrCode                rng=DataU!F42:G44             rdim=1 cdim=0
par=DsoCode                rng=DataU!F50:G54	         rdim=1 cdim=0
par=DataAff                rng=DataU!A65:D90             rdim=1 cdim=1
par=FuelMix                rng=DataUFuel!A3:N33          rdim=1 cdim=1
par=FuelPriceU             rng=DataUFuel!R3:AE33         rdim=1 cdim=1
par=DataHpKind             rng=DataHP!A10:Q21            rdim=1 cdim=2
par=CHP                    rng=CHP!A33:P37               rdim=1 cdim=1
par=DataPtX                rng=DataPtX!B9:C16            rdim=1 cdim=1
par=DataTransm             rng=DataTransm!B11:D34        rdim=2 cdim=0
par=TransmConfig           rng=DataTransm!G10:I16        rdim=1 cdim=1
par=Pipes                  rng=Pipes!B4                  rdim=1 cdim=1
par=Diverse                rng=Diverse!A9                rdim=1 cdim=0
par=StateU                 rng=PlantState!A10            rdim=1 cdim=1
par=StateF                 rng=FuelState!A10             rdim=2 cdim=1
par=Availability_hh        rng=Availabilities!A10        rdim=1 cdim=1
par=Revision_hh            rng=Availabilities!AE10       rdim=1 cdim=1
par=Prognoses_hh           rng=Prognoses!A10             rdim=1 cdim=1
par=CapEReservation        rng=CapacAlloc!B9:H34         rdim=1 cdim=2
par=CapEAvail              rng=CapacAlloc!M10:O34        rdim=1 cdim=1
par=DataElMarket           rng=CapacAlloc!Q10            rdim=1 cdim=1

$offecho

$call "ERASE  MecLPinput.gdx"
$call "GDXXRW MecLPinput.xlsb RWait=1 Trace=3 @MecLPinput.txt"

$if errorlevel 1 $abort gdxxrw: reading failed

# Indlæsning fra GDX-fil genereret af GDXXRW.
# $LoadDC bruges for at sikre, at der ikke findes elementer, som ikke er gyldige for den aktuelle parameter.
# $Load   udfører samme operation som $LoadDC, men ignorerer ugyldige elementer.
# $Load anvendes her for at tillade at indsætte linjer med beskrivende tekst.

$GDXIN MecLPinput.gdx
$LOAD   Scenarios
$LOAD   OnNetGlobalScen
$LOAD   OnUGlobalScen
$LOAD   OnURevisionScen
$LOAD   YS 
$LOAD   Brandsel
$LOAD   DataU
$LOAD   FuelCode
$LOAD   OmrCode
$LOAD   DsoCode
$LOAD   DataAff
$LOAD   FuelMix
$LOAD   FuelPriceU
$LOAD   DataHpKind
$LOAD   CHP
$LOAD   DataPtX
$LOAD   DataTransm
$LOAD   TransmConfig
$LOAD   Pipes
$LOAD   Diverse
$LOAD   StateU
$LOAD   Availability_hh
$LOAD   Revision_hh
$LOAD   Prognoses_hh
$LOAD   CapEReservation
$LOAD   CapEAvail
$LOAD   DataElMarket

$GDXIN   # Close GDX file.
$log  Finished loading data from GDXIN.

$gdxout "MecLpMain.gdx"
$unload
$gdxout
#--- $terminate 'BEVIDST STOP i ReadScenarios';

*end Indlæs scenarier fra Excel.



*begin Groft fejlcheck af indlæsning fra Excel via GDXXRW. QA på scenarie sheets udføres i PrepareMaster.gms.

# Hvis den numeriske sum af en parameter eller underrum heraf er nul, er data ikke blevet korrekt overført fra Excel (typisk fejl er startcellens adresse).
#(

*begin Sheet DataU
if (sum(f,   abs(FuelCode(f)))  EQ 0.0,  execute_unload "MecLpMain.gdx"; abort "ERROR: Sum af FuelCode er nul.";); 
if (sum(net, abs(OmrCode(net))) EQ 0.0,  execute_unload "MecLpMain.gdx"; abort "ERROR: Sum af OmrCode er nul.";); 

loop (hpSource, 
  loop (lblCopYield, 
    if (sum(lblHpCop, abs(DataHpKind(lblHpCop,hpSource,lblCopYield))) EQ 0.0, execute_unload "MecLpMain.gdx"; abort "ERROR: Sum af DataHpKind er nul for mindst een kombination af hpSource og lblHpCop."; );
  );
);
*end 

*begin Sheet CHP
loop (kv, if (sum(lblCHP, abs(CHP(kv,lblCHP))) EQ 0.0, execute_unload "MecLpMain.gdx"; abort "ERROR: Sum af række i CHP-tabellen er nul for mindst eet KV-anlæg."; ); );
*end 

*begin Sheet Brandsel
loop (lblBrandsel,
  if (sum(f, abs(Brandsel(f,lblBrandsel))) EQ 0.0, execute_unload "MecLpMain.gdx"; abort "ERROR: Summen af mindst een kolonne i tabellen Brandsel er nul"; );
);
*end

*begin Sheet Transmission og Pipes
if (sum(lblTrConfig, sum(tr,abs(TransmConfig(tr,lblTrConfig)))) EQ 0.0,  execute_unload "MecLpMain.gdx"; abort "ERROR: Sum af netF eller netT i TransmConfig er nul"; ); 
loop (lblPipe,
  if (sum(pipe, abs(Pipes(pipe,lblPipe))) EQ 0.0, execute_unload "MecLpMain.gdx"; abort "ERROR: Sum af mindst een kolonne i tabellen Pipes er nul."; );
);
*end 

*begin Sheet Diverse
if (sum(lblDiverse, abs(Diverse(lblDiverse))) EQ 0.0, abort "ERROR: Sum af tabellen Diverse er nul."; );
*end Sheet Diverse

*begin Sheet StateU

$OffOrder

actU(ualias) = no;
loop (u,
  actU(ualias) = ord(ualias) EQ ord(u);
  if (StateU(u,'start') GT 1.0, execute_unload "MecLPinput.gdx"; display actU, StateU; abort "ERROR: StateU(actU,'start') er større end 1"; );
  if (StateU(u,'slut')  GT 1.0, execute_unload "MecLPinput.gdx"; display actU, StateU; abort "ERROR: StateU(actU,'slut')  er større end 1"; );
);
$OnOrder

*end Sheet StateU

*begin Master scenarier
# Check at hele master-scenarie tabellen er indlæst.
# Dette check udføres her for at undgå spildtid ved at køre videre med mangelfulde data.
if (abs(Scenarios('BottomLineScenMaster','scmas1') - 999) GT 0.1,  execute_unload "MecLpMain.gdx"; abort 'ERROR-1: Sidste række i master scenarie tabellen er ikke indlæst. Check GDXXRW specifikationen.');
loop (scmas $(ord(scmas) EQ card(scmas)),
  if (abs(Scenarios('BottomLineScenMaster',scmas) - 999) GT 0.1, execute_unload "MecLpMain.gdx"; abort 'ERROR-2: Sidste kolonne i master scenarie tabellen er ikke indlæst. Check GDXXRW specifikationen.');
);

# Check at netop et masterscenarie er valgt i tabellen Scenarios fra arket ScenMaster.
tmp = sum(scmas, Scenarios('ActualMasterScen',scmas));
if (tmp GT 1, execute_unload "MecLpMain.gdx"; execute_unload "MecLpMain.gdx"; abort "ERROR: Der er valgt mere end 1 aktivt masterscenarie i rækken ActualMasterScen.");

# Identificer det ønskede master-scenarie.
loop (scmas, 
  if (Scenarios('ActualMasterScen',scmas) GT 0,
    scenMasNo = ord(scmas);
    break;
  );
);
display scenMasNo;


# Vælg det aktuelle scenarie ved at kopiere værdier for det aktuelle master-scenarie over i vektor.
# Det aktuelle scenaries indeks i set scmas er gemt i scenMasNo.
# Dernæst udtrækkes det tilhørende set member af typen 'scmasNN', hvor NN er scenMasNo, i singleton set actSc.
actSc(scmas) = ord(scmas) EQ scenMasNo;
display actSc;
ActScen(lblScenMas) = Scenarios(lblScenMas,actSc);
display ActScen;

# Check for zero-valued members in actual scenario. They will be marked with a nonzero value (9.99) in parameter ZeroScenMembers.
ZeroScenMembers(lblScenMas) = IfThen(ActScen(lblScenMas) EQ 0, 9.99, 0);
display ZeroScenMembers;

OnNetGlobal(net) = OnNetGlobalScen(net,actSc);
OnUGlobal(u)     = OnUGlobalScen(u,actSc);
OnURevision(cp)  = OnURevisionScen(cp,actSc);


*begin Transmissions-relaterede parametre

*begin Rådighed af T-ledninger.
OnTransGlobal(tr) = DataTransm(tr,'On');

# Check at de forbundne net er defineret.
loop (tr $OnTransGlobal(tr),
  if (TransmConfig(tr,'netF') LE 0 OR TransmConfig(tr,'netT') LE 0,
    execute_unload "MecLpMain.gdx";
    display "ERROR:", OnTransGlobal, TransmConfig;
    abort "Mindst een AKTIV transmissionsledning er ikke forbundet til et net.";
  );
);

# Beregning af rådige kombinationer af T-ledninger og net
Scalar SumOnTransNet 'Checksum' / 0 /;
OnTransNet(tr,netF,netT) = 0;  # Udgangspunkt: Ingen T-ledninger er til rådighed.
loop (tr $OnTransGlobal(tr),
  SumOnTransNet = 0;
  acttr(tr) = yes;
  loop (netF $OnNetGlobal(netF),
    loop (netT $OnNetGlobal(netT),
      if (TransmConfig(tr,'netF') EQ ord(netF) AND TransmConfig(tr,'netT') EQ ord(netT),
         OnTransNet(tr,netF,netT) = 1;
         SumOnTransNet = SumOnTransNet + 1;
         # Overfør forbundne netværk til DataTransm tabellen (bekvemt).
         DataTransm(tr,'netF') = TransmConfig(tr,'netF');
         DataTransm(tr,'netT') = TransmConfig(tr,'netT');
      );
    );
  );
  # Giv advarsel, hvis T-ledninger har fejlagtig kobling til net.
  if (SumOnTransNet EQ 0,
    display "ERROR TRANS-1:", acttr, OnTransGlobal, OnNetGlobal, DataTransm;
    abort "Mindst en transmissionsledning er forbundet til et inaktivt net. Se display ovenfor i lst-filen.";
  );
  if (SumOnTransNet GE 2,
    display "ERROR TRANS-2:", acttr, OnTransGlobal, OnNetGlobal, DataTransm;
    abort "Mindst en transmissionsledning er forbundet til mere end eet aktivt net. Se display ovenfor i lst-filen.";
  );
);

# Flowretning er ensrettet som defineret i TransmConfig.
DirTrans(tr) = +1;

*end

H    = 0.9;    # [m]
Cpp  = 4186;   # [J/kg*K]
lamG = 1.60;   # [W/M*K]
lamI = 0.027;  # [W/m*K]

loop (tr $OnTransGlobal(tr),
  acttr(tr) = yes;
  # Bestem det aktuelle rør (actPipe) givet ved sin dimension DN.
  Found = 0;
  loop (pipe,
    if (Pipes(pipe,'DN') EQ DataTransm(tr,'DNmm'),
      Found = 1;
      actpipe(pipe) = yes;
    );
  );
  if (NOT Found,
    display acttr, DataTransm, Pipes;
    abort "Rørdimension DNmm for T-ledning acttr findes ikke i tabellen Pipes (se displays ovenfor i listing filen).";
  );

  DN(tr)              = Pipes(actpipe,'DN') / 1E3 ;
  DiT(tr)             = Pipes(actpipe,'Di')   / 1E3;
  DyiT(tr,'frem')     = Pipes(actpipe,'InsulDiam3') / 1E3;               # Tfrem rørisolationsklasse 3.
  DyiT(tr,'retur')    = Pipes(actpipe,'InsulDiam1') / 1E3;
  Roughness(tr)       = Pipes(actpipe,'Roughness') / 1E3;
  L(tr)               = DataTransm(tr,'Lkm') * 1E3;
  VelocMax(tr)        = DataTransm(tr,'VelocMax');
  TinletT(tr,'frem')  = DataTransm(tr,'TFone');
  TinletT(tr,'retur') = DataTransm(tr,'TRtwo');
);
display DataTransm, DN, DiT, DyiT, Roughness, L, VelocMax, TinletT;

*end Transmissions-relaterede parametre


*end   Master scenarier

*begin års scenarier


*begin Check at hele års-scenarie tabellen er indlæst for det udvalgte årsscenarie.
if (YS("BottomLineYearScen") NE 999,
  execute_unload "MecLpMain.gdx";
  display "Fejlbehæftet række i årsscenarie";
  abort "ERROR-5: Sidste række i årsscenarie tabellen er ikke indlæst. Check GDXXRW specifikationen.";
);
*end

*end   års scenarier


*begin QA på DataU

# MaNVak1 og MaNVak2 udelukker hinanden gensidigt, så begge kan ikke være aktive.
if (OnUGlobal('MaNVak1') AND OnUGlobal('MaNVak2'),
  execute_unload "MecLpMain.gdx";
  abort "MaNVak1 og MaNVak2 kan ikke begge være aktive."
);

*end   QA på DataU

*begin QA på FuelMix og FuelPriceU

loop (upr $(OnUGlobal(upr) AND NOT ucool(upr)), 
  actUpr(upr) = yes;
  tmp = sum(f, FuelMix(upr,f));
  if (abs(tmp - 1.0) GT 1E-5,
    execute_unload "MecLpMain.gdx";
    display "Ingen drivmidler angivet for anlæg actUpr", actUpr;
    abort "Ingen drivmidler angivet for anlæg upr";
  );
);

*end  QA på FuelMix og FuelPriceU

*begin Kapacitetsreservation

CapEAvail(uelec,updown) = CapEAvail(uelec,updown) $OnUGlobal(uelec);

*end Kapacitetsreservation


#--- *begin Indlæsning af timeblokke fra særskilt Excel-fil.
#--- 
#--- $onecho > MECTidsAggregering.txt
#--- * TimeBlocks:  rowdim = tt,  coldims = aggr, yrPlan
#--- par=TimeBlocks      rng=TimeBlocks!B14     rdim=1 cdim=2
#--- $offecho
#--- 
#--- $call "ERASE MECTidsAggregering.gdx"
#--- $call "GDXXRW MECTidsAggregering.xlsx RWait=1 Trace=3 @MECTidsAggregering.txt"
#--- 
#--- $GDXIN MECTidsAggregering.gdx
#--- $LOAD TimeBlocks
#--- $GDXIN
#--- 
#--- *end Indlæsning af timeblokke fra særskilt Excel-fil.


#)