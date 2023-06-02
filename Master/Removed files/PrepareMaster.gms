$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        PrepareMaster.gms
Scope:          Erklærer globale sets, parms, vars, eqns og specificerer eqns for Master model.
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText

#begin Overførsel fra aktuelt master scenarie

#begin Sektion overordnede parametre
ScenarioID          = ActScen('ScenarioID');
SaveTimestamp       = ActScen('SaveTimestamp');
InterestRate        = ActScen('InterestRate');
InflationRate       = ActScen('InflationRate');
InvLenTransmPipe    = ActScen('InvLenTransmPipe');
InvLenTransmPump    = ActScen('InvLenTransmPump');
YearStart           = ActScen('YearStart');
PeriodFirst         = ActScen('PeriodFirst');
PeriodLast          = ActScen('PeriodLast');
OnDuplicatePeriods  = ActScen('OnDuplicatePeriods');
PeriodCount         = PeriodLast - PeriodFirst + 1;
# MOVE OnTimeAggr          = ActScen('OnTimeAggr');         #TimeAggr
# MOVE AggrKind            = ActScen('AggrKind');           #TimeAggr
# MOVE DurationPeriod      = ActScen('DurationPeriod');
EpsDeltaCap         = ActScen('EpsDeltaCap');
EpsDeltaNPVLower    = ActScen('EpsDeltaNPVLower');
EpsDeltaNPVUpper    = ActScen('EpsDeltaNPVUpper');
MasObjMinAbs        = ActScen('MasObjMinAbs');
MasObjMinRel        = ActScen('MasObjMinRel');
MaxIterBelowBest    = ActScen('MaxIterBelowBest');
MasterIterMax       = ActScen('MasterIterMax');
AlfaVersion         = ActScen('AlfaVersion');
AlfaReducIndiv      = ActScen('AlfaReducIndiv');
IterAlfaMax         = ActScen('IterAlfaMax');
AlfaMin             = ActScen('AlfaMin');
MipGapScheme        = ActScen('MipGapScheme');
MipGapMin           = ActScen('MipGapMin');
MipGapMax           = ActScen('MipGapMax');
MipIterBegin        = ActScen('MipIterBegin');
MipIterEnd          = ActScen('MipIterEnd');
OnMinCapacIncrement = ActScen('OnMinCapacIncrement');
OnCapex0            = ActScen('OnCapex0');
OnMaxProjNet        = ActScen('OnMaxProjNet');
OnMaxProjU          = ActScen('OnMaxProjU');
OnMinProjSeqU       = ActScen('OnMinProjSeqU');
WriteMasterOutput   = ActScen('WriteMasterOutput');

UseTimeAggr = OnTimeAggr NE 0;

PeriodCount = PeriodLast - PeriodFirst + 1;
if (PeriodCount LE 0, 
  execute_unload "MECmain.gdx"; 
  display "ERROR PrepareMaster: PeriodFirst er større end PeriodLast", PeriodFirst, PeriodLast;
  abort "PrepareMaster: PeriodFirst er større end PeriodLast";
);
YearSharePer(perA)  = Periods('PeriodHours',perA) / card(tt);


display InterestRate, YearStart, PeriodFirst, PeriodLast, PeriodCount;
display EpsDeltaCap, EpsDeltaNPVLower, EpsDeltaNPVUpper, MasObjMinAbs;
display MaxIterBelowBest, MasterIterMax, AlfaVersion, AlfaReducIndiv, IterAlfaMax, AlfaMin, MipGapScheme, MipGapMin, MipGapMax;
display YearSharePer;
display OnMinCapacIncrement, OnCapex0, OnMaxProjNet, OnMaxProjU;
#end

#begin Overfør controls for optimeringsforløbet

# MOVE DumpPeriodsToGdx = ActScen('DumpPeriodsToGdx');

#end 

#begin Overfør kapacitetsgrænser mv. fra ActScen.
# MOVE QInfeasMax     = ActScen('QInfeasMax');
CapUInfeasMax  = ActScen('CapUInfeasMax');
OnNpvPenalty   = ActScen('OnNpvPenalty');
AllowExcessCap = ActScen('AllowExcessCap');
ReserveCapQ    = ActScen('ReserveCapQ');
#end

