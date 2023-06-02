$log Entering file: %system.incName%
#(
$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        DeclareMasterStats.gms
Scope:          Erklærer parms for statistik for master forløb.
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText

Singleton set optIter(iter) 'Optimale master-iteration' / system.empty /;

Scalar    TimeOfWritingMasterResults       'Tidspunkt for sammenfatning af master results';  # Tidspunkt som serial day number.
Scalar    IterLast                         'Seneste master iteration';
Scalar    IterOptim                        'Hidtil bedste master iteration';
Scalar    AlfaOptim                        'Alfa (stepmax) i optimum';
Scalar    NPVOptim                         'NPV i optimum';
Scalar    MasObjOptimAbs                   'MaxObj i optimum';
Scalar    MasObjOptimRel                   'MaxObj / NPV i optimum';
Scalar    ConvergenceCodeOptim             'ConvergenceCode i optimum';

Scalar    RowCountOvwPer       'Antal records i StatsMasOvwPer';
Scalar    RowCountOvwNet       'Antal records i StatsMasOvwNet';
Scalar    RowCountOvwU         'Antal records i StatsMasOvwU';
Scalar    RowCountOvwUnew      'Antal records i StatsMasOvwUnew';
Scalar    RowCountOvwUnewIter  'Antal records i StatsMasOvwUnewIter';
Scalar    RowCountOvwTax       'Antal records i StatsMasOvwTax';
Scalar    RowCountOvwT         'Antal records i StatsMasOvwT';
Scalar    RowCountOvwFuel      'Antal records i StatsMasOvwFuel';

Parameter StatsMasOvwPer(perA,topicMasOvwPer)          'Master overview stats for period aggregates';
Parameter StatsMasOvwNet(perA,topicMasOvwNet,net)      'Master overview stats for nets';
Parameter StatsMasOvwU(perA,topicMasOvwU,u)            'Master overview stats for units';
Parameter StatsMasOvwUNew(perA,topicMasOvwUNew,unew)   'Master overview stats for new units';
Parameter StatsMasOvwTax(perA,tax,upr)                 'Master overview stats for taxes';
Parameter StatsMasOvwT(perA,topicMasOvwT,tr)           'Master overview stats for T-lines';
Parameter StatsMasOvwFuel(perA,topicMasOvwFuel,f)      'Master overview stats for fuels';
Parameter StatsMasOvwUnewIter(perA,iter,topicMasOvwUNew,unew)   'Master overview stats for new units';

Parameter CapUOptim(u,perA)                 'Varmeprod.kapacitet';
Parameter dCapUOptim(u,perA)               'Varmeprod. merkapacitet ift. forrige periode';
Parameter NProjNetOptim(net,perA)          'Antal nye anlægsprojekter pr. net';
Parameter NProjUOptim(unew,perA)           'Antal nye anlægsprojekter pr. unew';
Parameter FLHOptim(u,perA)                 'Fuldlasttimer i optimum';
Parameter OperHoursOptim(u,perA)           'Driftstimer i optimum';
Parameter PowInUOptim(u,perA)              'Brændselsenergi i optimum';
Parameter FuelQtysOptim(u,perA)            'Brændselsmængder i optimum';
Parameter CO2QtyPhysOptim(u,perA)          'Fysiske CO2-mængder i optimum';
Parameter CO2QtyRegulOptim(u,perA)         'Regulatoriske CO2-mængder i optimum';
Parameter CapUCostOptim(u,perA)            'Samlet CAPEX i optimum';
Parameter MargObjOptim(perA)               'Drifts netto-omk. i optimum';

Parameter HeatGenUOptim(u,perA)            'Varmeproduktion i optimum';
Parameter HeatGenNewOptim(perA)            'Varmeproduktion for nye anlæg i optimum';
Parameter HeatGenAllOptim(perA)            'Varmeproduktion for alle anlæg i optimum';

Parameter HeatMargCostUOptim(u,perA)        'Effektiv enhedsvarmeproduktionsomkostning i optimum';
Parameter HeatCapCostUOptim(u,perA)         'Effektiv enhedsvarmeproduktionsomkostning i optimum';
Parameter HeatCostUOptim(u,perA)           'Effektiv enhedsvarmeproduktionsomkostning i optimum';

Parameter HeatMargCostNewOptim(perA)       'Marginal andel af enhedsvarmeproduktionsomkostning over nye anlæg i optimum';
Parameter HeatCapCostNewOptim(perA)        'Kapac-andel af enhedsvarmeproduktionsomkostning over nye anlæg i optimum';

