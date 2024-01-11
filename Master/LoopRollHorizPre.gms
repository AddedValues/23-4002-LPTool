$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        LoopRollHorizPre.gms
Scope:          Første del af rolling horizon optimeringsloop
Inkluderes af:  MecLpMain.gms
Argumenter:     <endnu ikke defineret>

$OffText

display '>>>>>>>>>>>>>>>>  ENTERING %system.incName%  <<<<<<<<<<<<<<<<<<<';

if (LenRHhoriz GT Nblock,
  display "WARNING: LenRHhoriz overstiger Nblock, så LenRHhoriz og LenRHstep begrænses begge til Nblock.", LenRHhoriz, Nblock;
  LenRHhoriz = Nblock;
  LenRHstep  = Nblock;
);

# OBS MBL: nRHstep er antal regulære step af længde LenRHstep, og dertil kommer et sidste step, så der altid gennemløbes mindst eet step.
#          Eksempel: Hvis der ikke skal anvendes rullende horisont, vil nRHstep være lig nul. 

# Ved tidsaggregering justeres horisont- og trinlængde for at give regulære værdier af disse.
# OBS Tidsaggregering skal have skiftetid på den givne værdi af DurationPeriod.
# OBS ScenMaster parameteren LenRollHorizonOverhang angiver i det tilfælde overhænget.
 
# TODO De værdier som fx nRHstep, som beregnes i blokken herunder, skal evt. specificeres direkte via input, hvor også RHIntv indlæses.

if (OnTracing, display "INFO: RH setup", UseTimeAggr, UseTimeExpansionAny, DurationPeriod; );

# Tilpas RH overhæng, hvis deaggregering er aktiv. Overhænget skaleres med middelbloklængden. Nblock er antal tidsblokke for et helt år.
if (UseTimeAggr,                 
  Loop(tt $(ord(tt) LE Nblock),
    if (Bend(tt) GE DurationPeriod,    # Antal blokke fundet.
      NblockActual  = ord(tt);
      LenRHStep     = floor( NblockActual / CountRollHorizon );
      LenRHhoriz    = LenRHStep + LenRHoverhang;
      break;
    );
  );

elseif (UseTimeExpansionAny),
  NblockActual = Nblock;
  LenRHStep     = floor( NblockActual / CountRollHorizon );
  LenRHhoriz    = LenRHStep + LenRHoverhang;

else    # Hverken tidsaggregering eller tidsekspansion.
  NblockActual = DurationPeriod;
  LenRHStep    = floor( NblockActual / CountRollHorizon );
  LenRHhoriz = LenRHStep + LenRHoverhang;
);
display "LoopRollHorizPre: Tilpasning af RH-længder: ", UseTimeAggr, UseTimeExpansionAny, NblockActual, LenRHoverhang, CountRollHorizon, LenRHStep, LenRHhoriz;


# Denne afkortning er kun aktuel, hvis DurationPeriod er mindre end den beregnede LenRHhoriz, som er baseret på antal RH.
If (LenRHhoriz GT NblockActual, LenRHhoriz = NblockActual; );

# OBS : nRHstep er antal blokke af længde LenRHstep, så der udføres altid een blok mere svarende til resttiderne i perioden.
nRHstep        = CountRollHorizon - 1;   # Specs af RH ifm. tidsaggregering styres efter antal RH-trin og overhæng (LenRHhoriz - LenRHstep).
LenPureRHstep  = nRHstep * LenRHstep;
LenResidRHstep = NblockActual - LenPureRHstep;
display NblockActual, LenRHhoriz, LenRHstep, nRHstep, LenPureRHstep, LenResidRHstep;

Found = (LenRHhoriz GT NblockActual) OR (nRHstep LT 0) OR (floor(nRHstep) NE nRHstep);
if (Found, execute_unload "MecLpMain.gdx"; );
if (LenRHhoriz GT NblockActual, abort 'FEJL i Rolling Horizons: LenRHhoriz er større end NblockActual.', LenRHhoriz, NblockActual; );
if (nRHstep LT 0,               abort 'FEJL i Rolling Horizons: nRHstep er negativ.', nRHstep; );
if (floor(nRHstep) NE nRHstep,  abort 'FEJL i Rolling Horizons: nRHstep er ikke heltallig.', nRHstep; );


*begin Beregning af start og slut tidspunkt for hvert step i rolling horizon.
# MBL 2020-06-09 17:40: nRHstep er antal regulære step af længde LenRHstep. Dertil kommer et ekstra step med en residual længde.
# MBL 2023-01-18 12:53: Tidspunkterne t(tt) er aggregerede tidspunkter, som evt. kan være enkelttimer ifm. ingen aggregering.

RHIntv(rhStep,beginend) = 0;

