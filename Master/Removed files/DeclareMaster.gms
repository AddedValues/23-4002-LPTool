$log Entering file: %system.incName%
#(
$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        DeclareMaster.gms
Scope:          Overfører indlæste data for mastermodel.
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText


#begin Master parametre

# Parameteren AlfaReducIndiv styrer konvergenshastigheden for AlfaVersion GE 4.
# 0.80 er for højt og er set at medføre oscillationer (divergens), idet 0.80 kompenseres af den opadgående korrektion på 1.25.
Scalar    AlfaReducIndiv       'Alfa reduktionsfaktor AlfaVersion GE 4'  / 0.65 /;  
Scalar    AlfaExpandIndiv      'Alfa ekspansionfaktor AlfaVersion GE 4'  / 1.00 /;  

Parameter Scenarios(scenMasValue, scenMas)  'Master scenariers værdier';
Parameter ActScen(scenMasValue)             'Aktuelt master scenarie værdier';
Parameter ZeroScenMembers(scenMasValue)     'Scenarie elementer == 0';
Parameter cpStatsMonthPerIter(iter,cp,cpStatType,mo,perA) 'Stats for centrale anlæg';
Parameter ShareOfYear(perA)                 'Hver periodes antal af en normalår';
Parameter YearShare                         'En periodes andel af et normalår';
Parameter YearSharePer(perA)                'Hver periodes andel af et normalår';
Parameter Inflation                         'Inflations nedskrivning ift. en referenceperiode';
# MOVE TO Declarations.gms Parameter TimeBlocks(tt,aggr,yrPlan)        'Tidsblokkes starttime';     # TimeAggr

#begin Master parametre
Scalar    ScenarioID           'ID kodes som MmmSssUuuRrrFff';   # M= Model, S=Scenarie, U=Underscenarie, R=Roadmap, F=Følsomhed.
Scalar    SaveTimeStamp        'Tidspunkt hvor input-filen blev gemt';
# MOVE Scalar    InterestRate         'Kalkulationsrente procent p.a.';
# MOVE Scalar    InflationRate        'Inflationsrate procent p.a.';
Scalar    InvLenTransmPipe     'Afskrivningsperiode T-ledninger [år]';
Scalar    InvLenTransmPump     'Afskrivningsperiode Pumpestationer [år]';
Scalar    PmtTransmPipe        'Afskrivningsrate for T-ledning [DKK/år]';
Scalar    PmtTransmPump        'Afskrivningsrate for pumpestationer [DKK/år]';
Scalar    YearStart            'Første kalenderår i planperioden';
Scalar    YearCount            'Antal kalenderår i planperioden';
Scalar    PeriodFirst          'Første periode i planperioden';
Scalar    PeriodLast           'Sidste periode i planperioden';
Scalar    PeriodCount          'Antal perioder i planperioden';
Scalar    MasObjMinAbs         'Mindste værdi af Master obj i middel pr. periode';
Scalar    MasObjMinRel         'Mindste værdi af Master obj pr. periode relativt til abs(NPV)';
Scalar    ExtractDayInterval   'Antal døgn mellem udtræk';
Scalar    ExtractDayFirst      'Første årsdag som skal udtrækkes';
Scalar    StepMax              'Max. størrelse af kapacitetsændring';
Scalar    EpsDeltaCap          'Min. rel ændring af stepvektorens længde';
Scalar    EpsDeltaNPVLower     'Min. nedre ændring af nutidsværdien';
Scalar    EpsDeltaNPVUpper     'Min. øvre ændring af nutidsværdien';
Scalar    MaxIterBelowBest     'Max. antal master-iterationer i træk med NPV under hidtil bedste';
Scalar    MasterIterMax        'Max. antal master-iterationer';
Scalar    IterAlfaMax          'Max. antal iterationer på stepvektorens længde';
Scalar    AlfaMin              'Min. relativ længde på stepvektor [0..1]';
Scalar    MipGapScheme         'Nr. på algoritme til beregning af mipgap i slave solve';
Scalar    MipGapMin            'Mindste mipgap der anvendes i slave solve';
Scalar    MipGapMax            'Største mipgap der anvendes i slave solve';
Scalar    MipIterBegin         'Parameter i MipGapScheme';
Scalar    MipIterEnd           'Parameter i MipGapScheme';
Scalar    WriteMasterOutput    'Angiver 0/1 at MasterOutput skal udskrives for hver masteriteration, ikke kun den sidste';
Scalar    Found                'Angiver 0/1 at en betingelse er opfyldt';
Scalar    PrevOrigPeriod       'Index (ordinal) af seneste originale periode';  
Scalar    NactiveNewPlant      'Antal globalt aktive nye varmeproduktionsanlæg';
          
Scalar    OnNpvPenalty         'Angiver 0/1 at overskydende ny kapacitet pålægges penalty i mastermodellen';
Scalar    AllowExcessCap       '';
Scalar    ReserveCapQ          'Reservekapacitet udover (n-1) beredskab';
Scalar    OnMinCapacIncrement  'Angiver 0/1 aktivering af nedre grænse dCapUMin i mastermodel';
Scalar    OnCapex0             'Angiver 0/1 aktivering af kapac-uafh. projektomkostninger i mastermodel';
Scalar    OnMaxProjNet         'Angiver 0/1 aktivering af projektantalsgrænse på net-niveau';
Scalar    OnMaxProjU           'Angiver 0/1 aktivering af projektantalsgrænse på anlægs-niveau';
Scalar    OnMinProjSeqU         'Angiver 0/1 aktivering af min. antal år mellem anlægsprojekt på anlægs-niveau';
Parameter MaxProjNet(net)      'Angiver max. antal projekter på net-niveau over planhorisonten';
Parameter MaxProjU(unew)       'Angiver max. antal projekter på anlægs-niveau over planhorisonten';
Parameter MinProjSeqU(unew)    'Angiver min. antal perioder mlm. antal projekter på anlægs-niveau over planhorisonten';

