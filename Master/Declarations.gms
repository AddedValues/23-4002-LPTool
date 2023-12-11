$log Entering file: %system.incName%


*begin GLOBALE PARAMETRE

#--- Scalar tbeg;  # Bruges til ordinal for begyndelsestidspunkt.
#--- Scalar tend;  # Bruges til ordinal for sluttidspunkt.
Scalar QeInfeasMax        'Øvre grænse for varme-infeasibility (source/drain) [MWq]';
Scalar ElspotYear         'Elspot årsprofil anvendt';
Scalar QDemandYear        'FJV årsprofil anvendt';
Scalar ActualMasterScen   'Nr. på aktuel masterscenarie indlæst fra arket ScenMaster';
Scalar DumpPeriodsToGdx   'Switch for dump af perioderesultater til gdx'           / 0 /;  # 0 = None, 1=Full, 2=SlaveOnly
Scalar DoDumpPeriodsToGdx 'Angiver at perioderesultater blev udskrevet til gdx';
Scalar UseRawSlaveObj     'Switch for brug af objective slave uden tilbageførsel af penalties'  / 1 /;

Scalar    LenRHhoriz, LenRHstep, LenRHoverhang, CountRollHorizon, nRHstep, RatioRHLenToStep, LenResidRHstep, LenPureRHstep, tbegin, tend, tendstep, tendhoriz;
Scalar    LenRHhorizSave, LenRHstepSave;
Parameter RHIntv(rhStep,beginend);
Parameter StatsAll(topicAll); 
Parameter StatsRH(topicSolver,rhStep);
Parameter ObjectiveRH(rhStep);
Parameter ObjectiveRHreal(rhStep) 'Objective renset for infeasibility costs';
Scalar    ObjSumRH;
Scalar    ObjSumRHreal;

# Tidsekspansion (kort planperiode)
Parameter TimestampStart           'Starttidspunkt for planperioden ÅÅÅÅMMDDHH (integer)';
Parameter TimeResolution(planZone) 'Tidsopløsning for hver planlægningszone';
Parameter TimeScale(planZone)      'Tidsskala 60 min / TimeResolution';
Parameter TimeScaleInv(planZone)   '1 / TimeScale';


# OnTimeAggr:  =  0 : Ingen tidsaggregering
#              =  N : Tidsaggregering med aggr<N> på sheet TidsAggr (parameter TimeBlocks). Resultater foreligger kun i aggregeret form.
#              = -N : Som ved =N, men med udfoldning til fuldt tidsdomæne inkl. ekstra kørsel med låste binære variable. Resultater foreligger i fuldt tidsdomæne.

Scalar OnTimeAggr       'Angiver nr. på tidsaggr. skema, 0 = ingen aggr.' / 0 /;   #TimeAggr
Scalar AggrKind         'Angiver om aggr. er årshængig (0/1)'             / 0 /;   #TimeAggr
# REMOVE Scalar UseFullYear      'Angiver 0/1 om optimering omfatter hele kalenderår';

Scalar UseTimeAggr                   'Angiver 0/1 om tidsaggregering er aktiv';
Scalar    UseTimeExpansionAny        'Angiver 0/1 om tidsekspansion er aktivt';
Parameter UseTimeExpansion(planZone) 'Angiver 0/1 om tidsaggregering er aktiv';

Scalar    ordtt                      'Index af aktuelt medlem af tt';
Scalar    BLenMax                    'Største bloklængde i perioden';
Scalar    Nblock                     'Antal tidsblokke for helt år';
Scalar    NblockAggr                 'Antal tidsblokke for helt år før deaggregering' / 0 /;
Scalar    NblockActual               'Antal tidsblokke i aktuel periode';
Parameter Bbeg(tt)                   'Modeltime tt (60 min) for blokke på timebasis';
Parameter Bend(tt)                   'Modeltime tt (60 min) for blokke på timebasis';
Parameter BLen(tt)                   'Antal tidspunkter t i blokke (brøk ifm. tidsekspansion)';
Parameter BLenRatio(tt)              'Forholdet BLen(tt) / BLen(tt-1)';                           
Parameter IsBidDay(tt)               'Angiver 0/1 at tidspunkt ligger i buddøgnet';
Parameter TimeResol(tt)              'Tidsopløsning [min] for hvert modeltidspunkt';
Parameter TimeVector(tt)             'Tidspunkter akkumuleret [min] for hvert modeltidspunkt (start=0)';
Parameter NblockHour(planZone)       'Antal tidsblokke i en time';


