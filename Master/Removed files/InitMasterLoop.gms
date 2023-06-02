$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        InitMasterLoop.gms
Scope:          Initialiserer master iteration loop.
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText

display '>>>>>>>>>>>>>>>>  ENTERING %system.incName%  <<<<<<<<<<<<<<<<<<<';


#begin Erklæringer
# MOVE Scalar    nHours                     'Antal timer i aktuel periode';
Scalar    hourFix                    'Timespring mellem vakladning-fikseringer';
# MOVE Scalar    stop                       'temp parm ifm. konvergensvurdering';
Scalar    stepULen                   'Længde af stepvektoren';
# MOVE Scalar    pModelStat;               
Scalar    pMasterModelStat;         
Scalar    actualPeriod;             
Scalar    pyr, pmo;                 
Scalar    dNPV                       'Ændring af master objective';
Scalar    NIterBelowBest             'Antal master-iterationer siden hidtil bedste NPV';
Parameter StepULenIter(iter)         'Længde af stepvektoren';
Parameter dCapUOfzLenIter(perA,iter) 'Længde af stepvektoren på periodeniveau';

Scalars   ttStartMin, ttStartMax; # Ordinal position af tt i gdx startgæt-filen.
Parameter StartGaetAvailable(perA,iter)   'Angivelse af hvilke perioder og iterationer hvor der er start gæt til rådighed';
Parameter SbStart(tt,upr,perA,iter);
Parameter SbBypass(tt,kv,perA,iter);
Parameter SbRgk(tt,kv,perA,iter);
Parameter SbOn(tt,upr,perA,iter);
Parameter SbOnT(tt,tr,perA,iter);
Parameter SbOnTAll(tr,perA,iter);

Parameter dCapUOfzLen(perA)                             'Længde af stepvektoren';
Parameter StatsMaster(topicSolver,iter)                 'Master model and solve attributes';
                                                        
Parameter CapUOldParm(u,net,perA)                       'Eksisterende kapaciteter i hvert net og hver periode';
Parameter BoundViolation(unew,perA,bound)               'EQ 1 hvis initialkapacitet overskrider grænser';
Parameter CapNeedViolation(net,perA)                    'EQ 1 hvis initialkapacitet ikke opfylder mindstebehovet';
Parameter CapContingency(net,perA)                      'Rådig kapacitet fratrukket ydelsestab på vp';
Parameter Monotony(unew,perA)                           'Angiver 0/1 om kapacitetsiterationer er monotone';
Parameter MonotonyExists(perA)                          'Angiver 0/1 at mindst ét anlæg har monoton sekvens';
Parameter MonotonyExistsIter(perA,iter)                 'Angiver 0/1 at mindst ét anlæg har monoton sekvens';

* Rapportering erklæringer.
# MOVE Parameter StatsSolver(topicSolver)                      'Model and solve attributes';
Parameter StatsAll(topicAll,perA)                       'Overall stats for hver period';
# MOVE Parameter StatsInfeas(tt,net,infeasDir)                 'Infeasiblities Found';
# MOVE Parameter StatsT(tr,topicT)                             'Transmission topics';
# MOVE Parameter StatsU(u,topicU)                              'Prod unit topics';
# MOVE Parameter StatsVak(vak,topicVak)                        'VAK topics';
# MOVE Parameter StatsTax(upr,tax)                             'Tax topics';
Parameter StatsFox(topicFox)                            'FOX topics';
# MOVE Parameter StatsFuel(f,topicFuel)                        'Fuel topics';
# MOVE Parameter StatsOther(other,topicOther)                  'Other topics';
Parameter StatsTPerIter(tr,topicT,perA,iter)            'StatsT for hver periode i hver iteration';
Parameter StatsUPerIter(u,topicU,perA,iter)             'StatsU for hver periode i hver iteration';
Parameter StatsVakPerIter(vak,topicVak,perA,iter)       'StatsVak for hver periode i hver iteration';
Parameter StatsTaxPerIter(upr,tax,perA,iter)            'StatsTax for hver periode i hver iteration';
Parameter StatsFuelPerIter(f,topicFuel,perA,iter)       'StatsFuel for hver periode i hver iteration';
Parameter StatsOtherPerIter(other,topicOther,perA,iter) 'StatsOther for hver periode i hver iteration';
Parameter StatsSolverPerIter(topicSolver,perA,iter)     'Stats for hver periode i hver iteration';