Scalars   ScenarioID;
Scalars   rate, nTerm, fDeprec, fixCost, fixCostPlan, capex0, capex1, capp, dcapp, dNPV, dNPVBest, deprecMarg, deprecMargPlan, deprecAbsPlan, CostCap; #--- deprecAbs, 

Scalar    MasterIter                       'Master iterationstæller'  / 1 /;
# MOVE Scalar    NPV                              'Aktuel nutidsværdi';
# MOVE Scalar    NPVBest                          'Hidtil bedste nutidsværdi';
                                         
Scalar    RealRente                        'Nom. rente fratrukket inflation';
Scalar    MasterObjMax                     'Max. grænse på master obj';
Scalar    ReserveCapQ                      'Reservelast kapacitet MWq';
Scalar    MaxStorFyr                       'Maks grænse på sum af biokedler (store-fyringsanlæg sammenlægningsregler)';

Parameter zMasterIter(iter)                'Master obj inkl. penalties';
Parameter MasCapU(unew,perA,iter)          'Kapaciteter fra hver iteration';
Parameter MasdCapU(unew,perA,iter)         'Kapacitetsændringer fra hver iteration';
Parameter MasObjIter(iter)                 'Master objektfunktion fra hver iteration';
Parameter PerMargObj(perA,iter)            'Periode driftsmæssig objektfunktion for hver iteration';
Parameter CapUCostPerIter(u,perA,iter)     'Kapacitetsomkostninger i planperioden for hver iteration';
Parameter CapUCostSumPerIter(perA,iter)    'CapUCostPerIter summeret over u';

Parameter NPVIter(iter)                    'Nutidsværdi for hele planperioden';
Parameter dNPVIter(iter)                   'Ændring i nutidsværdi NPV';
Parameter ExcessCapPenalty(perA)           'Straf på overflødig kapacitet DKK/MWq' ;
Parameter ExcessCapPermitted(perA)         'Angiver 0/1 at invest. i overskudskapacitet er tilladt';
Parameter OnFixedCapU(unew,perA)           'Angiver 0/1 om et nyt anlæg har låst kapacitet';   # Låst således, at CapUMin == CapUMax.

Parameter Periods(scenPerValue,perA)       'Periode parametre';
Scalar    OnDuplicatePeriods               'Angiver -1/0/1 om periodeduplikering er aktivt';  # NB: -1 betyder, at duplikering ophæves hvis OnDeAggr == TRUE.
Scalar    NDuplicates                      'Antal duplikerede perioder efter en beregnet periode';
Scalar    BeginOrig                        'Første beregnede periode i en sekvens med dubletter';
Scalar    EndOrig                          'Sidste beregnede periode i en sekvens med dubletter';
Parameter PeriodWeight(perA)               'Hældningskoeff. ifm. periodeinterpolation';
Parameter DuplicateUntilIteration(perA)    'Angiver masteriteration hvorfra periode-duplikering ophører';
Parameter PeriodOriginal(perA,begend)      'Angiver perA index på perioder som er start- hhv. slut-original for mellemliggende interpolerede perioder';
Parameter PeriodIsDuplicate(perA,iter)     'Angiver > 0 fra hvilken periode, perA er kopieret (ordinal(perA))';

Parameter YearScen(scenYearValue,scyr,yr)  'Kalenderårs parametre ';
Parameter YearScenActual(scenYearValue,yr) 'Parametre for aktuelt årsscenarie';
Parameter QLargestCp(perA)                 'Største centrale kapacitet i given periode';

Parameter CapTInitPer(tr,perA)             'Initial kapacitet af T-ledning [mm]';   # Før periode per1 er kapaciteten nul, så dCapInit(unew,'per1') indeholder den fulde startkapacitet.
Parameter CapTMinPer(tr,perA)              'Min. DN-størrelse i given periode MWq';
Parameter CapTMaxPer(tr,perA)              'Max. DN-størrelse i given periode MWq';

Parameter MasterObjMaxIter(iter)           'MasterObjMax over iterationshistorien';
Parameter CapUReservePer(net,perA)         'Reserve capacity [MWq]';
Parameter dCapUInitPer(unew,perA)          'Initiel merkapacitet [MWq]';   # Før periode per1 er kapaciteten nul, så dCapInit(unew,'per1') indeholder den fulde kapacitet.
Parameter dCapUInitPerRead(unew,perA)      'Initiel merkapacitet [MWq]';   # Før periode per1 er kapaciteten nul, så dCapInit(unew,'per1') indeholder den fulde kapacitet.
Parameter dCapUInitPerMax(unew)            'Største dCapUMinPer henover aktive perioder';
Parameter dCapUMinPer(unew,perA)           'Min. kapacitetsændring ift. forrige periode MWq'; # OBS: Bruges kun ved OnMinCapacIncrement > 0.
Parameter CapUInitPer(unew,perA)           'Initiel kapacitet [MWq]'; 
Parameter CapUMinPer(unew,perA)            'Min. kapacitet i given periode MWq';
Parameter CapUMaxPer(unew,perA)            'Max. kapacitet i given periode MWq';
#--- Parameter dCapUMax(unew)                   'Max. kapacitetsændring i aktuel master-iteration';
Parameter dCapUMaxPer(unew,perA)           'Aktuel max. kapacitetsændring i given periode i aktuel master-iteration';
Parameter dCapUMaxInitPer(unew,perA)       'Initiel (indlæst) max. kapacitetsændring i given periode';
Parameter dCapUMaxIter(unew,iter)          'Aktuel max. kapacitetsændring i hver master-iteration';
Parameter dCapUMaxIterPer(unew,perA,iter)  'Aktuel max. kapacitetsændring i hver master-iteration';
                                           