*end   GLOBALE PARAMETRE

Parameter Scenarios(lblScenMas, scmas)  'Masterscenarier';
Parameter ScenYear(lblScenYear)         'Årsscenarier';
Parameter ActScen(lblScenMas)           'Aktuelt masterscenarie';
Parameter ZeroScenMembers(lblScenMas)   'Scenarie elementer == 0';

Parameter TimeBlocks(tt,aggr)          'Tidsblokkes starttime';     

Scalar    InterestRate                 'Kalkulationsrente procent p.a.';
Scalar    InflationRate                'Inflationsrate procent p.a.';
                                       
Scalar    NPV                          'Aktuel nutidsværdi';
                                       
#--- Parameter OnAvailUNet(u,net)           'Angiver at givet rådigt anlæg er aktivt i givet net';
                                          
#--- Parameter CapexTrans(tr)               'Afskrivning på T-ledninger [kr/år]';
#--- Parameter CapexPump(tr)                'Afskrivning på pumpestationer [kr/år]';

Scalar    Ntime                        'Antal tidspunkter tt i planperioden';
Scalar    TimeBegin                    'Første tidspunkt tt i aktuelle RH';
Scalar    TimeEnd                      'Sidste tidspunkt tt i aktuelle RH';
Scalar    HourBegin                    'Første årstimetal i planperioden';
Scalar    HourEnd                      'Sidste årstimetal i planperioden';
Scalar    HourBeginBidDay              'Første timetal ord(tt) i driftsdøgnet for budindmelding';
Scalar    HourEndBidDay                'Sidste timetal ord(tt) i driftsdøgnet for budindmelding';
Scalar    HoursBidDay                  'Antal timer i driftsdøgnet for budindmelding'  / 24 /;
Scalar    TimeIndexBeginBidDay         'Index = ord(tt) for første tidspunkt af driftsdøgnet for budindmelding';
Scalar    TimeIndexEndBidDay           'Index = ord(tt) for sidste tidspunkt af driftsdøgnet for budindmelding';

Scalar    nHourMarginals               'Antal timer med rådige marginaler';
Parameter HasMarginalsRH(rhStep)       'Angiver 0/1 om RH har marginaler';
Parameter MarginalsHour(unew)          'Timemiddel af rådige marginaler';


# REMOVE Scalar PeriodFrac                'Relativ timeandel af perioden ift. kalenderåret';
Scalar OnCapacityReservation     'Angiver 0/1 om kapac.reservation skal udføres';
Scalar DurationPeriod            'Antal timer i aktuel periode';

#--- Scalar    RealRente;
#--- Scalar    PmtTransmPipe        'Afskrivningsrate for T-ledning [DKK/år]';
#--- Scalar    PmtTransmPump        'Afskrivningsrate for pumpestationer [DKK/år]';


* Rapportering erklæringer.
Parameter StatsSolver(topicSolver)                      'Model and solve attributes';
Parameter StatsInfeas(tt,net,infeasDir)                 'Infeasiblities Found';
Parameter StatsT(tr,topicT)                             'Transmission topics';
Parameter StatsU(u,topicU)                              'Prod unit topics';
Parameter StatsVak(vak,topicVak)                        'VAK topics';
Parameter StatsTax(upr,tax)                             'Tax topics';
Parameter StatsFuel(f,topicFuel)                        'Fuel topics';
Parameter StatsOther(other,topicOther)                  'Other topics';
#--- Parameter StatsMecU(uall,topicMecU,moyr)                   'Stats på anlægsniveau til brug for MEC økonomi';
Parameter StatsMecF(f,topicMecF)                        'Stats på brændselsniveau til brug for MEC økonomi';
Parameter SalesHeatTotal(net)          'All sales DKK';
Parameter SalesPowerTotal(net)         'All sales DKK';
Parameter CostTotal(net)               'All taxes DKK';
Parameter TaxTotal(net)                'All taxes DKK';
Parameter CostMaintTotal(net)          'All maintenance costs DKK';
Parameter CostStartTotal(net)          'All start-stop costs DKK';
Parameter CostPowerTotal(net)          'All power consumption costs DKK';
Parameter CostFuelTotal(net)           'All fuel consumption costs DKK';
Parameter CostCO2EtsTotal(net)         'All CO2 ETS costs DKK';
Parameter TaxEnrTotal(net)             'Energi afgift DKK';
Parameter TaxCO2Total(net)             'CO2 afgift DKK';
Parameter TaxNOxTotal(net)             'NOx afgift DKK';
Parameter TaxSOxTotal(net)             'SOx afgift DKK';
Parameter SubsidiesTotal(net)          'All subsidies DKK';
Parameter InfeasTotal(net,InfeasDir)   'All heat compensation by virtual drain/source [MWh]';
Parameter CostTransTotal               'Transmission costs';
Parameter zNormalized                  'Slave objective in DKK';
Parameter zNormalizedReal              'Slave objective minus infeasibility costs DKK';
Parameter OperHours(u)                 'Annual operating hours prod.unit';
Parameter QMargPrice(u)                'Average marginal unit heat price [DKK/MWh]';
Parameter QMargPrice_Hourly(tt,u);