# MOVE Parameter StatsMecU(uall,topicMecU,moyr)                   'Stats på anlægsniveau til brug for MEC økonomi';
Parameter StatsMecUPerIter(uall,topicMecU,moyr,perA,iter)  'Stats på anlægsniveau til brug for MEC økonomi';
#--- Parameter StatsMecUPerOptim(uall,topicMecU,moyr,perA)      'Stats på anlægsniveau til brug for MEC økonomi for optimal kapacitetsiteration';
#--- Parameter StatsMecUPerLast(uall,topicMecU,moyr,perA)       'Stats på anlægsniveau til brug for MEC økonomi for sidste (konv.) kapacitetsiteration';
# MOVE Parameter StatsMecF(f,topicMecF)                        'Stats på brændselsniveau til brug for MEC økonomi';
Parameter StatsMecFPerIter(f, topicMecF,perA,iter)      'Stats på brændselsniveau til brug for MEC økonomi';

# MOVE Parameter SalesHeatTotal(net)          'All sales DKK';
# MOVE Parameter SalesPowerTotal(net)         'All sales DKK';
# MOVE Parameter CostTotal(net)               'All taxes DKK';
# MOVE Parameter TaxTotal(net)                'All taxes DKK';
# MOVE Parameter CostMaintTotal(net)          'All maintenance costs DKK';
# MOVE Parameter CostStartTotal(net)          'All start-stop costs DKK';
# MOVE Parameter CostPowerTotal(net)          'All power consumption costs DKK';
# MOVE Parameter CostFuelTotal(net)           'All fuel consumption costs DKK';
# MOVE Parameter CostCO2EtsTotal(net)         'All CO2 ETS costs DKK';
# MOVE Parameter TaxEnrTotal(net)             'Energi afgift DKK';
# MOVE Parameter TaxCO2Total(net)             'CO2 afgift DKK';
# MOVE Parameter TaxNOxTotal(net)             'NOx afgift DKK';
# MOVE Parameter TaxSOxTotal(net)             'SOx afgift DKK';
# MOVE Parameter SubsidiesTotal(net)          'All subsidies DKK';

# MOVE Parameter InfeasTotal(net,InfeasDir)   'All heat compensation by virtual drain/source [MWh]';

#--- Parameter CostVakTotal                 'Loading costs on tanks';
# MOVE Parameter CostTransTotal               'Transmission costs';

# Parametre, som tildeles .L attributen af udvalgte variable (performance issue ifm. indlæsning i python fra gdx-fil)
parameter Q_L(tt,u);
parameter QT_L(tt,tr);
parameter QRgk_L(tt,kv);
parameter Qbypass_L(tt,kv);
parameter Qcool_L(tt,ucool);
parameter Pnet_L(tt,kv);
parameter PowInU_L(tt,upr);
parameter bOn_L(tt,upr);
parameter bOnSR_L(tt,netq);
parameter LVak_L(tt,vak);
#--- parameter QUpr2Vak_L(tt,vak);
#--- parameter QT2Vak_L(tt,tr,vak);
#--- parameter CostInfeas_L(tt,net);
                      

Parameter dCapUCostIter(perA,iter)      'dCapUCost historie';
Parameter dMargObjUIter(perA,iter)      'dMargObjU historie';

Parameter ConvergenceCode(iter)        'Konvergens-check kode';
Scalar    ConvCode103                  'Har konvergens-check kode 103 været der';