loop (rhStep $(ord(rhStep) LE nRHstep + 1),

  actRHstep(rhStepAlias) = (ord(rhStepAlias) EQ ord(rhStep));
  if (ord(rhStep) EQ 1,
    tbegin = 1;
  else
    tbegin = (ord(rhStep) - 1) * LenRHstep + 1;
  );
  
  tend = tbegin - 1 + LenRHhoriz;       # Sluttidspunkt af den fulde aktuelle RH-længde.
  if (ord(rhStep) EQ nRHstep+1,
    tbegin = nRHstep * LenRHstep + 1;
    tend   = NblockActual;
  );
  
  RHIntv(rhStep,'begin')   = tbegin;
  RHIntv(rhStep,'end')     = tend;
  RHIntv(rhStep,'len')     = tend - tbegin + 1;
  RHIntv(rhStep,'endstep') = min(tbegin - 1 + LenRHstep, tend);
  if (ord(rhStep) EQ nRHstep + 1, 
    RHIntv(rhStep,'endstep') = NblockActual; 
  );
  RHIntv(rhStep,'lenstep') = RHIntv(rhStep,'endstep') - tbegin + 1;
  
  # Beregn antal timer i hvert trin hhv. horisont.
  tbegin    = RHIntv(rhStep, 'begin');
  tendstep  = RHIntv(rhStep, 'endstep');
  tendhoriz = RHIntv(rhStep, 'end');
  RHIntv(rhStep,'nhourstep')  = round(sum(tt $(ord(tt) GE tbegin AND ord(tt) LE tendstep),  BLen(tt)));
  RHIntv(rhStep,'nhourhoriz') = round(sum(tt $(ord(tt) GE tbegin AND ord(tt) LE tendhoriz), BLen(tt)));
  if (ord(rhStep) EQ nRHstep + 1, 
    RHIntv(rhStep,'endstep') = NblockActual; 
  );
);

if (OnTracing, display "DEBUG: RHIntv", nRhStep, LenRHhoriz, LenRHStep, RHIntv; );

*end 

#--- execute_unload "Main.gdx";
#--- abort.noerror "BEVIDST STOP i LoopRollHorizPre.gms";



#--- *begin Beregn CO2-emissions reference fordelt på RH efter varmebehovet.
#--- $OffOrder
#--- 
#--- # CO2-loftet er årsbaseret, og bliver her forholdsmæssigt fordelt på den aktuelle periode.
#--- CO2EmisRefPeriod(net,co2kind) = CO2EmisRef(net,co2kind) $(CO2EmisRef(net,co2kind) GE 0.0);
#--- 
#--- QDemandSum(net) = sum(t, QeDemandActual(t, net));
#--- QDemandTotal    = sum(net, QDemandSum(net));
#--- 
#--- loop (rhStep $(ord(rhStep) LE nRHstep + 1),
#---   QDemandSumRHfull(rhStep,net) = sum(t $(ord(t) GE RHIntv(rhStep,'begin') AND ord(t) LE RHIntv(rhStep,'end')), QeDemandActual(t,net)) $OnNet(net);
#---   CO2EmisRefShare(rhStep,net,co2kind) $OnNet(net) = CO2EmisRefPeriod(net,co2kind) * QDemandSumRHfull(rhStep,net) / [1.0 $(QDemandSum(net) EQ 0.0) + QDemandSum(net)];
#---   
#---   #--- Sidste RH tildeles max. af forrige RH og af andelen som følger tildelingsreglen for de øvrige RH.
#---   #--- Denne undtagelse skyldes en observation, at sidste RH kan få en meget lille tildeling og dermed medføre infeasibility.
#---   #--- if (ord(rhStep) EQ nRHstep + 1, CO2EmisRefShare(rhStep,co2kind) = max( CO2EmisRefShare(rhStep,co2kind),  CO2EmisRefShare(rhStep-1,co2kind) * [ RHIntv(rhStep-1,'len') / RHIntv(rhStep,'len') ] ) );
#--- );
#--- $OnOrder
#--- 
#--- *end 

#--- # Dump modellen på gdx så inspektion undervejs muliggøres.
#--- #--- execute_unload 'Main.gdx';
#--- abort.noerror "BEVIDST STOP i LoopRollHorizPre.gms";


# ==============================================  START På ROLLING HORIZON LOOP  ========================================================

Loop (rhStep $(ord(rhStep) LE nRHstep + 1),

  actRHstep(rhStepAlias) = (ord(rhStepAlias) EQ ord(rhStep));
  TimeBegin = RHIntv(rhStep,'begin');
  TimeEnd   = RHIntv(rhStep,'end');

  #--- CO2EmisRefShareRH(net,co2kind) = CO2EmisRefShare(rhStep,net,co2kind);

  display "ROLLING HORIZON:", actRHstep, TimeBegin, TimeEnd; #--- , CO2EmisRefShareRH;

$OffOrder
  t(tt) = yes;
  t(tt) = ord(tt) GE TimeBegin AND ord(tt) LE TimeEnd;
$OnOrder