Scalar    iblock, ActualBlockLen, ElspotSum, GasPriceSum, TariffDsoLoadSum, TariffEigenPumpSum; 
Parameter QDemSum(net)                 'Mellemregning ifm tidsaggregering';
Parameter dQExtSum(produExtR)          'Mellemregning ifm tidsaggregering';
Parameter QfOVmax(tt,uov)              'Maxlast for overskudsvarme (MWqov)';
Parameter QfOVmaxSum(uov)              'Mellemregning ifm tidsaggregering';
Parameter TariffElecUSum(u)            'Mellemregning ifm tidsaggregering';
Parameter TariffEigenUSum(u)           'Mellemregning ifm tidsaggregering';
Parameter OnUSum(u)                    'Mellemregning ifm tidsaggregering';
Parameter CopSum(hp)                   'Mellemregning ifm tidsaggregering';
Parameter QhpYieldSum(hp)              'Mellemregning ifm tidsaggregering';
Parameter alphaTSum(tr,trkind)         'Mellemregning ifm tidsaggregering';

Scalar    DurationRH                   'Antal timer i actuel RH';
Scalar    nHourMarginals               'Antal timer med rådige marginaler';
Parameter HasMarginalsRH(rhStep)       'Angiver 0/1 om RH har marginaler';
Parameter MarginalsHour(unew)          'Timemiddel af rådige marginaler';
       

# Start og stop indikatorer (beregnes efter solve af modelSlave).
Parameter bStartStop(tt,u,startstop)  'Angiver om start hhv. stop er on';

Scalar QInfeasPenalty   'DKK/MWq'  / 15000.0 /;  # Penalty på forbrug af virtuel varme kilde-dræn.
Scalar RewardWaste      'Belønning for at afbrænde affald DKK/kg'  / +0.100 /;  # Skal sikre at mest muligt affald afbrændes indenfor den rådige tonnage.
Scalar CapESlackPenalty 'DKK/MWe'  /  5000.0 /;  # Penalty på CapESlack.
Scalar QSrPenalty       'DKK/MWq'  /     0.0 /;  # Penalty på forbrug af spidslastvarme.
#--- Scalar bOnSRPenalty    'DKK/MWq'  / 0.00 /;   # Skal sikre at bOnSR holdes på nul, hvis ingen SR-anlæg er aktive.


Scalar OnOwnerShare              '0/1 for aktivering af ejerandel på grundlastvarmen' / 1 /;
Scalar QDemandOffset             'Offset of nominal heat demand [fraction of annual average]'  / 0.00 /;
Scalar QDemandGain               'Scaling of nominal heat demand [-]'                          / 1.00 /;
Scalar QDemandScaleActual        'Skalafaktor fra DIN-referenceprofiler til MEC';
     
#--- Parameter CO2EmisRef(net,co2kind)              'Ref. for CO2-emission [ton/år]';
#--- Parameter CO2EmisRefPeriod(net,co2kind)        'Ref. for CO2-emission i aktuel periode [ton]';
#--- Parameter CO2EmisLimit(net,co2kind)            'Reduktionsmål i pct af CO2-emission';
#--- Parameter CO2EmisRefShare(rhStep,net,co2kind)  'Ref, for CO2-emission i hver fuldlængde RH [ton]';
#--- Parameter CO2EmisRefShareRH(net,co2kind)       'Ref, for CO2-emission i aktuel fuldlængde RH [ton]';