# MOVE Parameter zNormalized                  'Slave objective in DKK';
# MOVE Parameter zNormalizedReal              'Slave objective minus infeasibility costs DKK';
# MOVE Parameter OperHours(u)                 'Annual operating hours prod.unit';
# MOVE Parameter QMargPrice(u)                'Average marginal unit heat price [DKK/MWh]';
# MOVE Parameter QMargPrice_Hourly(tt,u);
# MOVE Parameter Pbrut(tt,kv)                 'Power generated by CHP plants';
Parameter AlfaBound(bound)             'Stepvektor afgrænsning [0..1]';
Parameter CapNewMinParm(net,perA)      'Mindste behov for ny kapacitet';
Parameter CapUNeedParm(net,perA)       'Mindste kapacitetsbehov i given periode';
Parameter CapUOldSumParm(net,perA)     'Sum af eksist. kapacitet i given periode';
Parameter CapNewOfzParm(perA)          'Ny kapacitet anvendt i periode-optimeringer';
Parameter CapTransmSum(netT,perA)      'Sum af transmissionskapacitet til net';
Parameter dCapNewMinParm(perA)         'Max. kapac-ændring ved alfa=1 ift. MasCapActual';
Parameter AlfaNewMin(perA)             'Alfa som respekterer behov for ny kapacitet';
Scalar    Alfa                         'Aktuel stepvektor længdereduktion';
Parameter AlfaIndi(unew,perA)          'Aktuel stepvektor længdereduktion for hver enkelt unew og per';
Parameter AlfaIndiIter(unew,perA,iter) 'Historik på AlfaIndi over masteriterationerne';
Scalar    AlfaPrev                     'Alfa lige før sikring mod mindste ny kapacitet';
Scalar    AlfaMinPer                   'Største mindsteværdi af Alfa over perioder';
Scalar    AlfaReduc                    'Reduktionsfaktor på Alfa';
Parameter AlfaIter(iter)               'Alfa historie over masteriterationerne';
Scalar    IterAlfa                     'Alfa iterations tæller';
Scalar    IterAlfaOutset               'Iteration som er udgangspunkt for alfa-iterationen'  / 0 /;
Scalar    MasObjMinTotal               'Vægtet mindste master objective DKK';
Scalar    MasObjRel                    'Master objective relativt til NPV DKK';
Scalars   x0, x1, x2, y0, y1, y2, f2, c12, c22, coef0, coef1, coef2;

#end   Erklæringer

#begin Vægtet mindste master objective

MasObjMinTotal = MasObjMinAbs * sum(per, Periods('PeriodHours',per) / card(tt));
display MasObjMinAbs, MasObjMinTotal, PeriodFirst, PeriodLast, PeriodCount;

#end

#begin Anlægsrådighed

# Beregn rådige anlæg i hvert net og hver periode.
# MOVE OnAvailUNet(u,net,perA) = OnNetGlobal(net) AND OnNetNomPer(net,perA) AND AvailUNet(u,net) AND OnUNomPer(u,perA);
OnUPer(u,perA)          = sum(net $OnNetPer(net,perA), OnAvailUNet(u,net,perA));
OnUPer(u,perA)          = OnUPer(u,perA) $(ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast AND OnUGlobal(u));
OnNetPer(net,perA)      = OnNetNomPer(net,perA) AND OnNetGlobal(net);

display OnNetNomPer, AvailUNet, OnUNomPer, OnUPer, OnAvailUNet;

CapUMaxPer(unew,perA) = CapUMaxPer(unew,perA) $OnUPer(unew,perA);


# MOVE # Max. indfyret effekt for hvert anlæg og hver periode, pånær varmepumper som har variabel COP.
# MOVE display EtaQU;
# MOVE loop (u $(uexist(u) AND NOT hpexist(u) AND NOT vak(u)), 
# MOVE   PowInMaxUPer(u,perA) = CapUExistPer(u,perA) / EtaQU(u); 
# MOVE );

# Opsæt øvre grænse for indgivet effekt på produktionsanlæg.
loop (unew $(NOT unewhp(unew) AND NOT vaknew(unew)), PowInMaxUPer(unew,perA) = CapUMaxPer(unew,perA) / EtaQU(unew); );

display PowInMaxUPer;

# Global rådighed trumfer periode-rådighed.
#--- loop (u,
#---   if (NOT OnUGlobal(u),
#---     OnUPer(u,perA)       = 0;
#---     PowInMaxUPer(u,perA) = 0;
#---   );
#--- );
loop (tr,
  if (NOT OnTransGlobal(tr), OnTransPer(tr,perA) = 0; );
);

#end Anlægsrådighed

#--- #DEBUG
#--- execute_unload "MECmain.gdx";
#--- abort.noerror "BEVIDST STOP I INITMASTERLOOP.GMS";