Parameter GradU(unew,perA)                 'Effektiv skyggepris for periode obj';
Parameter GradUMarg(unew,perA)             'Marginal (driftsmæssig) skyggepris for periode obj';
Parameter GradCapU(unew,perA)              'Gradient af kapac.-omkostn.';
Parameter GradUIter(unew,perA,iter)        'Effektiv skyggepris for periode obj';
Parameter GradUMargIter(unew,perA,iter)    'Marginal (driftsmæssig) skyggepris for periode obj';
Parameter GradUMargAggrIter(unew,perA,iter)'Aggregerede skyggepriser';
Parameter GradCapUIter(unew,perA,iter)     'Gradient af kapac.-omkostn.';
Parameter GradUAggrIter(unew,perA,iter)    'Aggregerede effektiv gradient';
Parameter GradUCompMax(perA)               'Max numerisk komposant af effektiv master-gradient';
Parameter GradURel(unew,perA)              'Relativ størrelse af effektive gradients komposanter';
Parameter GradURelIter(unew,perA,iter)     'Relativ størrelse af effektive gradients komposanter';
Parameter SumGradUAggr(perA)               'Abs. sum af GradUAggr over unew';
Parameter SumGradUAggrIter(perA,iter)      'Abs. sum af GradUAggr over unew';
Parameter StepScale(perA)                  'Stepvektor skaleringsfaktor baseret på GradUAggr';
Parameter StepScaleIter(perA,iter)         'Stepvektor skaleringsfaktor baseret på GradUAggr';
Parameter SumGradUAggrRef(perA)            'Ref. for stepvektor skaleringsfaktor';
Parameter dCapUAnyMax(perA)                'Grænse for kapac-ændring i given periode';
                               
#- Parameter MatchPerObj(perA,iter)        'Afstand mlm periodeobj';

Parameter NProjNetIter(net,iter)            'Antal anlægsprojekter pr. net';
Parameter NProjUIter(unew,iter)             'Antal anlægsprojekter pr. unew';
Parameter bOnInvestUIter(unew,perA,iter)    '0/1 investering i merkapacitet';

Parameter MasCapOfz(unew,perA)              'Udgangspunkt for kapaciteter i master-optimering';
Parameter MasCapOfzIter(unew,perA,iter)     'Udgangspunkt for kapaciteter i master-optimering';
Parameter MasCapActualSum(net,perA)         'Sum af frie kapaciteter for hvert net i hver periode';
Parameter MasCapActual(u,perA)              'Udgangspunkt for kapaciteter i periode-optimering';
Parameter MasCapActualIter(unew,perA,iter)  'Udgangspunkt for kapaciteter i periode-optimering';
Parameter MasCapBest(unew,perA)             'Kapaciteter fra bedste forrige master-iteration';
Parameter MasCapBestIter(unew,perA,iter)    'Historik over MasCapBest';
Parameter CapUIter(unew,perA,iter)          'Iterative kapaciter CapU';
Parameter dCapUIter(unew,perA,iter)         'Iterative kapac-ændringer dCapU';
Parameter dCapUOfzIter(unew,perA,iter)      'Iterative kapac-ændringer dCapUOfz';
Parameter dCapUOfzAggrIter(unew,perA,iter)  'Iterative aggregerede kapac-ændringer fra og med given periode';
Parameter MasterBestIter(iter)              'Index of best master iteration';
Parameter NPVBestIter(iter)                 'Hidtil bedste nutidsværdi';
Parameter ExcessCapUIter(net,perA,iter)     'Overflødig kapacitet i hvert net i hver periode og master-iteration';
Parameter GradUMargAggr(unew,perA)          'Marginal (drift) gradient komposant aggregeret fra periode per til slut';
Parameter GradUAggr(unew,perA)              'Effektiv gradient komposant excl MasPenaltyCost aggregeret fra periode per til slut';
Parameter MasPenaltyCostActual(iter)        'Actuelle penalty cost associeret med overkapacitet der skal trækkes fra NPV i konvergensvurdering';
Parameter CapUOldSumParm(net,perA)          'Sum af eksist. kapacitet [MWq] for hver periode';
Parameter CapUNewMaxParm(unew,net,perA)     'Øvre grænse for kapaciteter';
Parameter CapUNewMaxSumParm(net,perA)       'Øvre grænse for kapaciteter';
Parameter CapAvailShareMaxParm(tr,perA)     'Øvre grænse for ejerandel af max rådig produktionskapacitet';


Parameter ExcessCapUExist(perA)             'Sum af eksist. overkapacitet [MWq] for hver periode';
Parameter CapUNeedParm(net,perA)            'Nødvendig totalkapacitet [MWq] for hver periode';
# MOVE Parameter OnAvailUNet(u,net,perA)           'Angiver at givet rådigt anlæg er aktivt i givet net i given periode';

Parameter CapacFuelPer(f,net,perA)          'Rådig produktionskapacitet fordelt på net og fuel';
                                           
# MOVE Parameter CapexTrans(tr)                    'Afskrivning på T-ledninger [kr/år]';
# MOVE Parameter CapexPump(tr)                     'Afskrivning på pumpestationer [kr/år]';

#end   Master parametre

# TODO Tilføj vars og eqns til håndtering af lagerstand ved periodeovergang

#begin Master variable

Free     variable zMaster                          'Master obj værdi';
Positive variable CapUExcess(net,perA)             'Overflødig kapacitet i given periode';
Positive variable CapU(unew,perA)                  'Kapaciteter i hver periode';
Positive variable CapUNewSum(net,perA)             'Sum af nye kapaciteter i hver periode';
Positive variable MasPenaltyCost(perA)             'Penalty cost for overflødig kapacitet';
Positive variable dCapU(unew,perA)                 'Kapacitetsændring fra periode til næste';
Free     variable dCapUOfz(unew,perA)              'Kapac-ændring ift. periode-optim. kapaciteter';
Free     variable dCapUOfzAggr(unew,perA)          'Aggr. mer-kapacitet fra og med given periode';
Free     variable dCapUCost(perA)                  'Kapac-omkostn. ved mer-kapacitet';
Free     variable dMargObjU(perA)                  'Mer-DB ved aggreg. mer-kapacitet';