Parameter Prognoses_hh(tt,lblPrognoses)  'Prognoser på timeniveau';
Parameter Prognoses(tt,lblPrognoses)     'Prognoser på ekspanderet tidsniveau';

#--- Parameter dQExthh(tt,produExtR)     'Effekt tilført af externe produktionsanlæg';

Parameter THeatSource_hh(tt,hpSource)     'VP varmekilde temperaturer [°C]';
Parameter THeatSource(tt,hpSource)        'VP varmekilde temperaturer [°C]';
# REMOVE Parameter QmaxPtx_hh(tt)                  'Max. effekt fra PtX';
Parameter QfOVmax_hh(tt,uov)               'Max. effekt fra OV-leverandører';

Scalar    OnVakStartFix             'Switch for fix af vak niveau i t1 og t1--1'                  / 1 /;
Scalar    OnStartCostSlk            'Switch til deaktivering af startomkostninger på SLK'         / 1 /;
Scalar    OnRampConstraints         '0/1 om rampetider skal respekteres';
Scalar    QfBaseMaxAll              'Max. grundlastvarme som er til rådighed';

Parameter CostHeatProducExt(produExt) 'Købspris for eksterne varmeleverance [DKK/MWhq]';

Parameter DataU(u,lblDataU)         'Data for anlæg';
Parameter DataAff(lblDataAff,uaff)  'Specifikke data for affaldsanlæg';

Parameter LhvMWhPerUnitFuel(f)      'LHV of fuels per unit (used for conversion of quantities)';
Parameter CO2ProdTonMWh(f)          'CO2 production ton/MWh';
Parameter TaxRateMWh(f,tax,m)       'Tax rate per fuel, tax kind and machine kind DKK/MWh';

Parameter TariffFuelMWh(f)              'Fuel buy tariff DKK/MWh';
Parameter TariffElecU_hh(tt,u)          'El-tarif for eldrevne anlæg DKK/MWhe';
Parameter TariffElecU(tt,u)             'El-tarif for eldrevne anlæg DKK/MWhe';
Parameter TariffEigenU_hh(tt,u)         'El-tarif for egetforbrug på hvert anlæg DKK/MWhe';
Parameter TariffEigenU(tt,u)            'El-tarif for egetforbrug på hvert anlæg DKK/MWhe';
Parameter TariffEigenPump_hh(tt)        'El-tarif for pumpestationer DKK/MWe';
Parameter TariffEigenPump(tt)           'El-tarif for pumpestationer DKK/MWe';
Parameter TariffElSellU(u)              'Tariff [DKK/MWh-el] ved salg på hvert anlæg';                                        
Parameter TariffElRaadighedU(u)         'Tariff [DKK/MWh-el] ved egetforbrug af egenproduceret el på hvert anlæg';  
Parameter TariffElEffektU(u)            'Tariff [DKK/MW-el] ved på hvert anlæg';  
Parameter TariffDsoAll(dso,loadDso)     'DSO variable tarifsatser for aktuel periode';
Parameter TariffDso_hh(tt,dso)          'DSO tarif vs. kundetype for hele perioden';
Parameter TariffDsoLoad_hh(tt)          'DSO eltarif lastniveau = ord(loadDso)';
Parameter TariffDsoLoad(tt)             'DSO eltarif lastniveau = ord(loadDso)';
Parameter TariffDsoFeedIn(dso)          'DSO eltarif for indfødning';
Parameter TariffElRaadighed(dso)        'Rådighedstarif';
Parameter TariffElEffekt(dso)           'Effektbetaling';

Parameter FfMax(u)                      'Nominal max. fuel input [MW]';
Parameter CapEU(tt,uelec)               'Time-varying power capacity of electric plants';
Parameter CapQU(u)                      'Heat capacity of plants';
Parameter CapacP(u)                     'Elkapacitet MWe';
Parameter CapacPoverQ(u)                'Elkapacitet ift. varmekapacitet MWe/MWq';
Parameter FixCapUCost(u)                'Fixed capacity costs [DKK/MWq/yr]';
Parameter FixTariffElCost(u)            'Fixed electricity tariff costs [DKK/MWq/yr]';
Parameter FixCapUTotalCost(u)           'Total fixed capacity costs [DKK/MWq/yr]';

Parameter StartCost(u)              'Startomkostning [DKK/start]';
Parameter PnetMin(u)                'Min. net power [MWe]';