# MOVE #begin Sikring for hver periode at en rådig VAK har mindst eet rådigt produktionsanlæg tilknyttet.
# MOVE 
# MOVE loop (perA $(ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast),
# MOVE   actPer(perA) = yes;
# MOVE   loop (vak $OnUPer(vak,actPer),
# MOVE     actVak(vak) = yes;
# MOVE     nUprOn = 0;
# MOVE     loop (upr $OnUPer(upr,actPer),
# MOVE       if (upr2vak(upr,vak), nUprOn = nUprOn  + 1;  );
# MOVE       actUpr(upr) = yes;
# MOVE     );
# MOVE     nTrOn = 0;
# MOVE     loop (tr $OnTransPer(tr,actPer),
# MOVE        if (tr2vak(tr,vak), nTrOn = nTrOn + 1; );
# MOVE     );
# MOVE     if (nUprOn EQ 0 AND nTrOn EQ 0,
# MOVE       execute_unload "MECmain.gdx"; 
# MOVE       display "ERROR: ", actPer, actVak;
# MOVE       display "ERROR: Ingen af de tilknyttede anlæg eller transmissionslinjer til den rådige VAK (actVak) er aktive i periode actPer. :", actVak;
# MOVE       abort "ERROR: Ingen af de tilknyttede anlæg eller transmissionslinjer til den rådige VAK (actVak) er aktive i periode actPer.";
# MOVE     );
# MOVE   );
# MOVE );

#end

# Tag højde for at en given periodes længde afviger fra en årslængde ( ikke aktuelt i MEC-modellen).
#remove loop (perA $(ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast), ShareOfYear(perA) = Periods('PeriodHours',perA) / 8760.0; );
ShareOfYear(per) = Periods('PeriodHours',per) / 8760.0;

#begin Initialisering af startværdi for dynamiske kapaciteter inden periode-optimeringer.

# NB: Master-iteration nr. 1 er ikke en iteration, men starttilstanden.
BoundViolation(unew,perA,bound) = 0.0;
bestIter('iter1') = yes;

#--- $OffOrder

MasCapU(unew,perA,'iter1')    = 0.0;  # VIGTIGT AT TAGE UDGANGSPUNKT I NUL-KAPACITETER FOR NYE ANLÆG AHT CAPEX-beregning.
MasdCapU(unew,perA,'iter1')   = 0.0;
MasCapActual(unew,perA)       = 0.0;
StepULenIter('iter1')         = 0.0;
dCapUOfzLenIter(perA,'iter1') = 0.0;


OnFixedCapU(unew,perA) = 0;  # Alle nye anlæg har som udgangspunkt frie kapaciteter.

# OBS Dette loop herunder skal køre over perA, ikke per, idet nye TILLÆGS-kapaciteter initialiseres i periode 1, og akkumulerer henover perioderne.
# OBS Er det stadig aktuelt ?

Loop (perA $(ord(perA) LE PeriodLast),
  actPer(perAlias) = (ord(perAlias) EQ ord(perA));
  
  NProjNetIter(net,'iter1') = 0;
  NProjUIter(unew, 'iter1') = 0;
  bOnInvestUIter(unew,perA,'iter1') = 0;
  
  # dCapUInit indeholder startgæt på mer-kapacitet i en given periode.
  #--- If (ord(perA) EQ 1,
  #---   MasCapActual(unew,perA) = dCapUInitPer(unew,perA) $OnUPer(unew,perA);
  #--- Else
    MasCapActual(unew,perA) = dCapUInitPer(unew,perA) $OnUPer(unew,perA) + MasCapActual(unew,perA-1) $(ord(perA) GE 2);
  #--- );
  
  # Eksisterende anlæg overføres også til MasCapActual, så kapaciteterne holdes på ensartet form.
  MasCapActual(uexist,perA) = CapUExistPer(uexist,perA);
  
  display actPer, MasCapActual;
  
  MasCapBest(unew,perA)               = MasCapActual(unew,perA) $OnUPer(unew,perA);
  MasCapActualIter(unew,perA,'iter1') = MasCapActual(unew,perA) $OnUPer(unew,perA);
  MasCapBestIter(unew,perA,'iter1')   = MasCapActual(unew,perA) $OnUPer(unew,perA);
  MasCapActualSum(net,perA)           = sum(unew $OnAvailUNet(unew,net,perA), MasCapActual(unew,perA));

  # Marker hvis kapacitetsgrænserne er overskredet og træk ind på nærmeste grænse.
  loop(unew $OnUPer(unew,perA),
  
    If (MasCapActual(unew,perA) LT CapUMinPer(unew,perA) $OnUPer(unew,perA) - tiny,
      BoundViolation(unew,perA,'min') = [MasCapActual(unew,perA) - CapUMinPer(unew,perA) $OnUPer(unew,perA)];
      MasCapActual(unew,perA) = CapUMinPer(unew,perA) $OnUPer(unew,perA);
      
    ElseIf MasCapActual(unew,perA) GT CapUMaxPer(unew,perA) $OnUPer(unew,perA) + tiny,
      BoundViolation(unew,perA,'max') = [MasCapActual(unew,perA) - CapUMaxPer(unew,perA) $OnUPer(unew,perA)];
      MasCapActual(unew,perA) = CapUMaxPer(unew,perA) $OnUPer(unew,perA);
    );
  );

  # Bestem om et anlægs kapacitet er de-facto låst mellem nedre og øvre grænse.
  loop(unew $OnUPer(unew,perA),
    If (abs(CapUMaxPer(unew,perA) - CapUMinPer(unew,perA)) LT 1E-3,
      OnFixedCapU(unew,perA) = 1;
    );  
  );
);
#--- $OnOrder