#--- Free     variable CapUNewMin(net,perA)             'Mindstebehov for ny kapacitet';
#--- Free     variable dCapUNeed(net,perA)              'Ændring i kapacitetsbehov';
#--- Free     variable dCapUSumOld(net,perA)            'Ændring i eksist. kapac. ift. forrige periode';

Positive variable CapUInfeas(InfeasDir,net,perA)   'Virtuelt kapacitet til brug for debug af infeasible mastermodel';
                                                   
Positive variable SumCapex0(perA)                  'Sum af capex0 over unew i given periode';
Positive variable NProjNet(net)                    'Antal projekter på net-niveau';
Positive variable NProjU(unew)                     'Antal projekter på anlægs-niveau';
Binary   variable bOnInvestU(unew,perA)            'Angiver 0/1 om dCapU er positiv';


#end Master variable

#begin Master equation declaration

Equation  EQ_MasObj                              'Master objektfunktion';
Equation  EQ_MasPenaltyCost(perA)                'Beregner penalty for overflødig kapactet';
Equation  EQ_CapUInfeasMax(InfeasDir,net,perA)   'Øvre grænse for virtuel anlægskapacitet';
Equation  EQ_CapUCost(perA)                      'Kapac-omkostn. ved mer-kapacitet';
Equation  EQ_MargObjU(perA)                      'Mer-DB ved aggreg. mer-kapacitet på anlæg';
Equation  EQ_dCapUOfzAggr(unew,perA)             'Aggreg. mer-kapaciteter fra og med given periode';
Equation  EQ_dCapUOfz(unew,perA)                 'Beregner kapac-ændring ift. periode-optim.';
                                                
# Ligninger på anlægsniveau.
Equation  EQ_CapUMonotony(unew,perA)     'Monotont stigende kapaciteter';
Equation  EQ_CapUMin(unew,perA)          'Mindste kapacitet';
Equation  EQ_CapUMax(unew,perA)          'Største kapacitet';
Equation  EQ_dCapU(unew,perA)            'Relation mellem kapacitet og tilvækst';
Equation  EQ_dCapUOfzMin(unew,perA)      'Nedre grænse for ændringens størrelse ift. forrige iteration';
Equation  EQ_dCapUOfzMax(unew,perA)      'Øvre  grænse for ændringens størrelse ift. forrige iteration';

# Ligninger på tværs af anlæg (på net- og periode-niveau).;
#remove Equation  EQ_dCapUSumMin(net,perA)       'Sikrer at kapacitetsændringer opfylder behov for ny kapacitet';
#remove Equation  EQ_CapUNewMin(net,perA)        'Beregner mindste behov for ny kapacitet';
#remove Equation  EQ_dCapUNeed(net,perA)         'Beregner ændring i kapacitetsbehov ift. forrige periode';
#remove Equation  EQ_dCapUOldSum(net,perA)       'Beregner ændring i eksist. kapac. ift. forrige periode';

Equation  EQ_CapUNewSum(net,perA)        'Beregner ny kapacitet kapacitet';

Equation  EQ_Capex0(perA)                'Sum af capex0 for unew over planhorisonten';
Equation  EQ_dCapUMin(unew,perA)         'Nedre grænse på merinvestering ift. forrige periode';
Equation  EQ_dCapUMax(unew,perA)         'Øvre grænse på merinvestering ift. forrige periode';
Equation  EQ_NProjNet(net)               'Antal projekter på net-niveau over planhorisonten';
Equation  EQ_NProjU(unew)                'Antal projekter på anlægs-niveau over planhorisonten';
Equation  EQ_MaxProjNet(net)             'Aktiverer loft på antal projekter på net-niveau';
Equation  EQ_MaxProjU(unew)              'Aktiverer loft på antal projekter på anlægs-niveau';
Equation  EQ_MinProjSeqU(unew,perA)      'Højst eet anlægsprojekt i givet antal perioder';

#end

#begin Master equation spec.

$OffOrder

# dCapU    er kapac-ændringen fra den forrige periode til den næste.
# dCapUOfz er kapac-ændringen ift. forrige master-iterations kapaciteter MasCapOfz.


EQ_MasObj  ..  zMaster  =E=  sum(per, dMargObjU(per) - dCapUCost(per) - SumCapex0(per) - MasPenaltyCost(per) );

# Marginal forbedringen i en given periode er i den lineariserede version
# lig med den aggregerede gradient GradUMargAggr multipliceret med merkapaciteten dCapUOfz.
EQ_MargObjU(per) .. dMargObjU(per)  =E=  sum(unew $OnUPer(unew,per), dCapUOfz(unew,per) * GradUMargAggr(unew,per));
EQ_CapUCost(per) .. dCapUCost(per)  =E=  sum(unew $OnUPer(unew,per), dCapUOfz(unew,per) * GradCapU(unew,per));
EQ_MasPenaltyCost(per) .. MasPenaltyCost(per) =E= ExcessCapPenalty(per) * sum(net $OnNet(net), CapUExcess(net,per)) $OnNpvPenalty 
                                                + ExcessCapPenalty(per) * sum(net $OnNet(net), sum(InfeasDir, (CapUInfeas(InfeasDir,net,per))) );
EQ_CapUInfeasMax(InfeasDir,net,per)  .. CapUInfeas(InfeasDir,net,per)  =L=  CapUInfeasMax;
#begin Kapac-uafh. omkostninger og begrænsninger på antal anlægsprojekter.