Parameter OnNetGlobal(net)          'Global availability of networks';
Parameter OnNet(net)                'Actual availability of networks';
Parameter OnUGlobal(u)              'Nominal global availability of prod units';           # Off-state overrides period availabilities.
Parameter OnUNet(u,net)             'Angiver at et anlæg og dets net er aktivt i aktuelle periode';
Parameter OnURevision(cp)            'Revision permitted 0/1 in actuel period';
Parameter OnU_hh(tt,u)              'Actual availability of prod units på timebasis';
Parameter OnU(tt,u)                 'Actual availability of prod units på aktuel tidsbasis';
Parameter OnT(tt,tr)                'Actual availability of transmission units på aktuel tidsbasis';
Parameter AvailUNet(u,net)          'Indicates upr exists in network';
Parameter OnFuel(f)                 'Indicates fuels referred by plants';
Parameter BothAffAvailable(tt)      'Angiver 0/1, at begge eksist. aff.linjer er til rådighed';

Parameter QDemandPeakNom(net)       'FJV spidsbehov nominelt [MWq]';

Parameter TaxEForm(kv)              '=1 for E-formel, =0 for V-formel';
Parameter OnBypass(kv)              '0/1 rådighed over bypass';
Parameter EtaPU(u)                  'Elvirkningsgrad';
Parameter EtaQU(u)                  'Varmevirkningsgrad';
Parameter EtaTU(u)                  'Totalvirkningsgrad EtaP+EtaQ';
Parameter EtaRGK(u)                 'RGK andel af indfyret effekt';
Parameter FjvPris(Actor,Actor)      'Salgspris fra sælger til køber';
Parameter CopGain(hp)               'Forstærkningsfaktor på VP COP';
Parameter CapFacN1Res(unew)         'VP ydelsesfaktor på kold dag i relation til N-1 reservekap kriterie';
Parameter DeprecExist(u)            'Afskrivning eksisterende anlæg [DKK/yr]';

Parameter TotalSumCO2Emis(net,co2kind)  'Samlet CO2-emission fra alle anlæg';
Parameter Diverse(lblDiverse)           'Parametre som ikke passer ind andre steder';
Parameter DataPtX(lblDataPtX, uptx)     'Egenskaber for modellering af PtX-OV';
Parameter OwnerShare(tr)                'Modtagers ejerandel af T-ledning tr';

Parameter QDemandAnnualAvg(net)         'Annual nominal heat demand average [MW]';
Parameter QDemandAnnualSum(net)         'Total nominal heat demand [MWh/yr]';
Parameter bOnPrevious(upr)              'Plant activity at end of previous rolling horizon step';
Parameter bOnPreviousRH(upr,rhStep)     'Plant activity at end of previous rolling horizon step';
Parameter FfInPrevious(upr)           'Plant activity at end of previous rolling horizon step';
Parameter FinPreviousRH(upr,rhStep)  'Plant activity at end of previous rolling horizon step';
Parameter EvakPrevious(vak)             'Tank level at end of previous rolling horizon step';
Parameter EvakPreviousRH(vak,rhStep)    'Tank level at end of previous rolling horizon step';
                                        
Parameter FuelMix(upr,f)                'Brændselssammensætning for hvert anlæg';     
Parameter FuelPriceU(upr,f)              'Specifik brændselspris for hvert anlæg';
Parameter FuelCode(f)                   'Fuel to Integer code';                          # Indlæses fra arket DataU. NB: FuelCode er uafh. af ordinal position i set fuel.
Parameter OmrCode(net)                  'Område til Integer code';                       # Indlæses fra arket DataU. NB: OmrCode er uafh. af ordinal position i set net.
Parameter DsoCode(net)                  'DSO til Integer code';                          # Indlæses fra arket DataU. NB: DsoCode er uafh. af ordinal position i set dso.
#--- Parameter Solvarme(tt,usol)          'Solvarmeproduktion [MWq]';

Parameter DataHpKind(lblHpCop,hpSource,lblCopYield) 'Karakteristikker vs. VP-type';
Parameter DataHp(hp,lblHpCop,lblCopYield)                'Karakteristikker for hver VP';
Parameter COP_hh(tt,hp);
Parameter COP(tt,hp);
Parameter QhpYield_hh(tt,hp)                             'Ydelsesfaktor ift. nominel kapacitet';
Parameter QhpYield(tt,hp)                                'Ydelsesfaktor ift. nominel kapacitet';
Parameter COPmin(hp)                                     'Mindste COP henover året';
Parameter YieldMin(hp)                                   'Mindste VP ydelse henover året';
#--- Parameter CHP(kv,lblCHP);
Parameter DeprecCost(u)              'Afskrivninger i aktuel periode  for hvert anlæg';
Parameter FinSum(upr)             'Sum af indgivet effekt over en periode';
Parameter CO2emisFuelSum(f,co2kind)  'Sum af CO2-emission pr. drivmiddel [kg]';