Parameter HeatMargCostAllOptim(perA)       'Marginal andel af enhedsvarmeproduktionsomkostning over alle anlæg i optimum';
Parameter HeatCapCostAllOptim(perA)        'Kapac-andel af enhedsvarmeproduktionsomkostning over alle anlæg i optimum';

Parameter HeatCostNewOptim(perA)           'Effektiv enhedsvarmeproduktionsomkostning over nye anlæg i optimum';
Parameter HeatCostAllOptim(perA)           'Effektiv enhedsvarmeproduktionsomkostning over alle anlæg i optimum';

Parameter HeatVentedOptim(perA)            'Bortkølet varme i optimum';
Parameter HeatSentOptim(perA)              'Transmitteret varme i optimum';

Parameter TaxProdUOptim(perA,tax,upr)      'Afgifter over alle anlæg i optimum';

Parameter TotalDbElWindOptim(perA)         'Totalindtægt på el fra vindmøller';
Parameter TotalPWindHPOptim(perA)          'Total mængde el fra vindmøller til varmepumpe';
Parameter TotalPWindActualOptim(perA)      'Total mængde el fra vindmøller';
Parameter CO2QtyFuelOptim(co2kind,f,perA)  'Sum af CO2-emission [ton] for hvert drivmiddel i optimum';

Parameter NPVIterCopy(iter)                'Kopi af NPVIter med nul i iter1';
Parameter FLHIter(u,perA,iter)             'Fuldlasttimer';
Parameter OperHoursIter(u,perA,iter)       'Driftstimer';
Parameter PowInUIter(u,perA,iter)          'Brændsels-energi MWh';
Parameter FuelQtysIter(u,perA,iter)        'Brændselsmængder';
Parameter CO2QtyPhysIter(u,perA,iter)      'Fysiske CO2-mængder';
Parameter CO2QtyRegulIter(u,perA,iter)     'Regulatoriske CO2-mængder';
Parameter PowerOptim(u,perA)               'El-nettoproduktion i optimum';
Parameter ElEgbrugOptim(u,perA)            'El-egetforbrug i optimum';
Parameter PowerUIter(u,perA,iter)          'El-nettoproduktion';
Parameter PowerGenUIter(u,perA,iter)       'El-produktion';
Parameter HeatGenUIter(u,perA,iter)        'Varmeproduktion';
Parameter HeatGenNewIter(perA,iter)        'Varmeproduktion alle nye anlæg';
Parameter HeatGenAllIter(perA,iter)        'Varmeproduktion alle anlæg';
Parameter HeatMargCostUIter(u,perA,iter)   'Marginal andel af varmeproduktionspris DKK/MWhq';
Parameter HeatCapCostUIter(u,perA,iter)    'Kapac-andel af varmeproduktionspris DKK/MWhq';
Parameter HeatCostUIter(u,perA,iter)       'Effektiv enhedsvarmeproduktionsomkostning hvert anlæg';
Parameter HeatCapCostNewIter(perA,iter)    'Kapac-andel af Varmeproduktionsomkostning for nye anlæg';
Parameter HeatMargCostNewIter(perA,iter)   'Marginal andel af  Varmeproduktionsomkostning for nye anlæg';
Parameter HeatCostNewIter(perA,iter)       'Varmeproduktionsomkostning for nye anlæg';
Parameter HeatCapCostAllIter(perA,iter)    'Kapac-andel af Effektiv enhedsvarmeproduktionsomkostning alle anlæg';
Parameter HeatMargCostAllIter(perA,iter)   'Marginal andel af Effektiv enhedsvarmeproduktionsomkostning alle anlæg';
Parameter HeatCostAllIter(perA,iter)       'Effektiv enhedsvarmeproduktionsomkostning alle anlæg';
Parameter HeatVentedIter(perA,iter)        'Bortkølet varme';
Parameter HeatSentIter(tr,perA,iter)       'Transmitteret (afsendt) varme';
Parameter HeatLostIter(tr,perA,iter)       'Varmetab i transmission';
Parameter CostPumpIter(tr,perA,iter)       'Pumpeomkostninger i transmission';

Parameter CO2QtyFuelPerIter(co2kind,f,perA,iter)  'CO2-emission [ton] for hvert drivmiddel';

Scalar HeatAll, CostAll, CapCostAll, MargCostAll;

#)