# Stop hvis initialkapacitet overskriver grænserne.
If (sum(unew, sum(perA, sum(bound, abs(BoundViolation(unew,perA,bound))))) GT 0,
  execute_unload "MECmain.gdx"; 
  display BoundViolation;
  #--- abort "Nogle initialkapaciter dCapUInitPer er udenfor grænserne. Se hvilke i BoundViolation, som er listet herover";
  display "ERROR: Nogle initialkapaciter dCapUInitPer er udenfor grænserne og er derfor trukket ind på grænsen. Se hvilke og overskridelsen i BoundViolation, som er listet herover";
  abort "Nogle initialkapaciter dCapUInitPer er udenfor grænserne og er derfor trukket ind på grænsen. Se hvilke og overskridelsen i BoundViolation, som er listet herover";
);

# Check at initialkapaciteterne MasCapActual opfylder mindstebehovet i hver periode.
# Først beregnes den mindste sum af aktive variable kapaciteter, som skal være tilstede i hver periode.
CapUNeedParm(net,per)     = 0.0;
CapUOldParm(u,net,per)    = 0.0;
CapTransmSum(net,per)     = 0.0;
CapNeedViolation(net,per) = 0.0;
CapContingency(net,per)   = 0.0

$OffOrder
Loop (per,
  OnUNet(u,net) = OnUPer(u,per) AND OnNetPer(net,per) AND AvailUNet(u,net);
  Loop (net $OnNetPer(net,per),
    CapUNeedParm(net,per)        = QDemandPeakYr(net,per) + CapUReservePer(net,per);
    #--- CapUOldParm(uexist,net,per) = CapUExistPer(uexist,per) $(OnUPer(uexist,per) AND OnUNet(uexist,net) AND NOT vakexist(uexist));
    CapUOldParm(uexist,net,per)  = CapUExistPer(uexist,per) $(OnUPer(uexist,per) AND OnUNet(uexist,net) AND NOT ucoolexist(uexist) AND NOT vakexist(uexist));
    CapUOldSumParm(net,per)      = sum(uexist, CapUOldParm(uexist,net,per));
    CapUNewMaxParm(unew,net,per) = CapUMaxPer(unew,per) $(OnUPer(unew,per) AND OnUNet(unew,net) AND NOT ucoolnew(unew) AND NOT vaknew(unew));
    CapUNewMaxSumParm(net,per)   = sum(unew, CapUNewMaxParm(unew,net,per));
    CapTransmSum(net,per)        = sum(netF, sum(tr $OnTransPer(tr,per), DataTransm(tr,'QTmax') $OnTransNet(tr,netF,net))); 
    CapNewMinParm(net,per)       = CapUNeedParm(net,per) - CapUOldSumParm(net,per) - CapTransmSum(net,per);
    CapAvailShareMaxParm(tr,per) = sum(net2tr(netF,tr), OwnerShare(tr) * [CapUOldSumParm(netF,per) + CapUNewMaxSumParm(netF,per)] $OnTransPer(tr,per));

#---    if (ord(per) EQ 1,
#---      CapNewMinParm(net,per) = CapUNeedParm(net,per) - CapUOldSumParm(net,per);
#---    else
#---      CapNewMinParm(net,per) = [CapUNeedParm(net,per) - CapUNeedParm(net,per-1)] - [CapUOldSumParm(net,per) - CapUOldSumParm(net,per-1)];
#---    );

    # Tag højde for kapacitetsreduktion på varmepumper ved vurdering af, om den aktuelle kapacitet opfylder mindstebehovet.
    CapContingency(net,per) = MasCapActualSum(net,per) - sum(unewhp $OnAvailUNet(unewhp,net,per), (1 - CapFacN1Res(unewhp)) * MasCapActual(unewhp,per));
    CapNeedViolation(net,per) = (CapContingency(net,per) LT CapNewMinParm(net,per));
  );
);
$OnOrder
display MasterIter, CapUNeedParm, CapNewMinParm, CapUOldParm, CapUOldSumParm, CapTransmSum, MasCapActualSum, CapContingency, CapNeedViolation;