EQ_Capex0(per) .. SumCapex0(per)  =E=  sum(unew $OnUPer(unew,per), Capex(unew,'capex0') * 1E6 * YearSharePer(per) * bOnInvestU(unew,per) ) $OnCapex0;

EQ_dCapUMin(unew,per) $OnUPer(unew,per) .. dCapU(unew,per) =G=  [dCapUminPer(unew,per) $OnMinCapacIncrement + CapUminPer(unew,per) $(NOT OnMinCapacIncrement)]  * bOnInvestU(unew,per);
EQ_dCapUMax(unew,per) $OnUPer(unew,per) .. dCapU(unew,per) =L=  CapUmaxPer(unew,per) * bOnInvestU(unew,per);
#--- EQ_dCapUMax(unew,per) $OnUPer(unew,per) .. dCapU(unew,per) =L=  (CapUmaxPer(unew,per) - CapUmaxPer(unew,per-1))  * bOnInvestU(unew,per);

EQ_NProjNet(net) $OnNetGlobal(net) .. NProjNet(net)  =E=  sum(unew, sum(per $OnAvailUNet(unew,net,per), bOnInvestU(unew,per)));
EQ_NProjU(unew)  $OnUGlobal(unew)  .. NProjU(unew)   =E=  sum(per, bOnInvestU(unew,per) $OnUPer(unew,per));
 
EQ_MaxProjNet(net) $(OnMaxProjNet AND MaxProjNet(net) GT 0) ..  NProjNet(net)  =L=  MaxProjNet(net); 
EQ_MaxProjU(unew)  $(OnMaxProjU   AND MaxProjU(unew)  GT 0) ..  NProjU(unew)   =L=  MaxProjU(unew); 

EQ_MinProjSeqU(unew,per) $(OnUPer(unew,per) AND OnMinProjSeqU AND MinProjSeqU(unew) GT 0 AND ord(per) LE (PeriodCount - (MinProjSeqU(unew)-1)) ) ..
                         sum(perAlias $(ord(perAlias) GE (ord(per)+PeriodFirst-1) AND ord(perAlias) LE (ord(per)+PeriodFirst-1+MinProjSeqU(unew)-1) ), bOnInvestU(unew,perAlias))  =L=  1;
                         
#end 


#begin Ligninger på anlægsniveau.

# Sikrer at hver anlægskapacitet er ikke-aftagende henover planperioden.
EQ_CapUMonotony(unew,per) $(ord(per) GE 2 AND OnUPer(unew,per)) .. CapU(unew,per)  =G=  CapU(unew,per-1);

EQ_CapUMin(unew,per) $OnUPer(unew,per)  ..  CapU(unew,per)  =G=  CapUMinPer(unew,per) * bOnInvestU(unew,per);
EQ_CapUMax(unew,per) $OnUPer(unew,per)  ..  CapU(unew,per)  =L=  CapUMaxPer(unew,per);
#--- EQ_CapUMax(unew,per) $OnUPer(unew,per)  ..  CapU(unew,per)  =L=  CapUMaxPer(unew,per) * bOnInvestU(unew,per);

EQ_dCapUOfz(unew,per)     $OnUPer(unew,per) ..  dCapUOfz(unew,per)     =E= CapU(unew,per) - MasCapOfz(unew,per);

EQ_dCapUOfzAggr(unew,per) $OnUPer(unew,per) ..  dCapUOfzAggr(unew,per) =E= sum(perAlias $(ord(perAlias) GE (ord(per)+PeriodFirst-1) AND ord(perAlias) LE PeriodLast), dCapUOfz(unew,perAlias));

#--- #NEW 
#remove Equation EQ_MaxSumdCapUOfz(net,perA) 'Øvre grænse for sum af kapac-ændring';
#--- EQ_MaxSumdCapUOfz(net,per) $OnNet(net) .. sum(unew $OnAvailUNet(unew,net,per), dCapUOfz(unew,per))  =L=  dCapUAnyMax(per);

# Første periodes kapacitet er identisk med første periodes tilvækst (dvs. eksisterende variabel ny kapacitet er nul før første periode).
#--- EQ_MasFirstPer(unew) $OnUPer(unew,'per1')                      ..  CapU(unew,'per1')  =E=  dCapU(unew,'per1') $OnUPer(unew,'per1');
#--- EQ_MasOtherPer(unew,per) $(ord(per) GE 2 AND OnUPer(unew,per)) ..  CapU(unew,per)     =E=  CapU(unew,per-1) + dCapU(unew,per) $OnUPer(unew,per);


EQ_dCapU(unew,per) $OnUPer(unew,per) ..   dCapU(unew,per)  =E=  CapU(unew,per) - CapU(unew,per-1) $(ord(per) GE 2);


# De to ligninger herunder dæmper komposanterne af stepvektoren dCapUOfz ift. udgangspunktet.
# dCapUMaxPer beregnes forskelligt for de to versioner af stepvektor bounding box:
#  AlfaVersion1: Hvert anlæg har egen grænse for kapac-ændring ift. forrige iteration.
#  AlfaVersion2: Hvert anlæg har egen grænse for kapac-ændring ift. forrige iteration skaleret med gradientkomposantens relative størrelse.

EQ_dCapUOfzMin(unew,per) $(OnUPer(unew,per)) .. dCapUOfz(unew,per)  =G=  - dCapUMaxPer(unew,per);
EQ_dCapUOfzMax(unew,per) $(OnUPer(unew,per)) .. dCapUOfz(unew,per)  =L=  + dCapUMaxPer(unew,per);

#end 

#begin Ligninger på tværs af anlæg (på net- og periode-niveau).
# OBS Hvis eksist. kapacitet overstiger CapUNeedParm, skal EQ_CapUExcess kun være aktiv, når AllowExcessCap == TRUE, ellers bliver mastermodellen infeasible, da CapUExcess er erklæret positiv.