*begin Parametre for transmissionsledninger

# Parametre, som er fælles for alle rør og installationer.
scalar H                      'Dybde af rørcentre [m]';
scalar lamG                   'Jordens termiske ledningsevne [W/(K m)]';
scalar lamI                   'Rørisolationens termiske ledningsevne [W/(K m)]';
scalar vmax                   'Max. flowhastighed [m/s]' / 3.5  /;

Parameter RhoW(tr)            'Middel massefylde af vand [kg/m3]';
Parameter DN(tr)              'Rørets nominelle dimension [mm]';
Parameter DiT(tr)             'Rørets indre diameter [m]';
Parameter DyiT(tr,trkind)     'Rørisolationens ydre diameter [m]';
Parameter Roughness           'Ruhed af rørets indre overflade [m]';
Parameter Area(tr)            'Flowareal af T-ledning [m2]';
Parameter VelocMax(tr)        'Max. hastighed i T-ledning [m/s]';
Parameter Tavg(tr)            'Middeltemperatur i T-ledning [°C]';
Parameter QTfMin(tr)          'Minimal effekt ved v = VelocMax [MWq]';
Parameter QTfMax(tr)          'Maksimal effekt ved v = VelocMax [MWq]';
Parameter L(tr)               'T-ledning længde [m]';
Parameter Beta(tr,trkind)     'Faktor for T-ledning varmetab';
Parameter h1(tr,trkind)       'Faktor for varmetab';

parameter TransmConfig(tr,lblTrConfig)  'T-ledning opsætning';
parameter DataTransm(tr,lblDataTransm)  'T-ledning data';
parameter OnTrans(tr)                   'T-lednings aktuelle rådighed';
parameter OnTransGlobal(tr)             'T-lednings nominelle rådighed';
parameter OnTransNet(tr,netF,netT)      '0/1 indikation for rådig T-ledning';
Parameter DirTrans(tr)                  '+/- 1.0 for flowretning ift. nominel retning';

scalar Cpp                    'Heat capacity water [kJ/kg/K]';
scalar veloc                  'Skønnet årsmidlet hastighed i T-ledning [m/s]';
scalar etaPump                'Pumpe virkningsgrad'  / 0.90 /;
scalar InvCostPump            'Investeringsomkostning for pumpestationer [DKK]'  / 1E+6 /;

Parameter RoughRel(tr)        'Relativ ruhed af indre rør [mm/mm]';
Parameter ViscDyn(tr)         'Dynamisk viskositet af vand [Pa s]';
Parameter Wpump(tr)           'Pumpearbejde [MW]';
Parameter dP(tr)              'Trykfald over hele T-ledning [Pa]';
Parameter NPump(tr)           'Antal pumpestationer';
Parameter fD(tr)              'Strømningsmodstandsfaktor';
Parameter Re(tr)              'Reynolds tal for rørstrømning';

parameter kT(tt,tr,trkind)        'Henfaldsfaktor for rørtemperatur';
parameter alphaT_hh(tt,tr,trkind) 'Henfaldsfaktor for varmetab';
parameter alphaT(tt,tr,trkind)    'Henfaldsfaktor for varmetab';
parameter TinletT(tr,trkind)      'Indløbstemperatur i T-ledning [°C]';

# TODO Beregn pumpearbejdet efter solve af SlaveModel.
Parameter PumpWorkT(tr)      'Aposteriori pumpearbejde [MW]';

Parameter Pipedata(pipe);
parameter Pipes(pipe,lblpipe)         'Egenskaber for rådige rør';
Parameter THav_hh(tt);
Parameter THav(tt);

*end

*begin Parametre flyttet fra DeclareSlave.gms

Parameter Brandsel(f,lblBrandsel)         'Brændsels-egenskaber';

#--- # Ekstern varmeproduktion
#--- Parameter dQExt_hh(tt,produExtR)      'Ekstern produktion [MWq]';
#--- Parameter dQExt(tt,produExtR)         'Ekstern produktion [MWq]';

