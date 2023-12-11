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

);  # End of rolling horizon loop.


# Beregn samlet objective henover rolling horizon
ObjSumRH     = sum(rhStep, ObjectiveRH(rhstep));
ObjSumRHreal = sum(rhStep, ObjectiveRHreal(rhstep));
              
# Beregn totale emission af CO2.
TotalSumCO2Emis(net,co2kind) =  sum(tt $(ord(tt) LE DurationPeriod), TotalCO2Emis.L(tt,net,co2kind));

*begin Beregn marginaler for kapacitetsallokeringer til elmarkeder

# Tolkning af equation marginaler:
#   Generelt angiver en equation marginal, hvad objektfunktionen (her: gevinsten) vil stige, hvis højresiden øges med 1 enhed, alt andet lige.
#   GradUCapE er marginalerne for hvert tidspunkt i driftsdøgnet (hvortil buddene er givet).
#   GradUCapE beregnes med fortegn således, at den angiver gevinsten for en øgning af CapEAlloc med 1 enhed.

# CapEU er den øjeblikkelige max. kapacitet: FfMax / COP for elforbrugende anlæg, og PfNet(t) for elproducerende anlæg
#--- EQ_CapEAllocConsUp(t,uelcons)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'up'))   .. Ff(t,uelcons)                        =G=  BLen(t) * CapEAlloc(t,uelcons,'up');
#--- EQ_CapEAllocConsDown(t,uelcons) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapEAvail(uelcons,'down')) .. Ff(t,uelcons)                        =L=  BLen(t) * (CapEU(t,uelcons) - CapEAlloc(t,uelcons,'down'));
#--- EQ_CapEAllocProdUp(t,uelprod)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'up'))   .. sum(kv $sameas(kv,uelprod), PfNet(t,kv))  =L=  BLen(t) * (CapEU(t,uelprod) - CapEAlloc(t,uelprod,'up'));
#--- EQ_CapEAllocProdDown(t,uelprod) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapEAvail(uelprod,'down')) .. sum(kv $sameas(kv,uelprod), PfNet(t,kv))  =G=  BLen(t) * CapEAlloc(t,uelprod,'down');

GradUCapE(tbid,uelcons,'up')   $OnUGlobal(uelcons) = sum(tt2tbid(tt,tbid), +Blen(tt) * EQ_CapEAllocConsUp.m(tt,uelcons));
GradUCapE(tbid,uelcons,'down') $OnUGlobal(uelcons) = sum(tt2tbid(tt,tbid), -Blen(tt) * EQ_CapEAllocConsDown.m(tt,uelcons));
GradUCapE(tbid,uelprod,'up')   $OnUGlobal(uelprod) = sum(tt2tbid(tt,tbid), -Blen(tt) * EQ_CapEAllocProdUp.m(tt,uelprod));
GradUCapE(tbid,uelprod,'down') $OnUGlobal(uelprod) = sum(tt2tbid(tt,tbid), +Blen(tt) * EQ_CapEAllocProdDown.m(tt,uelprod));

GradUCapESumU(tbid,dirResv) = sum(uelec $OnUGlobal(uelec), GradUCapE(tbid,uelec,dirResv));
GradUCapETotal(dirResv)     = sum(tbid, GradUCapESumU(tbid,dirResv));

*end 