# Fælles varmesalgspris for alle net.
QSalgsPris(net) = ActScen('QSalgsprisAlle');


#begin Aktivér perioder, som er indeholdt i planhorisonten.
per(perA) = yes;
per(perA) = (ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast);
display per;
#end 

RealRente = InterestRate - InflationRate + 1E-7;    # Adderes med 1E-7 for at undgå division by zero hvis realrenten er 0.
PmtTransmPipe = (RealRente) / (1-(1+RealRente)**(-InvLenTransmPipe));
PmtTransmPump = (RealRente) / (1-(1+RealRente)**(-InvLenTransmPump));


#begin QA på ActScen

If (MasterIterMax GE card(iter) - 1,  execute_unload "MECmain.gdx"; abort "MasterIterMax overstiger antal definerede iterationer"; );

If (AlfaMin LE 0.0 OR AlfaMin GE 1.0, execute_unload "MECmain.gdx"; abort "AlfaMin udenfor ]0;1["; );

# MOVE if (DumpPeriodsToGdx LT 0 OR DumpPeriodsToGdx GT 2, execute_unload "MECmain.gdx"; abort 'DumpPeriodsToGdx skal være 0, 1 eller 2'; );

#begin QA på sheet ScenMaster

loop (scenmas, if ( abs(sum(net, QDemandPeakScen(net,scenMas))) EQ 0.0,   execute_unload "MECmain.gdx"; abort "ERROR: Sum af QDemandPeakScen er nul for mindst eet masterscenarie"; ); );
loop (scenmas, if ( abs(sum(net, OnNetGlobalScen(net,scenMas))) EQ 0.0,   execute_unload "MECmain.gdx"; abort "ERROR: Sum af OnNetGlobalScen er nul for mindst eet masterscenarie"; ); );
loop (scenmas, if ( abs(sum(u, OnUGlobalScen(u,scenMas))) EQ 0.0,         execute_unload "MECmain.gdx"; abort "ERROR: Sum af OnUGlobalScen er nul for mindst eet masterscenarie"; ); );
loop (scenmas, if ( abs(sum(unew, CapFacN1ResScen(unew,scenMas))) EQ 0.0, execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapFacN1ResScen er nul for mindst eet masterscenarie"; ); );
loop (capexKind $(NOT sameas(capexKind,'minFlh')),
  loop (scenmas, if ( abs(sum(u, CapexScen(capexKind,u,scenMas))) EQ 0.0, execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapexScen er nul for mindst eet masterscenarie"; ); );
);
#--- loop (scenmas, if ( abs(sum(u, DataTransmScen(tr,lblDataTransm,scenMas))) EQ 0.0, execute_unload "MECmain.gdx"; abort "ERROR: Sum af DataTransmScen er nul for mindst eet masterscenarie"; ); );

display MaxProjUScen;
loop (scenmas, if ( abs(sum(net,  MaxProjNetScen(net,scenMas))) LE 0.0, execute_unload "MECmain.gdx";  abort "ERROR: Mindst eet element i MaxProjNetScen er ikke-positivt"; ); );
loop (scenmas, if ( abs(sum(unew, MaxProjUScen(unew,scenMas)))  LE 0.0, execute_unload "MECmain.gdx";  abort "ERROR: Mindst eet element i MaxProjUScen er ikke-positivt"; ); );

#end 

#begin QA på sheet ScenPeriod

loop (perA $(ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast),

   if ( abs(sum(tr,     CapTInitPer(tr, perA))) EQ 0.0,       execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapTInitPer er nul for mindst een periode."; ); 
   if ( abs(sum(tr,     CapTMinPer(tr, perA))) EQ 0.0,        execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapTMinPer er nul for mindst een periode."; ); 
   if ( abs(sum(tr,     CapTMaxPer(tr, perA))) EQ 0.0,        execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapTMaxPer er nul for mindst een periode."; ); 
   if ( abs(sum(net,    OnNetNomPer(net,perA))) EQ 0.0,       execute_unload "MECmain.gdx"; abort "ERROR: Sum af OnNetNomPer er nul for mindst een periode. Brug evt. OnNetGlobal"; ); 
   if ( abs(sum(u,      OnUNomPer(u,perA))) EQ 0.0,           execute_unload "MECmain.gdx"; abort "ERROR: Sum af OnUNomPer er nul for mindst een periode. Brug evt. OnUGlobal"; ); 
   if ( abs(sum(net,    CapUReservePer(net,perA))) EQ 0.0,    execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapUReservePer er nul for mindst een periode."; ); 
  
   #--- if ( abs(sum(unew,   dCapUInitPer(unew,perA))) EQ 0.0,     execute_unload "MECmain.gdx"; abort "ERROR: Sum af dCapUInitPer er nul for mindst een periode."; ); 
   #--- if ( abs(sum(unew,   CapUMinPer(unew,perA))) EQ 0.0,       execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapUMinPer er nul for mindst een periode."; ); 

  if ( (abs(sum(unew, CapUMaxPer(unew,perA))) EQ 0.0) AND (sum(unew, OnUNomPer(unew,perA)) GT 0),       
     execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapUMaxPer er nul for mindst een periode, hvor mindst eet nyt anlæg er aktivt."; 
  ); 
  
  if ( abs(sum(uexist, CapUExistPer(uexist,perA)))   EQ 0.0, execute_unload "MECmain.gdx"; abort "ERROR: Sum af CapUExistPer er nul for mindst eet anlæg."; ); 
  if ( abs(sum(uexist, DeprecExistPer(uexist,perA))) EQ 0.0, execute_unload "MECmain.gdx"; abort "ERROR: Sum af DeprecExistPer er nul for mindst eet anlæg."; ); 

);

#end 


#end   QA på ActScen


#begin Beregn lookup-tabeller for duplikerede perioder.

OnDeAggr = 0;   # Kan blive aktiveret i LoopMasterPost.gms, hvis OnTimeAggr er negativ.

Found = 0;
PeriodOriginal(perA,begend) = 0; 
DuplicateUntilIteration(perA) = Periods('DuplicateUntilIteration', perA);

if (OnDuplicatePeriods,
  loop (perA $(ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast),
    actPer(perAlias) = (ord(perAlias) EQ ord(perA));
    if (DuplicateUntilIteration(perA) EQ 0,
      PrevOrigPeriod = ord(perA);
    elseif (DuplicateUntilIteration(perA) LE 2),
      display "ERROR: DuplicateUntilIteration skal angive master-iteration 3 eller højere.", actPer, DuplicateUntilIteration;
      Found = 1;
    elseif (ord(perA) EQ PeriodFirst),
      display "ERROR: Første periode kan ikke være en dublet af den foregående", actPer, PeriodFirst, DuplicateUntilIteration;
      Found = 2;
    else
      # Periodeangivelse var OK. 
      PeriodOriginal(perA,'begin') = PrevOrigPeriod;    
    );
  );
);  
display Found, OnDuplicatePeriods, DuplicateUntilIteration, PeriodOriginal;
  
if (Found NE 0, execute_unload "MECmain.gdx";  abort "ERROR: Fejl fundet i angivelse af periode-parameteren DuplicateUntilIteration."; );

#end   Beregn lookup-tabeller for duplikerede perioder.


# Konverter CapUInitPer til dCapUInitPer.
# OBS De indlæste værdier for dCapUInitPer ignoreres.

$OffOrder

dCapUInitPer(unew,per) = CapUInitPer(unew,per) - CapUInitPer(unew,per-1);
dCapUInitPerMax(unew)  = max(0.1, smax(per, dCapUInitPer(unew,per)));

# Af praktiske hensyn kan DeprecExistPer også anvendes på nye anlæg.
DeprecExistPer(unew,perA) = 0.0;

$OnOrder

#--- execute_unload "MECmain.gdx";
#--- abort.noerror "BEVIDST STOP i InitMasterLoop.gms";