# Grundlastvarmeproduktion
Parameter BaseLoad(tt)                   'Grundlastvarmeproduktion [MWhq]';
Parameter BaseLoadSum                    'Sum af grundlastvarmeproduktion [MWhq]';
Parameter QTransSum                      'Sum af transmitteret varme [MWhq]';
Parameter BaseLoadShare(tt,netq)         'Andel af grundlastvarmeproduktion';
Parameter ViolationOwnerShare(tt, netq)  'Timer hvor ejerandel blev overskredet';
Parameter CountViolationOwnerShare(netq) 'Antal timer hvor ejerandel blev overskredet';
                          
* Raadigheder

Parameter Availability_hh(tt,u)          'Nominel rådighed på timebasis for alle anlæg';
Parameter Revision_hh(tt,cp)             'Nominel revision på timebasis for centrale anlæg';
Parameter RevisionActual(tt,cp)          '0/1: 0 = rådig time, 1 = revisionstime';
Parameter StateU(u,startslut)            'Start- og sluttilstand i planperioden for anlæg'; 
Parameter StateF(upr,fsto,startslut)     'Start- og slutlagerbeholdning i planperioden for anlæg-fuel kombination'; 

# Erklæring af nominelt og aktuelt fjv-behov, elspotpris og brændselspriser

# Normerede FJV-tidsserier
Parameter QSalgspris(net)                'FJV-salgspris [DKK/MWh]';  QSalgspris(net) = 0.0;  #--- 300.00
Parameter YS(lblScenYear)                'Markedspriser, afgifter, tariffer';
Parameter QeDemandActual_hh(tt,net)       'Fjv-behov i forbrugsområder';
Parameter QeDemandActual(tt,net)          'Fjv-behov i forbrugsområder';
Parameter QDemandSum(net)                'Sum af periodens fjv-behov over forbrugsområder';
Parameter QDemandSumRHfull(rhStep,net)   'Sum af fjv-behov indenfor hver fuld RH-længde';
Scalar    QDemandTotal                   'Sum af fjv-behov over alle net og tidspunkter i perioden';
Parameter ElspotActual_hh(tt)            'Actual elspot price';
Parameter ElspotActual(tt)               'Actual elspot price';
Parameter AffAux(uaff)                   'Forhold mlm. varme- og total-virkningsgrad';
#--- Parameter GasPrice_hh(tt)              'Actual gas spot price';
#--- Parameter GasPriceActual(tt)           'Actual gas spot price';
#--- Parameter uCC(cc)                      'Angiver om carbon capture er aktivt i den gældende periode';

# REMOVE Parameter QmaxPtX_hh(tt)        'Max. varmeeffekt leveret fra PtX-anlæg';
# REMOVE Parameter QmaxPtX(tt);
Parameter QfOVmax_hh(tt,uov)              'Max. varmeeffekt leveret fra OV-leverandører';

*begin Parametre til diagnosticering

Parameter QinfeasSum(net,infeasDir)      'Sum af QeInfeas';
Parameter CostInfeasSum(net)             'CostInfeas for hver periode';

*end Parametre til diagnosticering

*end  Parametre flyttet fra DeclareSlave.gms

*begin Kapacitets allokering til el-markeder

Parameter DataResv(tbid,elmarket,lblDataResv)     'Budmelding til elmarkeder (kapacitet, pris)';
Parameter CapEResv(tbid,elmarket,dirResv)         'Kapacitetsreservationer til elmarkeder';
Parameter CapEResvSum(tbid,dirResv)               'Kapacitetsreservationer summeret over elmarkeder';
Parameter CapEAvail(uelec,dirResv)                'Anlæg til rådighed for kapacitetsreservation';
Parameter GainCapE(tbid,elmarket,dirResv)         'Rådighedsbetaling for kapacitetsreservation [DKK]';
Parameter GainCapETotal                           'Samlet rådighedsbetaling [DKK]';
Parameter DataElMarket(lblElMarket,elmarket)      'Elmarkedsegenskaber';
Parameter GradUCapE(tbid,uelec,dirResv)           'Følsomheder for CapE allokeringer';
Parameter GradUCapESumU(tbid,dirResv)             'Sum af GradUCapE over uelec for hver budtime';
Parameter GradUCapETotal(dirResv)                 'Sum af GradUCapESumU over buddøgnet';

*end Kapacitets allokering til el-markeder
