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
#   GradUCapF er marginalerne for hvert tidspunkt i driftsdøgnet (hvortil buddene er givet).
#   GradUCapF beregnes med fortegn således, at den angiver gevinsten for en øgning af CapFAlloc med 1 enhed.

# CapFU er den øjeblikkelige max. kapacitet: FfMax / COP for elforbrugende anlæg, og PfNet(t) for elproducerende anlæg
#--- EQ_CapFAllocConsUp(t,uelcons)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapFAvail(uelcons,'up'))   .. Ff(t,uelcons)                        =G=  BLen(t) * CapFAlloc(t,uelcons,'up');
#--- EQ_CapFAllocConsDown(t,uelcons) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelcons) AND CapFAvail(uelcons,'down')) .. Ff(t,uelcons)                        =L=  BLen(t) * (CapFU(t,uelcons) - CapFAlloc(t,uelcons,'down'));
#--- EQ_CapFAllocProdUp(t,uelprod)   $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapFAvail(uelprod,'up'))   .. sum(kv $sameas(kv,uelprod), PfNet(t,kv))  =L=  BLen(t) * (CapFU(t,uelprod) - CapFAlloc(t,uelprod,'up'));
#--- EQ_CapFAllocProdDown(t,uelprod) $(OnCapacityReservation AND IsBidDay(t) AND OnU(t,uelprod) AND CapFAvail(uelprod,'down')) .. sum(kv $sameas(kv,uelprod), PfNet(t,kv))  =G=  BLen(t) * CapFAlloc(t,uelprod,'down');

GradUCapF(tbid,uelcons,'up')   $OnUGlobal(uelcons) = sum(tt2tbid(tt,tbid), +Blen(tt) * EQ_CapFAllocConsUp.m(tt,uelcons));
GradUCapF(tbid,uelcons,'down') $OnUGlobal(uelcons) = sum(tt2tbid(tt,tbid), -Blen(tt) * EQ_CapFAllocConsDown.m(tt,uelcons));
GradUCapF(tbid,uelprod,'up')   $OnUGlobal(uelprod) = sum(tt2tbid(tt,tbid), -Blen(tt) * EQ_CapFAllocProdUp.m(tt,uelprod));
GradUCapF(tbid,uelprod,'down') $OnUGlobal(uelprod) = sum(tt2tbid(tt,tbid), +Blen(tt) * EQ_CapFAllocProdDown.m(tt,uelprod));

GradUCapFSumU(tbid,dirResv) = sum(uelec $OnUGlobal(uelec), GradUCapF(tbid,uelec,dirResv));
GradUCapFTotal(dirResv)     = sum(tbid, GradUCapFSumU(tbid,dirResv));

*end 