#--- EQ_dCapUSumMin(net,per) $(ord(per) GE 2 AND OnNet(net)) .. sum(unew $OnAvailUNet(unew,net,per), dCapU(unew,per))  =G=  CapUNewMin(net,per);
#--- 
#--- EQ_CapUNewMin(net,per)  $(ord(per) GE 2 AND OnNet(net)) .. CapUNewMin(net,per)   =E=  dCapUNeed(net,per) - dCapUSumOld(net,per) - CapUExcess(net,per-1);
#--- EQ_dCapUNeed(net,per)   $(ord(per) GE 2 AND OnNet(net)) .. dCapUNeed(net,per)    =E=  CapUNeedParm(net,per)   - CapUNeedParm(net,per-1);
#--- EQ_dCapUOldSum(net,per) $(ord(per) GE 2 AND OnNet(net)) .. dCapUSumOld(net,per)  =E=  CapUOldSumParm(net,per) - CapUOldSumParm(net,per-1);

#--- EQ_CapUExcessZero(net,per) $(NOT AllowExcessCap AND OnNet(net)) .. CapUExcess(net,per)  =E=  0.0;
#--- EQ_CapUExcess(net,per)     $(OnNet(net))                        .. CapUExcess(net,per)  =E=  CapUOldSumParm(net,per) + CapUNewSum(net,per) - CapUNeedParm(net,per);


EQ_CapUNewSum(net,per) $OnNet(net)  .. CapUNewSum(net,per)  =E=  sum(unewuq $(OnAvailUNet(unewuq,net,per) and not unewhp(unewuq)), CapU(unewuq,per)) 
                                                               + sum(unewhp $(OnAvailUNet(unewhp,net,per)),                        CapU(unewhp,per) * CapFacN1Res(unewhp));

# Reviderede restriktioner for mindste ny kapacitet, hvor transmissions-kapaciteter inddrages til at dække behovet i hvert net.

#--- Positive variable CapT(tr,net,perA)        'Mindste T-kapacitet allokeret til hvert net';
Positive variable CapT(tr,perA)            'Rådig T-kapacitet';
Positive variable CapTMin(tr,perA)         'Mindste værdi for rådig T-kapacitet';
Positive variable CapAvailU(net,perA)      'Rådig produktions-kapacitet i givet net';
Positive variable CapAvail(net,perA)       'Rådig produktions- og transmissions-kapacitet til behovsdækning i givet net';
Positive variable CapAvailShare(tr,perA)   'Rådig transmissions-kapacitet for import';
Positive variable CapTImport(netT,perA)    'Importkapacitet til rådighed for net';
Positive variable CapTExport(netF,perA)    'Eksportkapacitet forpligtet af net';
                                           
Equation EQ_CapAvailU(net,perA)            'Beregner CapAvailU';
Equation EQ_CapAvail(net,perA)             'Beregner CapAvail';
Equation EQ_CapAvailMin(net,perA)          'Mindste samlet behov for CapAvail';
Equation EQ_CapTImport(netT,perA)          'Beregner CapTImport';
Equation EQ_CapTExport(netF,perA)          'Beregner CapTExport';
#--- Equation EQ_CapTBalance(tr,perA)           'Balance på transmissionskapaciteter';
Equation EQ_CapAvailShare(tr,perA)         'Rådig transmissions-kapacitet til import';
Equation EQ_CapTMin1(tr,perA)              '';
Equation EQ_CapTMin2(tr,perA)              '';
Equation EQ_CapTMin3(tr,perA)              '';
Equation EQ_CapTMin4(tr,perA)              '';
Equation EQ_dminSum(tr,perA)               '';
Equation EQ_CapTMin(tr,perA)               'Nedre grænse for tildeling af T-importkapacitet';
Equation EQ_CapTMax(tr,perA)               'Øvre grænse for tildeling af T-importkapacitet';
Equation EQ_CapUExcess(net,perA)           'Overflødig kapacitet i given periode';
Equation EQ_CapUExcessZero(net,perA)       'Ingen overflødig kapacitet tilladt';

# OBS : Forbrugsnettene (netHo, netSt) er garanteret en transmissionseffekt givet ved CapT, som skal kunne leveres samtidigt (her: fra netMa).
#       Derfor er det ikke nok at have kapacitet til netop at levere forskellen mellem de forsynede nets behov og egenkapacitet.

EQ_CapAvailU(net,per)   $OnNetPer(net,per) ..  CapAvailU(net,per)  =E=  CapUOldSumParm(net,per) + CapUNewSum(net,per);
EQ_CapAvail(net,per)    $OnNetPer(net,per) ..  CapAvail(net,per)   =E=  CapAvailU(net,per) + CapTImport(net,per) - CapTExport(net,per);
EQ_CapAvailMin(net,per) $OnNetPer(net,per) ..  CapAvail(net,per)   =G=  CapUNeedParm(net,per);

EQ_CapTImport(netT,per) $OnNetPer(netT,per) .. CapTImport(netT,per)  =E=  sum(tr2net(tr,netT) $OnTransPer(tr,per), CapT(tr,per));
EQ_CapTExport(netF,per) $OnNetPer(netF,per) .. CapTExport(netF,per)  =E=  sum(net2tr(netF,tr) $OnTransPer(tr,per), CapT(tr,per));

# OBS CapT er indtil videre låst til aktuelle T-kapaciteter, idet modellen ikke kan investere i T-ledninger.