# Stop hvis initialkapaciteter ikke opfylder mindstebehovet.
If (sum(net, sum(per, CapNeedViolation(net,per))) GT 0,
  execute_unload "MECmain.gdx"; 
  display "Mindst én initial kapacitet opfylder ikke mindstebehovet. Se CapNeedViolation herover for at lokalisere problemet.";
  display "Det kan skyldes den reducerede beredskabskapacitet CapFacN1Res på varmepumper";
  abort "Initialkapaciteter opfylder ikke mindstebehovet. Se CapNeedViolation herover for at lokalisere problemet.";
  
#--- if (1, abort "Tvunget stop mhp. debug af CapNeedViolation.");
);

# Lås kapaciteter og tilvækst til nul for de nye anlæg, som ikke er rådige.
loop (unew,
  Loop (per,
    If (OnUPer(unew,per) EQ 0,
      CapU.fx(unew,per)  = 0.0;
      dCapU.fx(unew,per) = 0.0;
    );
  );
);

#remove dCapUNeed.fx(net,'per1')   = 0.0;
#remove dCapUSumOld.fx(net,'per1') = 0.0;
#remove CapUNewMin.fx(net,'per1')  = 0.0;

#end



#begin Initialisering / tildeling af resultatværdier for master iteration 1 (som ikke er en iteration, men en initialisering).
MasPenaltyCostActual('iter1') = sum(per, ExcessCapPenalty(per) * sum(net $OnNetPer(net,per), CapUOldSumParm(net,per) + MasCapActualSum(net,per) - CapUNeedParm(net,per)));
MasterBestIter('iter1')       = 1;
MasObjIter('iter1')           = 0.0;
MasterObjMaxIter('iter1')     = 10 * PeriodObjScale;
dNPVIter('iter1')             = 0.0;
NPVIter('iter1')              = -999E+6 * PeriodCount - MasPenaltyCostActual('iter1');
NPVBestIter('iter1')          = NPVIter('iter1');
AlfaBound('min')              = 0.0;
AlfaBound('max')              = 1.0;
IterAlfa                      = 0.0;
Alfa                          = 1.0;
AlfaIter('iter1')             = 1.0;
ConvergenceCode('iter1')      = 0;
ConvCode103                   = 0;

loop (per,
  MasCapActualIter(unew,per,'iter1')   = MasCapActual(unew,per) $OnUPer(unew,per);
  CapUIter(unew,per,'iter1')           = MasCapActual(unew,per) $OnUPer(unew,per);
  AlfaIndi(unew,per)                   = 1.0 $OnUPer(unew,per);
  #--- AlfaIndi(unew,per)                   = 1.0 $(OnUPer(unew,per) AND NOT OnFixedCapU(unew,per));
  AlfaIndiIter(unew,per,'iter1')       = AlfaIndi(unew,per);
  dCapUOfzIter(unew,per,'iter1')       = tiny $OnUPer(unew,per);
  dMargObjUIter(per,'iter1')           = tiny;
  GradUMargIter(unew, per,'iter1')     = tiny $OnUPer(unew,per);
  GradUMargAggrIter(unew, per,'iter1') = tiny $OnUPer(unew,per);
  GradCapUIter(unew, per,'iter1')      = tiny $OnUPer(unew,per);
  GradUIter(unew, per,'iter1')         = tiny $OnUPer(unew,per);
  GradUAggrIter(unew, per,'iter1')     = tiny $OnUPer(unew,per);
  ExcessCapUIter(net,per,'iter1')      = tiny;
);
display MasCapU;

#end

