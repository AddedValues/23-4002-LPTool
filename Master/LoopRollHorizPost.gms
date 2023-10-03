$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        LoopRollHorizPost.gms
Scope:          Afsluttende del af rolling horizon optimeringsloop
Inkluderes af:  MecLpMain.gms
Argumenter:     <endnu ikke defineret>

$OffText

# OBS Denne beregning af slave objective afgrænset til steplængden af den rullende horisont skal være ækvivalent til beregning af zSlave.
  
tRH(tt) = ord(tt) GE TimeBegin AND ord(tt) LE (TimeBegin - 1 + LenRHStep);
if (ord(rhStep) EQ nRHstep+1,
  tRH(tt) = ord(tt) GE TimeBegin AND ord(tt) LE DurationPeriod;
);

# OBS ObjectiveRH stmt skal afspejle slave-objective, blot afgrænset til den aktuelle rullende horisont.

ObjectiveRH(rhStep) = ( sum (tRH,
                             + QSales.L(tRH)
                         + sum (tr  $OnTrans(tr),  -CostPump.L(tRH,tr))
                         + sum (u   $OnU(tRH,u),   -TotalCostU.L(tRH,u) )
                         + sum (kv  $OnU(tRH,kv),  +TotalElIncome.L(tRH,kv))
                         + sum (net $OnNet(net),   -CostInfeas.L(tRH,net))
                         + sum (net $OnNet(net),   -CostSrPenalty.L(tRH,net))
                        )
                      ) / PeriodObjScale;      # Total cost in DKK.

ObjectiveRHreal(rhStep) = ObjectiveRH(rhStep) + sum(net $OnNet(net), sum(tRH, [CostInfeas.L(tRH, net) + CostSrPenalty.L(tRH,net)])) / PeriodObjScale;

# Opsamling af solver statistik.
StatsRH(topicSolver,actRHstep) = StatsSolver(topicSolver);

# Markér om marginaler er produceret af solveren eller ej.
HasMarginalsRH(actRHstep) = TRUE;

# DONE Eksistens-check af marginaler skal aktiveres, når de tilhørende kapacitetsrestriktioner er identificeret / navngivet.
# GAMS har en funktion mapVal(x), som leverer en integer-kode for typen af x (se:  https://www.gams.com/latest/docs/UG_Parameters.html#UG_Parameters_mapval )

loop (unew $OnUGlobal(unew),
  loop (upr $sameas(unew,upr),
    actUpr(upr) = yes;
    tmp = sum(t, 1.0 $(mapVal(EQ_QProdUmax.m(t,upr)) EQ NAN));
    HasMarginalsRH(actRHstep) = HasMarginalsRH(actRHstep) AND (tmp EQ 0);
    if (tmp GT 0.0, display "MANGLER MARGINALER for anlæg actUpr:", actUpr; );
  );
);

if (NOT HasMarginalsRH(actRHstep), 
  display actRHstep;
  display "OBS: MANGLER MARGINALER I AKTUEL ROLLING HORIZON. UDSKRIVER MEC --- Failed ---.gdx";
  execute_unload "MEC --- Failed ---.gdx";
  #--- abort "MANGLER MARGINALER: Se "MEC --- Failed ---.gdx";
);
display actRHstep; 
  
);  # End of rolling horizon loop.

display HasMarginalsRH;

# Beregn samlet objective henover rolling horizon
ObjSumRH     = sum(rhStep, ObjectiveRH(rhstep));
ObjSumRHreal = sum(rhStep, ObjectiveRHreal(rhstep));


# Beregn totale emission af CO2.
TotalSumCO2Emis(net,co2kind) =  sum(tt $(ord(tt) LE DurationPeriod), TotalCO2Emis.L(tt,net,co2kind));


*begin Beregn marginaler for kapacitetsallokeringer til elmarkeder

# Tolkning af equation marginaler:
#   Generelt angiver en equation marginal, hvad objektfunktionen (her: gevinsten) vil stige, hvis højresiden øges med 1 enhed, alt andet lige.
#   GradUCapE er marginalerne for hver time i driftsdøgnet (hvortil buddene er givet).
#   GradUCapE beregnes med fortegn således, at den angiver gevinsten for en øgning af CapEAlloc med 1 enhed.

# CapEU er den øjeblikkelige max. kapacitet: PowInUMax / COP for elforbrugende anlæg, og Pnet(t) for elproducerende anlæg
#--- EQ_CapEAllocConsUp(t,uelcons)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'up'))   .. PowInU(t,uelcons)                        =G=  BLen(t) * CapEAlloc(t,uelcons,'up');
#--- EQ_CapEAllocConsDown(t,uelcons) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'down')) .. PowInU(t,uelcons)                        =L=  BLen(t) * (CapEU(t,uelcons) - CapEAlloc(t,uelcons,'down'));
#--- EQ_CapEAllocProdUp(t,uelprod)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'up'))   .. sum(kv $sameas(kv,uelprod), Pnet(t,kv))  =L=  BLen(t) * (CapEU(t,uelprod) - CapEAlloc(t,uelprod,'up'));
#--- EQ_CapEAllocProdDown(t,uelprod) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'down')) .. sum(kv $sameas(kv,uelprod), Pnet(t,kv))  =G=  BLen(t) * CapEAlloc(t,uelprod,'down');

GradUCapE(tbid,uelcons,'up')   $OnUGlobal(uelcons) = + sum(tt2tbid(tt,tbid), EQ_CapEAllocConsUp.m(tt,uelcons));
GradUCapE(tbid,uelcons,'down') $OnUGlobal(uelcons) = - sum(tt2tbid(tt,tbid), EQ_CapEAllocConsDown.m(tt,uelcons));
GradUCapE(tbid,uelprod,'up')   $OnUGlobal(uelprod) = - sum(tt2tbid(tt,tbid), EQ_CapEAllocProdUp.m(tt,uelprod));
GradUCapE(tbid,uelprod,'down') $OnUGlobal(uelprod) = + sum(tt2tbid(tt,tbid), EQ_CapEAllocProdDown.m(tt,uelprod));

GradUCapESumU(tbid,updown) = sum(uelec $OnUGlobal(uelec), GradUCapE(tbid,uelec,updown));
GradUCapETotal(updown)     = sum(tbid, GradUCapESumU(tbid,updown));

*end 