# Beregning af mindsteværdien af CapAvailShare og DataTransm.
set idmin 'Bruges til beregning af CapTMin' / CapU, CapT /;
Binary variable dmin(tr,perA,idmin) 'Angiver 0/1 om første eller andet arg til min er mindst';
EQ_CapTMin1(tr,per) .. CapTMin(tr,per)  =L=  CapAvailShare(tr,per)  $OnTransPer(tr,per); 
EQ_CapTMin2(tr,per) .. CapTMin(tr,per)  =L=  DataTransm(tr,'QTmax') $OnTransPer(tr,per);
EQ_CapTMin3(tr,per) .. CapTMin(tr,per)  =G=  [CapAvailShare(tr,per)  - (CapAvailShareMaxParm(tr,per) - 0) * (1 - dmin(tr,per,'capu'))] $OnTransPer(tr,per);
EQ_CapTMin4(tr,per) .. CapTMin(tr,per)  =G=  [DataTransm(tr,'QTmax') - (DataTransm(tr,'QTmax')       - 0) * (1 - dmin(tr,per,'capt'))] $OnTransPer(tr,per);
EQ_dminSum(tr,per) $OnTransPer(tr,per)  .. sum(idmin, dmin(tr,per,idmin))  =E=  1;
#move CapAvailShareMaxParm(tr,per) = sum(net2tr(netF,tr), OwnerShare(tr) * [CapUOldSumParm(netF,per) + CapUNewMaxSumParm(netF,per)] $OnTransPer(tr,per);

EQ_CapAvailShare(tr,per) .. CapAvailShare(tr,per)  =E=  sum(net2tr(netF,tr), OwnerShare(tr) * CapAvailU(netF,per)) $OnTransPer(tr,per);
EQ_CapTMin(tr,per)       .. CapT(tr,per)           =G=  CapTMin(tr,per) $OnTransPer(tr,per); 
EQ_CapTMax(tr,per)       .. CapT(tr,per)           =L=  CapTMin(tr,per) $OnTransPer(tr,per);

#--- EQ_CapTMin(tr,per) ..  CapT(tr,per)  =G=  sum(net2tr(netF,tr), OwnerShare(tr) * CapAvailU(netF,per)) $OnTransPer(tr,per);

EQ_CapUExcess(net,per)     $(OnNet(net))                        .. CapUExcess(net,per)  =E=  CapAvail(net,per) - CapUNeedParm(net,per);
EQ_CapUExcessZero(net,per) $(NOT AllowExcessCap AND OnNet(net)) .. CapUExcess(net,per)  =E=  0.0;


#begin Ugyldige ligninger
#--- EQ_CapAvail(net,per) $OnNetPer(net,per)    ..  CapAvail(net,per)  =E=  CapUOldSumParm(net,per) + CapUNewSum(net,per)
#---                                                                        + sum(tr2net(tr,net) $OnTransPer(tr,per),  CapT(tr,net,per))    # Varmekapacitet som tilføres net fra T-ledninger.
#---                                                                        - sum(net2tr(net,tr) $OnTransPer(tr,per),  CapT(tr,net,per))    # Varmekapacitet som afsendes fra net til T-ledninger.
#---                                                                        ;
#---                                                                        
#--- EQ_CapAvailMin(net,per) $OnNetPer(net,per) ..  CapAvail(net,per)  =G=  CapUNeedParm(net,per);
#--- 
#---                                                                   #--- - CapUNewSum(net,per) - CapUOldSumParm(net,per)        # Mindste kapac-behov i net fratrukket lokal kapacitet.
#---                                                                   #--- - sum(tr2net(tr,net) $OnTransPer(tr,per),        CapT(tr,net,per))           # Garanteret varmetrans-kapacitet fra andre net 
#---                                                                   #--- + sum(net2tr(net,tr) $OnTransPer(tr,per),        CapT(tr,net,per))           # Garanteret varmetrans-kapacitet til andre net.
#---                                                                   #--- - sum(netT $(net2net(net,netT) AND OnNet(netT)), CapUOldSumParm(netT,per))   # Eksist. kapac i netT, som forsynes fra net.
#---                                                ;
#--- 
#--- # OBS CapT er indtil videre låst til aktuelle T-kapaciteter, idet modellen ikke kan investere i T-ledninger.
#--- EQ_CapTBalance(tr,per) $OnTransPer(tr,per) ..  sum(net $tr2net(tr,net), CapT(tr,net,per))  =E=  sum(net $net2tr(net,tr), CapT(tr,net,per));
#--- EQ_CapTMin(tr,per)     $OnTransPer(tr,per) ..  sum(net $tr2net(tr,net), CapT(tr,net,per))  =G=  DataTransm(tr,'QTmax');
#--- EQ_CapTMax(tr,per)     $OnTransPer(tr,per) ..  sum(net $tr2net(tr,net), CapT(tr,net,per))  =L=  DataTransm(tr,'QTmax');
#--- 
#--- EQ_CapUExcessZero(net,per) $(NOT AllowExcessCap AND OnNet(net)) .. CapUExcess(net,per)  =E=  0.0;
#--- EQ_CapUExcess(net,per)     $(OnNet(net))                        .. CapUExcess(net,per)  =E=  CapAvail(net,per) - CapUNeedParm(net,per);
#end Ugyldige ligninger


#end                                                             

#begin Ligninger for transmissionsledninger

#--- SOS1 variable bOnInvT(tr,per) 'Investeringstidpunkt 1-af-N';
#--- 
#--- equations
#---   EQ_bOnInvT(tr,perA)
#---   EQ_CapTMin(tr)    
#---   EQ_CapTMax(tr)    
#---   EQ_dCapT(tr,perA)  
#---   EQ_CapT(tr,perA)   
#--- ;
#--- 
#--- EQ_bOnInvT(tr,per) $OnTrans(tr) ..  sum(per, bOnInvT(tr,per))  =L=  1.0;
#--- EQ_CapTMin(tr)     $OnTrans(tr) ..  CapT(tr)      =G=  CapTMin(tr) * bOnInvT(tr,per);
#--- EQ_CapTMax(tr)     $OnTrans(tr) ..  CapT(tr)      =L=  CapTMax(tr) * bOnInvT(tr,per);
#--- EQ_dCapT(tr,per)   $OnTrans(tr) ..  dCapT(tr,per) =L=  dCapTMax(tr,per) * bOnInvT(tr,per);
#--- EQ_CapT(tr,per)    $OnTrans(tr) ..  CapT(tr,per)  =E=  CapT(tr,per-1) + dCapT(tr,per);
#--- 
#--- #--- EQ_CapT(tr,per) $(OnTrans(tr) AND ord(per) GE 2) .. CapT(tr,per)  =E=  CapT(tr,per-1) + dCapT(tr,per);
#--- 
#--- Parameter Capex0T 'Initial invest. i T-ledning [DKK/m]';
#--- GradCapT(tr,'capex0') = Capex0T * L(tr);
#--- GradCapT(tr,'capex1') = Capex1T * L(tr) * 18.3 * DNmm(t);
#--- 
#--- EQ_CapCostT(per)   .. dCapCostT(per) =E= sum(tr $OnTrans(tr), CapT(tr,per) * GradCapT(tr,per,'capex1') + GradCapT(tr,'capex0') * sum(per, bOnInvT(tr,per)));
#--- 
#--- #--------- GradUMarg(unew,actPer) = PeriodObjScale * sum(uq $sameas(unew,uq), sum(t, EQ_QProdUmax.m(t,uq) * bOn.L(t,uq)));
#--- 
#--- GradMargT(tr,per)     = PeriodObjScale * sum(tr, sum(t, EQ_QTmax.m(t,tr) * bOnT(t,tr)));
#--- GradMargAggrT(tr,per) = sum(perAlias $(ord(perAlias) GE ord(per) AND ord(perAlias) LE PeriodLast), GradMargT(tr,perAlias));
#--- EQ_MargObjT(per)   .. dMargObjT(per) =E= sum(tr, dCapT(tr,per) * GradMargAggrT(tr,per));
#--- 
#--- 
#--------- GradUMargAggr(unew,per)          = sum(perAlias $(ord(perAlias) GE ord(per) AND ord(perAlias) LE PeriodLast), GradUMarg(unew,perAlias));
#--------- GradUAggr(unew,per)              = GradUMargAggr(unew,per) - GradCapU(unew,per);
#--------- GradUMargAggrIter(unew,per,iter) = GradUMargAggr(unew,per);
#--------- GradUAggrIter(unew,per,iter)     = GradUAggr(unew,per);

#end 

$OnOrder

#end Master equation spec

#begin Master model declaration

# Master model
model modelMaster / 
      EQ_MasObj                      ,   # Master objektfunktion.
      EQ_MasPenaltyCost              ,   # Beregner penalty for overflødig kapactet.
      EQ_CapUCost                    ,   # Kapac-omkostn. ved mer-kapacitet.
      EQ_MargObjU                    ,   # Mer-DB ved aggreg. mer-kapacitet på anlæg.
      EQ_dCapUOfzAggr                ,   # Aggreg. mer-kapaciteter fra og med given periode.
      EQ_dCapUOfz                    ,   # Beregner kapac-ændring ift. periode-optim..
      EQ_CapUMonotony                ,   # Monotont stigende kapaciteter.
      EQ_CapUMin                     ,   # Mindste kapacitet.
      EQ_CapUMax                     ,   # Største kapacitet.
      EQ_dCapU                       ,   # Relation mellem kapacitet og tilvækst.
      EQ_dCapUOfzMin                 ,   # Nedre grænse for ændringens størrelse ift. forrige iteration.
      EQ_dCapUOfzMax                 ,   # Øvre  grænse for ændringens størrelse ift. forrige iteration.
      EQ_CapUNewSum                  ,   # Beregner ny kapacitet kapacitet.
      EQ_Capex0                      ,   # Sum af capex0 for unew over planhorisonten.
      EQ_dCapUMin                    ,   # Nedre grænse på merinvestering ift. forrige periode.
      EQ_dCapUMax                    ,   # Øvre grænse på merinvestering ift. forrige periode.
      EQ_NProjNet                    ,   # Antal projekter på net-niveau over planhorisonten.
      EQ_NProjU                      ,   # Antal projekter på anlægs-niveau over planhorisonten.
      EQ_MaxProjNet                  ,   # Aktiverer loft på antal projekter på net-niveau.
      EQ_MaxProjU                    ,   # Aktiverer loft på antal projekter på anlægs-niveau.
      EQ_MinProjSeqU                 ,   # Højst eet anlægsprojekt i givet antal perioder.
      EQ_CapAvailU                   ,   # Beregner CapAvailU.
      EQ_CapAvail                    ,   # Beregner CapAvail.
      EQ_CapAvailMin                 ,   # Mindste samlet behov for CapAvail.
      EQ_CapTImport                  ,   # Beregner CapTImport.
      EQ_CapTExport                  ,   # Beregner CapTExport.
      EQ_CapAvailShare               ,   # Rådig transmissions-kapacitet til import.
      EQ_CapTMin1                    ,   # '';
      EQ_CapTMin2                    ,   # '';
      EQ_CapTMin3                    ,   # '';
      EQ_CapTMin4                    ,   # '';
      EQ_dminSum                     ,   # '';
      EQ_CapTMin                     ,   # Nedre grænse for tildeling af T-importkapacitet.
      EQ_CapTMax                     ,   # Øvre grænse for tildeling af T-importkapacitet.
      EQ_CapUExcess                  ,   # Overflødig kapacitet i given periode.
      EQ_CapUExcessZero                  # Ingen overflødig kapacitet tilladt.
      /;

#end   Master model declaration

$If not errorfree $exit
#)