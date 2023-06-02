$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        SetupMasterModel.gms
Scope:          Opstiller master model forud for dens optimering.
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText


#begin Beregn nutidsværdi over planperioden for de kapaciteter, som blev anvendt i periode-modellen.
$OnText
# NB: iter1 svarer til initialisering uden master-iteration.
#     iter(N) udfører først en periode-optimering med kapaciteterne fra iter(N-1).
#     Dernæst beregnes nutidsværdien for planperioden.
#     Dernæst beregnes inkrementelle kapacitetsændringer vha. master-modellen.
$OffText

# Beregn fast kapacitets omkostning for hvert anlæg: FixCost + Deprec + TariffElEffekt
# OBS Worst-case beregning for VP, reelt skal el-effekt tariffen beregnes af max-effekttrækket som snit af 10 timer med højeste effekttræk jf. Dansk Energis Tarif-3.0 model.
# OBS set uelec er foreningsmængden af set hp og set uek. 
# OBS Et anlæg kan være til rådighed med nul-kapacitet under masteriterationerne. 
CapacPPer(u,per)                    = 0.0;
CapacPPer(kv,per)  $OnUPer(kv,per)  = PowInMaxUPer(kv,per) * DataU(kv,'EtaP');
CapacPPer(hp,per)  $OnUPer(hp,per)  = MasCapActual(hp,per) / COPmin(hp);
CapacPPer(uek,per) $OnUPer(uek,per) = MasCapActual(uek,per);
CapacPoverQPer(u,per)               = 0.0;
CapacPoverQPer(uelec,per) $(OnUPer(uelec,per) AND MasCapActual(uelec,per) GT 10*tiny)  = CapacPPer(uelec,per) / MasCapActual(uelec,per);
FixCapUCostPer(u,per) = Capex(u,'fixCost') + TariffElEffektUPer(u,per) * CapacPoverQPer(u,per) $OnUPer(u,per);  # DKK/MWq/yr
display CapacPPer, CapacPoverQPer, FixCapUCostPer;

$OffOrder
rate = ActScen('InterestRate');
CapUCostPerIter(unew,perA,iter) = 0.0;

# Eksisterende anlæg med faste kapaciteter i given periode.
#--- SharedCapexPerIter(perA,iter) = 0.0;
loop (uexist,
  loop (per $OnUPer(uexist,per),
    #remove YearShare = Periods('PeriodHours',per) / card(tt);
    CapUCostPerIter(uexist,per,iter) = YearSharePer(per) * [FixCapUCostPer(uexist,per) + DeprecExistPer(uexist,per) * 1E+6]; # DeprecExistPer angivet i MDKK/år.

#---     # Omkostninger for fællesanlæg (VAK).
#---     loop (vak $(OnUPer(vak,per) AND sameas(vak,uexist)),
#---       SharedCapexPerIter(per,iter) = SharedCapexPerIter(per,iter) + CapUCostPerIter(uexist,per,iter);
#---     );
  );
);

# Nye anlæg med variable kapaciteter.
loop (unew,
  actU(unew) = yes;
  nTerm   = Capex(unew, 'invLen');             # Antal terminer [år].
  fDeprec = rate / (1 - (1+rate)**(-nTerm));   # Amortiseringsfaktor.
  capex0  = Capex(unew,'capex0') * 1E6;        # Kapac-uafh. investering DKK/MWq.
  capex1  = Capex(unew,'capex1') * 1E6;        # Kapac-afh. investering DKK/MWq.

  loop (per $OnUPer(unew,per),
    actPer(per) = yes;
    # Beregn hver periodes mer-kapacitet dcapp ift. foregående periode og tilhørende capex.
    # MasCapActual indeholder de absolutte kapaciteter anvendt i forrige periode-optimering hhv. initialisering af kapaciteter.
    If (ord(per) EQ 1,
      dcapp = MasCapActual(unew,per);
    Else
      dcapp = MasCapActual(unew,per) - MasCapActual(unew,per-1);
    );
    
    deprecMarg    = capex1 * fDeprec;              # NB: capex0 udeladt, da det afventer MIP-master model.
    deprecAbsPlan = dcapp * deprecMarg;

    # INFLATION: Her korrigeres deprecAbsPlan for inflation ift. udgangsperioden per for del-investeringen dcapp.
    loop (perAlias $(ord(perAlias) GE (ord(per) + PeriodFirst - 1) AND ord(perAlias) LE PeriodLast),
      # Capex og fixCost er foreskrevet på årsbasis. Derfor skal periodens relative årslængde multipliceres i summeringen af de samlede merkapacitetsomkostninger.
      # Annuiteter skal betales frem til den tidligste af planperiodens slutning og annuitetslånets løbetid (nTerm).
      # Faste omkostninger skal betales til og med planperiodens slutning.
      actPerAlias(perAlias) = yes;
      YearShare   = YearSharePer(perAlias);
      Inflation   = Periods('DisconInfla',per) / Periods('DisconInfla',perAlias);                  
      fixCostPlan = dcapp * FixCapUCostPer(unew,per);     # Årlige faste omkostninger DKK/MWq/år. Skal IKKE inflationskorrigeres.
  
      CapUCostPerIter(unew,perAlias,iter) = CapUCostPerIter(unew,perAlias,iter) + YearShare * [fixCostPlan + deprecAbsPlan * Inflation $(ord(perAlias) LE nTerm+PeriodFirst-1)];
    );
  );
);

$OnOrder

# Nutidsværdien er summen af drifts-objectives over perioderne minus kapacitetsomkostninger.
# Indtil videre regnes i faste priser dvs. uden diskontering af fremtidige pengestrømme.
# Både eksisterende og nye kapaciteter medregnes i NPV, så NPV kan bruges direkte beregning af den gennemsnitlige varmeprod-omkostn.

CapUCostSumPerIter(per,iter) = sum(u $OnUPer(u,per), CapUCostPerIter(u,per,iter));
NPVIter(iter)                = sum(per, PerMargObj(per,iter) - CapUCostSumPerIter(per,iter) ) - (MasPenaltyCostActual(iter-1) $OnNpvPenalty);
display MasterIter, IterAlfa, AlfaIter, PerMargObj, CapUCostSumPerIter, NPVIter, CapUCostPerIter;

#end   Beregn nutidsværdi over planperioden.

#begin Exit Master-iteration loop, hvis kun slave-modellen ønskes udført.

if (MasterIterMax EQ 1,
  display 'Slave-modellen er udført - der skal ikke udføres master-iterationer, idet MasterIterMax = 1', MasterIterMax;
  break;
);

#end

#begin Konvergensvurdering EFTER Periode-model og FØR Master-model.

# Konvergens vurderes på følgende kriterier:
# 1: Max. antal master-iterationer er opbrugt.
# 2: Ændringen i planperiodens nutidsværdi ift. forrige iteration var mindre end EpsDeltaNPVLower.
#
# MasCapU er de anlægsvarmekapaciteter, som beregnes af master-modellen i hver iteration efter 'iter1'.
# MasCapU beregnes vha master-modellen baseret på MasCapOfz, som fastlægges efter periode-optimering,
#        og kan derfor mangle, hvis stop-kriterier er opfyldt efter periode-optimering og før master-optimering.
# MasCapActual er udgangspunkt for periode-optimeringer, dvs. beregning af PowInMaxU.
# MasCapActual er master-modellen optimale kapaciteter i forrige master-iteration.
# MasCapBest er de kapaciteter, som har givet hidtil bedste nutidsværdi NPV.
# MasterBestIter peger på den master-iteration, som gav bedste nutidsværdi, dvs. før kørsel af mastermodellen.


#TODO Fjerne MasCapBest og MasCapBestIter, da de kan hentes via MasterBestIter.
#begin Start på konvergens-vurdering efter periodeoptimering.
display "START PAA KONVERGENS-VURDERING EFTER PERIODE-MODEL, MEN FØR MASTER-MODEL";
dNPV           = NPVIter(iter) - NPVIter(iter-1);
dNPVIter(iter) = dNPV;
dNPVBest       = NPVIter(iter) - NPVBestIter(iter-1);
display MasterIter, dNPV, dNPVBest;

If (NPVIter(iter) GE NPVBestIter(iter-1),
  bestIter(iter)                = yes;
  MasterBestIter(iter)          = MasterIter;
  NPVBestIter(iter)             = NPVIter(iter);
  MasCapBest(unew,per)          = MasCapActual(unew,per) $OnUPer(unew,per);
  MasCapBestIter(unew,per,iter) = MasCapBest(unew,per) $OnUPer(unew,per);
Else
  MasterBestIter(iter)          = sum(bestIter, MasterBestIter(bestIter));
  NPVBestIter(iter)             = sum(bestIter, NPVBestIter(bestIter));
  MasCapBestIter(unew,per,iter) = sum(bestIter, MasCapBestIter(unew,per,bestIter));
);

display bestIter, MasterIter, IterAlfa, Alfa, dNPV, NPVIter, NPVBestIter;
#end

#begin Check om kapacitetsændringer for hvert anlæg er monotone henover iterationer.

Monotony(unew,per) = 1;  # Monoton sekvens indtil iter GE 3 og indtil modsatte er bevist herunder.
loop (iterAlias $(ord(iterAlias) GE 3 AND ord(iterAlias) LT ord(iter)),
  loop (per,
    loop (unew $OnUPer(unew,per),
      tmp = MasdCapU(unew,per,iterAlias) * MasdCapU(unew,per,iterAlias-1);
      #- tmp = (MasCapActualIter(unew,per,iterAlias)   - MasCapActualIter(unew,per,iterAlias)) *
      #-       (MasCapActualIter(unew,per,iterAlias-1) - MasCapActualIter(unew,per,iterAlias-2));
      # Hvis tmp er negativ, er ændringerne ikke monotont stigende hhv. konstante.
#TODO Relaksering af monotoni-krav (fortegnsskift)  tmp GT eps
      Monotony(unew,per) = Monotony(unew,per) AND (tmp GT 0.25);
    );
  );
);
MonotonyExists(per) = sum(unew $OnUPer(unew,per), Monotony(unew,per));
MonotonyExistsIter(per,iter) = MonotonyExists(per);
display MasterIter, Monotony, MonotonyExistsIter;

#end Check for monotonitet.

#begin Pre-Master konvergens-check
# Først checkes for om iteration af stepvektorens råderum er igangværende (IterAlfa > 0).
# Ellers checkes mod de øvrige konvergenskriterier.
stop = 0;
ConvergenceCode(iter) = -999;
NIterBelowBest = MasterIter - MasterBestIter(iter);
display MasterIter, NIterBelowBest, MasterBestIter;

#begin Generelle konvergens-check uafh. af AlfaVersion
If (AlfaIter(iter-1) LT AlfaMin,
  display "KONVERGENS-PRE-MASTER 0.1: Stop på at forrige Alfa underskrider AlfaMin";
  display AlfaMin, Alfa, AlfaIter;
  ConvergenceCode(iter) = 0.1;
  stop = 1;
ElseIf (NIterBelowBest GT MaxIterBelowBest),
  display "KONVERGENS-PRE-MASTER 0.2: Stop på at antal iterationer med NPV under hidtil bedste er overskredet";
  display MasterIter, NIterBelowBest, MasterBestIter;
  ConvergenceCode(iter) = 0.2;
  stop = 1;
#end Generelle konvergens-check uafh. af AlfaVersion

ElseIf (AlfaVersion EQ 2),
#begin AlfaVersion = 2
  If (dNPV GT EpsDeltaNPVUpper * abs(NPVIter(iter)),   #--- OR (dNPV LT -EpsDeltaNPVLower * abs(NPVIter(iter))),
    display "KONVERGENS-PRE-MASTER 2.1: AlfaVersion = 2: Alfa fastholdes.";
    # Alfa fastholdes, da dNPV overstiger mindstekravet til fortsat søgning med nuværende stepvektor.
    ConvergenceCode(iter) = 2.1;
    IterAlfa = 0;

  #DISABLED ElseIf (abs(dNPV) LT min(EpsDeltaNPVLower,EpsDeltaNPVUpper) * abs(NPVIter(iter))),
  #DISABLED   display "KONVERGENS-PRE-MASTER 2.2: AlfaVersion = 2: abs(dNPV) underskrider mindstekravet. Master-iteration stoppes.";
  #DISABLED   # Ændringen i NPV underskrider den relative tærskel og master-iterationen stoppes.
  #DISABLED   ConvergenceCode(iter) = 2.2;
  #DISABLED   stop = 1;

  Else
    display "KONVERGENS-PRE-MASTER 2.3: AlfaVersion = 2: Alfa reduceres med AlfaReducIndiv.", AlfaReducIndiv;
    # Start på reduktion af stepvektoren uanset om dNPV er positiv eller negativ.
    ConvergenceCode(iter) = 2.3;
    Alfa = Alfa * AlfaReducIndiv; #--- 0.5;  #--- 2/3;
    IterAlfa = IterAlfa + 1;
  );
  # Tag udgangspunkt i hidtil bedste iteration.
  #MasCapOfz(unew,per) = MasCapBestIter(unew,per,iter);
  MasCapOfz(unew,per) = MasCapActual(unew,per);
  AlfaIter(iter) = Alfa;
  display MasterIter, bestIter, AlfaIter, Alfa;
#end AlfaVersion = 2

ElseIf (AlfaVersion EQ 3),
#begin AlfaVersion = 3
  If (IterAlfa GT 0,
    display "KONVERGENS-PRE-MASTER 3.1: AlfaVersion = 3: Alfa iteration igang, Alfa reduceres.";
    # Alfa iteration i gang. Alfa reduceres, men udgangspunktet er nyt.
    ConvergenceCode(iter) = 3.1;
    Alfa = Alfa * AlfaReducIndiv;  #--- / 2;
    IterAlfa = IterAlfa + 1;
  ElseIf (dNPV GT EpsDeltaNPVUpper * abs(NPVIter(iter))),
    display "KONVERGENS-PRE-MASTER 3.2: AlfaVersion = 3: Alfa fastholdes.";
    # Alfa fastholdes, da dNPV overstiger mindstekravet til fortsat søgning med nuværende stepvektor.
    ConvergenceCode(iter) = 3.2;
  Else
    display "KONVERGENS-PRE-MASTER 3.3: AlfaVersion = 3: Alfa reduceres.";
    # Start på reduktion af stepvektoren uanset om dNPV er positiv eller negativ.
    ConvergenceCode(iter) = 3.3;
    Alfa = Alfa * AlfaReducIndiv;  #--- / 2;
    IterAlfa = IterAlfa + 1;
  );
  # Tag udgangspunkt i hidtil bedste iteration.
  #MasCapOfz(unew,per) = MasCapBestIter(unew,per,iter);
  MasCapOfz(unew,per) = MasCapActual(unew,per);
  AlfaIter(iter) = Alfa;
  display MasterIter, bestIter, AlfaIter, Alfa;
#end AlfaVersion = 3

ElseIf (AlfaVersion EQ 4 OR AlfaVersion EQ 5 OR AlfaVersion EQ 6),
#begin AlfaVersion = 4, 5 eller 6
  # Vi forsøger os med dobbelt kørsel af master solve for at finde passende alfaindi(-viduel).
  MasCapOfz(unew,per) = MasCapActual(unew,per);
  ConvergenceCode(iter) = 4.1;
  display AlfaVersion, "KONVERGENS-PRE-MASTER 4.1: AlfaVersion = 4, 5 eller 6: Ekstra master-iteration udføres.";
#end AlfaVersion = 4, 5 eller 6

# OBS: Følgende del af if-then-else blokken vedrører kun AlfaVersion = 1.

ElseIf (dNPV GE 0.0 AND dNPV LE EpsDeltaNPVUpper * abs(NPVIter(iter))),
  # Intet behov for at opdatere MasCapOfz, gøres kun for at se resultatet af en sidste master-optimering i gdx-filen.
  MasCapOfz(unew,per) = MasCapActual(unew,per);
  #- If (sum(per, MonotonyExists(per)) GT 0,  # )
  If (MonotonyExists('per1') GT 0,
    stop = 0;
    ConvergenceCode(iter) = 1.1;
    display "KONVERGENS-PRE-MASTER 1: Ingen stop på dNPV >= 0 AND <= EpsDeltaNPVUpper pga. monotone kapacitetsændringer";
  else
    stop = 1;
    ConvergenceCode(iter) = 1.2;
    display "KONVERGENS-PRE-MASTER 2: Stop på dNPV >= 0 AND <= EpsDeltaNPVUpper";
  );
#- ElseIf (NOT sum(per, MonotonyExists(per)) AND (IterAlfa EQ 0) AND dNPV GT -EpsDeltaNPVLower * abs(NPVIter(iter-1))),
#- ElseIf (NOT MonotonyExists('per1') AND (IterAlfa EQ 0) AND dNPV GT -EpsDeltaNPVLower * abs(NPVIter(iter-1))),
# OBS: Monotoni-kravet udelades; i stedet sikres, at dNPV er negativ.

#--- ElseIf (AlfaVersion LE 3) AND (IterAlfa EQ 0) AND dNPV LT 0.0 AND dNPV GT -EpsDeltaNPVLower * abs(NPVIter(iter-1)),
ElseIf (IterAlfa EQ 0) AND (dNPV LT 0.0) AND (dNPV GT -EpsDeltaNPVLower * abs(NPVIter(iter-1))),
  display "KONVERGENS-PRE-MASTER 3: START På STEPVEKTOR-ITERATIONER";
  #begin Start på iteration af stepvektorens råderum (AlfaVersion = 1).
  # Kapaciteterne er ikke længere monotone, og nutidsværdien har haft et lille dyk.
  # Linearisering af NPV holdt ikke stik for stepvektoren.
  # Faldet i nutidsværdi ift. forrige master-iteration ligger indenfor tolerancen.
  # Derfor skal stepvektoren begrænses, først en halvering, dernæst bedre estimat vha. 2. ordens approksimation.
  # Men først beregnes det nødvendige tredje punkt mellem forrige og aktuelle iteration.
  stop = 0;
  Alfa = Alfa * AlfaReducIndiv; #--- / 2;    # Næste iteration skal beregne NPV for reduceret bounding-box (alfa) til brug for parabel.
  IterAlfa = 1;       # Tæller antal iterationer på stepvektoren.
  display "IterAlfa := 1";
  # MasCapBest(unew,per) er uændret, derfor adopteres den som var bedst i forrige iteration.
  IterAlfaOutset       = MasterBestIter(iter);
  MasCapOfz(unew,per)  = sum(iterAlias $(ord(iterAlias) EQ IterAlfaOutset), MasCapActualIter(unew,per,iterAlias) );
  #-MasCapOfz(unew,per)  = sum(bestIter, MaxCapActualIter(unew,per,bestIter));
  display 'NPV < NPVprev', MasterIter, bestIter, MasterBestIter, IterAlfaOutset, IterAlfa, Alfa, AlfaIter, MasCapOfz;
  ConvergenceCode(iter) = 1.4;
  #end

  #TODO Der er en mulig risiko ved at forveksle udgangspunktet for alfa-iterationen med det hidtil bedste udgangspunkt.

#--- ElseIf (AlfaVersion LE 3) AND (IterAlfa EQ 1),
ElseIf (IterAlfa EQ 1),
  display "KONVERGENS-PRE-MASTER 4: FØRSTE STEPVEKTOR - ITERATION: IterAlfa = 1";
  ConvergenceCode(iter) = 1.11;
  #begin Iteration af stepvektorens råderum er startet i foregående iteration.
  # De 2 foregående iterationers indhold svarer nu til alfa = 0.0, AlfaPrevious og 0.5*AlfaPrevious.
  # NPV tilnærmes med en parabel baseret på de 3 seneste iterationer.
  #- MasCapOfz(unew,per) = sum(iterAlias $(ord(iterAlias) EQ IterAlfaOutset), MasCapActualIter(unew,per,iterAlias) );

  #begin Beregn koefficienter til parablen gennem de 3 NPV-værdier som funktion af alfa.
  # Herunder står x for alfa og y for NPV. Indices rangerer fra 0 til 2 sv. til alfa = {0, 1, 0.5}.
  # coef er koefficienter til parablen, hvor coef[i] er koeff. til x**i.
  x0 = 0.0;
  x1 = 0.5;
  x2 = 1.0;
  y0 = NPVIter(iter-2);
  y1 = NPVIter(iter-0);
  y2 = NPVIter(iter-1);
  display y0, y1, y2;

  f2 = (x2-x0) / (x1-x0);
  c22 = x2**2 - x0**2 - f2 * (x1**2 - x0**2);
  coef2 = ((y2 - y0) - f2 * (y1 - y0)) / c22;

  c12 = x1**2 - x0**2;
  coef1 = (y1 - y0 - c12 * coef2) / (x1 - x0);

  coef0 = y0 - coef2 * x0**2 - coef1 * x0;
  display f2, c22, c12;
  display coef0, coef1, coef2;

  # Alfa-koordinat for parablens toppunkt.
  # Udgangspunktet for næste iteration er stadig kapaciteterne for seneste iteration med alfa = 0.0,
  # dvs. MasCapBest er uændret.
  If (coef2 GE 0.0,
    # Parabel toppunkt er minimum eller parabel er degenereret til linje.
    # Stepvektorens råderum halveres ift. forrige iteration (EKSPERIMENT).
    AlfaReduc = 0;
  Else
    AlfaReduc = -coef1 / (2 * coef2);
  );
  display MasterIter, bestIter, AlfaReduc;
  If (AlfaReduc LE 0.0 OR AlfaReduc GT 1.0,
    display "KONVERGENS-PRE-MASTER 5: Parabel toppunkt ligger udenfor AlfaReduc-intervallet [0..1]. Iteration stoppes";
    display Alfa, AlfaReduc;
    stop = 1;
    ConvergenceCode(iter) = 1.12;
  );
  #end
  IterAlfa = IterAlfa + 1;
  Alfa = (2 * Alfa) * AlfaReduc;  # Alfa var indtil denne linje lig med 0.5 * AlfaPrevious.
  display 'IterAlfa EQ 2', MasterIter, bestIter, IterAlfa, IterAlfaMax, AlfaReduc, Alfa, AlfaIter;
  #end

#--- ElseIf (AlfaVersion LE 3) AND (IterAlfa GE 2),
ElseIf (IterAlfa GE 2),
  display "KONVERGENS-PRE-MASTER 6: EFTERFØLGENDE STEPVEKTOR - ITERATION: IterAlfa >= 2";
  ConvergenceCode(iter) = 1.13;
  #begin Iteration på stepvektorens råderum er i gang.
  # I forrige iteration blev bestemt den mest lovende alfa-værdi baseret på parabel approksimation.
  display MasterIter, NPVIter, NPVBestIter;
  # Hvis nutidsværdien er større end hidtil bedste, opdateres udgangspunktet MasCapOfz.
  # Det vil kun være tilfældet, hvis parablen har opadvendt toppunkt.
  display NPVIter, NPVBestIter;
  If (NPVIter(iter) GE NPVBestIter(iter-1),
    ConvergenceCode(iter) = 1.14;
    display "NPV(iter) >= NPVBest(iter-1)";
    MasterBestIter(iter) = MasterIter;
    MasCapBest(unew,per) = MasCapActual(unew,per);
    MasCapOfz(unew,per)  = MasCapActual(unew,per);
    NPVBestIter(iter)    = NPVIter(iter);
  Else
    # Parablens toppunkt gav ikke en bedre løsning.
    # Derfor reduceres Alfa og ny parabel-approksimation kan testes.
    ConvergenceCode(iter) = 1.15;
    MasterBestIter(iter) = MasterBestIter(iter-1);
    NPVBestIter(iter)    = NPVBestIter(iter-1);
  );

  # Uanset om parabel-approksimation gav en bedre nutidsværdi eller ej, så stoppes master-iterationer.
  stop = 1;
  display "KONVERGENS-PRE-MASTER 7: Stop efter parabel-approksimation";

  #- # Reducer alfa og fortsæt, herunder tillad fornyet parabel approksimation, nu med reduceret Alfa.
  #- Alfa     = min(0.5, Alfa / 2);
  #- IterAlfa = 1;
  #- display 'IterAlfa GE 2', MasterIter, IterAlfa, IterAlfaMax, Alfa, AlfaIter, NPVBestIter, MasCapOfz;
  #end

Else
  display "KONVERGENS-PRE-MASTER 8: Fortsæt iteration";
  stop = 0;
  # Brug aktuelle kapaciteter som udgangspunkt for næste master-optimering,
  # selvom nutidsværdien NPV ikke blev forøget ("annealing").
  MasCapOfz(unew,per) = MasCapActual(unew,per);
  ConvergenceCode(iter) = 1.16;
  display MasterIter, MasterBestIter, IterAlfa, Alfa, AlfaIter, MasCapOfz;

  #begin Check om NPV tidligere har været på dette niveau og i så fald reduceres alfa.
  NPV     = NPVIter(iter);
  NPVBest = NPVBestIter(iter);
  tmp     = abs(NPVIter(iter) - NPVBestIter(iter-1));
  #TODO Koefficient herunder (5E-3) skal oprettes som parameter i master scenariet.
  If (dNPV GT 0.0 AND tmp LE 5E-3 * abs(NPVBestIter(iter-1)),
    Alfa = Alfa * AlfaReducIndiv;  #--- Alfa / 2;
    ConvergenceCode(iter) = 1.17;
    display "Alfa reduceret med faktor AlfaReducIndiv: ", MasterIter, Alfa, tmp, NPV, NPVBest, AlfaReducIndiv;
  Else
    ConvergenceCode(iter) = 1.18;
    display "Alfa IKKE reduceret med faktor AlfaReducIndiv: ", MasterIter, Alfa, tmp, NPV, NPVBest, AlfaReducIndiv;
  );
  #end
);

MasCapOfzIter(unew,per,iter) = MasCapOfz(unew,per);

display MasterIter, stop, IterAlfa, Alfa, AlfaIter, EpsDeltaCap, EpsDeltaNPVLower, EpsDeltaNPVUpper, dNPV;
display NPVIter, NPVBestIter, MasCapU, MasdCapU, PerMargObj;

#end Pre-Master konvergens-check

#begin Absolutte (hårde) stopkriterier.
If (IterAlfa GT IterAlfaMax,
  # Max. antal iterationer på stepvektorens råderum er opbrugt.
  display "KONVERGENS-PRE-MASTER 9: Stop på max. antal alfa-iterationer  ";
  #- MasCapOfz(unew,per) = MasCapActual(unew,per);
  stop = 1;
  ConvergenceCode(iter) = 1.19;
  display 'IterAlfa GT IterAlfaMax',  MasterIter, IterAlfa, IterAlfaMax, Alfa, AlfaIter;
);
#end Absolutte (hårde) stopkriterier.

#- # Afbryd master-iterationer hvis blot ét kriterium ovenfor var opfyldt.
#- break $(stop GT 0);

#end   Konvergensvurdering EFTER Periode-model og FØR Master-model.

#begin Beregning af effektive skyggepris (GradU) for anlægskapaciteter.

$OnText
Det antages indtil videre at investeringer er lineære funktioner af kapaciteten.
Det kan ændres til fx en potensformel senere.
Indtil videre negligeres de kapac-uafhængige omkostninger Capex(...,'capex0').
Investeringer amortiseres med en rate svarende til hele afskrivningsperioden,
men pålægges kun frem til planperiodens slut.
Faste omkostninger (fixCost) summes op fra perioden til planperiodens ophør.
Afskrivninger (deprecMarg) summes op fra perioden til den tidligste af investerings- hhv. planperiodens ophør.
$OffText

#begin Beregning af faste årlige omkostninger inkl. afskrivninger.

$OffOrder
  # Iteration på alfa er ikke startet, derfor beregnes gradient på basis af seneste skyggepriser fra periode-optimeringen.
  rate = ActScen('InterestRate');
  display rate;
  loop (unew $OnU(unew),
    nTerm   = Capex(unew,'invLen');            # Antal terminer [år].
    fDeprec = rate / (1 - (1+rate)**(-nterm)); # Amortiseringsfaktor, ens for alle terminer.
    #--- fixCost = Capex(unew,'fixCost');           # årlige faste omkostninger DKK/MWq/år.
    capex0  = Capex(unew,'capex0') * 1E6;      # Kapac-uafh. investering DKK.
    capex1  = Capex(unew,'capex1') * 1E6;      # Kapac-afh. investering DKK/MWq.

    loop (per $OnUPer(unew,per),
      deprecMarg = capex1 * fDeprec;       # Lineær capex, derfor afskrivn. uafh. af aktual kapacitet.

      # OBS : GradCapU multipliceres i mastermodellen på kapac-ændringerne (dCapUOfz), 
      #       derfor skal aggregerede delta kapac-omk. fra inv-tidspunkt og tiden ud medregnes.

      CostCap = 0;
      loop (perA $(ord(perA) GE (ord(per)+PeriodFirst-1) AND (ord(perA) LE PeriodLast)),
        # INFLATION: Her korrigeres kapacitetsomk. for inflation ift. udgangsperioden 'per1'.
        YearShare = Periods('PeriodHours',perA) / card(tt);
        Inflation = Periods('DisconInfla',per) / Periods('DisconInfla',perA);
        fixCost   = FixCapUCostPer(unew,perA);      # årlige faste omkostninger DKK/MWq/år incl el-effekt tariffer.
        
        # BUG   nTerm skal regnes fra den dag, anlægget reelt er til rådighed.
        # TODO  Overvej at sætte initial kapacitet lig nul og anlægget OFF, og beregn fra første periode med aktivt anlæg.
        # TODO  Men det kan forhindre, at marginaler beregnes, hvis et potentielt anlæg ikke er til rådighed.

        CostCap = CostCap + YearSharePer(perA) * [fixCost + deprecMarg * Inflation $(ord(perA) LE nTerm + PeriodFirst - 1)];
      );

      GradCapU(unew,per) = CostCap;  # DKK/MWq
    );
  );
$OnOrder
  # Beregning af den effektive gradient GradU som marginalgradienten minus kapacitetsgradienten.
  GradU(unew,per)              = GradUMarg(unew,per) - GradCapU(unew,per);
  GradUMargIter(unew,per,iter) = GradUMarg(unew,per);
  GradCapUIter(unew,per,iter)  = GradCapU(unew,per);
  GradUIter(unew,per,iter)     = GradU(unew,per);
#-Else  #- (
#-  # Iteration på alfa er startet, derfor ingen genberegning af GradU.
#-  GradUMargIter(unew,per,iter) = GradUMargIter(unew,per,iter-1);
#-  GradCapUIter(unew,per,iter)  = GradCapUIter(unew,per,iter-1);
#-  GradUIter(unew,per,iter)     = GradUIter(unew,per,iter-1);
#- );

# Beregn den effektive varmeprod-omkostn. for hver periode og for hele planperioden, for hvert anlæg hhv. alle anlæg.


display MasterIter, IterAlfa, GradUMarg, GradCapU, GradU;
#end

#begin Beregn effektiv gradient for master-modellen.
$OffOrder
# Kapacitetsgradienten GradCapU har inkluderet alle omk. fra og med investeringstidspunktet.
# Marginalgradienten GradUMarg gælder kun for en given periode og skal derfor aggregeres fra og med investeringstidspunktet.

#TODO CHECK HER: INFEASIBILITY EFTER SUMMERING OVER perAlias.

loop (perA $(ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast),
  GradUMargAggr(unew,perA)          = sum(perAlias $(ord(perAlias) GE ord(perA) AND ord(perAlias) LE PeriodLast), GradUMarg(unew,perAlias));
  GradUAggr(unew,perA)              = GradUMargAggr(unew,perA) - GradCapU(unew,perA);
  GradUMargAggrIter(unew,perA,iter) = GradUMargAggr(unew,perA);
  GradUAggrIter(unew,perA,iter)     = GradUAggr(unew,perA);
);

# Overførsel af hidtil bedste gradienter uanset ovenstående beregninger af gradienter.
#if (alfaVersion NE 4,
#  GradCapU(unew,per)      = sum(bestIter, GradCapUIter(unew,per,bestIter));
#  GradUMargAggr(unew,per) = sum(bestIter, GradUMargAggrIter(unew,per,bestIter));
# );

$OnOrder
display MasterIter, GradUMargAggr, GradUAggr;

#begin Afgræns råderummet for stepvektoren.

AlfaIter(iter) = Alfa;
display MasterIter, IterAlfa, Alfa, AlfaIter;

#TODO Kodeblokken herunder udføres før start af master-iterationer.
#-# Beregn den mindste sum(unew, dCapU(unew)) for hver periode, som skal være tilstede.
#-# Beregn mindstebehovet for ny kapacitet.
#-loop (perA $(ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast),
#-  CapUNeedParm(perA)   = QDemandPeak + ReserveCapQ + QLargestCp(perA);
#-  CapUOldSumParm(perA) = sum(cp  $OnUPer(cp,perA),                     PowInMaxUPer(cp,perA)  * EtaQU(cp)) +
#-                        sum(kvp $(OnUPer(kvp,perA) and not unew(kvp)), PowInMaxUPer(kvp,perA) * EtaQU(kvp));
#-  CapNewMinParm(perA) = [CapUNeedParm(perA) - CapUNeedParm(perA-1)] - [CapUOldSumParm(perA) - CapUOldSumParm(perA-1)];
#- );
display MasterIter, CapNewMinParm;

# Beregn nedre grænse for alfa baseret på opfyldelse af minimum mængde ny kapacitet.
# Noget af den nye kapacitet er der taget højde for i de aktuelle kapaciteter MasCapActual,
# som bliver opdateret i hver master-iteration forud for periode-optimeringerne.
# Når master-konvergens nærmer sig, skal alfa reduceres for at få en mere præcis stepvektorlængde,
# dvs. alfa har alene betydning for dCapUOfz, som er iterationens kapac-ændringer ift. de aktuelle kapaciteter MasCapActual.
# Den nedre grænse på alfa skal sikre, at mindstemængden af ny kapacitet bliver mulig for master-modellen.

#TODO CapNewOfzParm skal inddrage den temperatur-drevne ydelses-ændring på varmepumper.
CapNewOfzParm(per)  = sum(unew $OnUPer(unew,per), MasCapActual(unew,per));
dCapNewMinParm(per) = sum(unew $OnUPer(unew,per), dCapUInitPer(unew,per));

# Kun positive kapac-behov skal respekteres.
  AlfaNewMin(per) = [sum(net $OnNet(net), CapNewMinParm(net,per)) - CapNewOfzParm(per)] / max(1, dCapNewMinParm(per));

display CapNewOfzParm, dCapNewMinParm, AlfaNewMin;

AlfaPrev = Alfa;
AlfaMinPer = smax(per, AlfaNewMin(per));
Alfa = max(Alfa, AlfaMinPer);
If (Alfa GT 1.0,
  display Alfa;
  ConvergenceCode(iter) = 999.1;
  display 'FEJL: Alfa skal være større end 1.0 for at honorere ny kapacitet.', Alfa, AlfaNewMin;
  #--- abort 'Alfa skal være større end 1.0 for at honorere ny kapacitet. Forøg startkapaciter dCapInit'
);

# Beregn grænser for stepvektoren efter Version1 eller Version2
# Version1: Individuelle grænser for hver anlæg, som de facto udnyttes fuldt ud.
# Version2: Bounding box skaleres efter gradienten og dens numerisk største komposant.

# Først beregnes den normerede (1-norm) effektive gradientvektor GradURel.
GradUCompMax(per)  = 0.0;
GradURel(unew,per) = 0.0;
loop (per,
  tmp0 = 0.0;
  loop (unew $OnUPer(unew,per), tmp0 = max(tmp0, abs(GradUAggr(unew,per))); );  #--- tmp0 = smax(abs(GradUAggr(unew,per)));
  GradUCompMax(per) = tmp0;
  if (GradUCompMax(per) EQ 0.0,
    GradURel(unew,per) = 0.0;
  else
    # Giv et mindste råderum for anlæg med numerisk små komposanter af GradUAggr.
    # Her er valgt 25% af max. komposanten.
    loop (unew, GradURel(unew,per) = max(0.25, abs(GradUAggr(unew,per) / GradUCompMax(per)) ) $OnUPer(unew,per); );
  );
  GradURelIter(unew,per,iter) = GradURel(unew,per);
);
display MasterIter, GradURel;

# Beregn størrelsen på summen af GradUAggr og brug:
#OBS Anvendes kun ifm. AlfaVersion = 6.

display "DEBUG: ", MasterIter, AlfaIndi, GradUAggrIter;

StepScale(per) = 1.0;  # Default skalering af stepvektoren.
loop (per,
  SumGradUAggr(per)          = abs(sum(unew $OnUPer(unew,per), GradUAggr(unew,per)));
  SumGradUAggrIter(per,iter) = SumGradUAggr(per);
  if (MasterIter GE 3,
    SumGradUAggrRef(per) = SumGradUAggrIter(per,iter-1);
    if (SumGradUAggrRef(per) EQ 0.0,    # Optræder, hvis investeringer ikke er mulige i periode per.
      StepScale(per) = tiny;
    else
      StepScale(per) = SumGradUAggr(per) / SumGradUAggrRef(per);
    );
    if (StepScale(per) GT 0.80, StepScale(per) = 1.0; );
    StepScaleIter(per,iter) = StepScale(per);
    if (AlfaVersion EQ 6,
      AlfaIndi(unew,per) = AlfaIndi(unew,per) * StepScale(per);
    );
  );
);
display MasterIter, StepScale, AlfaIndi, SumGradUAggr, SumGradUAggrIter;


# Her sættes grænserne for kapac-ændringerne ift. forrige master-iteration.

# OBS Fiksering af dCapUOfz deaktiveret, da det medførte divergent master-iteration.
#--- # Først fikseres dCapUOfz for de-facto låste anlæg.
#--- loop (per,
#---   loop (unew $OnUPer(unew,per),
#---     if (OnFixedCapU(unew,per), dCapUOfz.fx(unew,per) = 0.0; );
#---   );
#--- );

# Dernæst beregnes grænser for stepvektorens komposanter.

If (AlfaVersion EQ 1 OR AlfaVersion EQ 3,
  dCapUMaxPer(unew,per) = dCapUMaxInitPer(unew,per) * Alfa;
  
ElseIf (AlfaVersion EQ 2),
  # MBL 2020-06-25 20:16: Grænser på dCapUOfz er her afhængige af gradientvektoren, men anvender fælles Alfa og fælles største kapac-ændring.
  #--- dCapUMaxPer(unew,per) = GradURel(unew,per) * dCapUAnyMax(per) * Alfa;
  # MBL 2020-12-21 09:21: I stedet for dCapUAnyMax anvendes nu de anlægs-individuelle ændringsgrænser.
  dCapUMaxPer(unew,per) = GradURel(unew,per) * dCapUMaxInitPer(unew,per) * Alfa;

ElseIf (AlfaVersion EQ 4),
  dCapUMaxPer(unew,per) = dCapUMaxInitPer(unew,per) * AlfaIndi(unew,per);

ElseIf (AlfaVersion EQ 5 OR AlfaVersion EQ 6),
  # Version 5 er en kombi af version 2 og 4, hvor bounding-box afhænger af både gradienten og de individuelle skaleringer.
  #DISABLED dCapUMaxPer(unew,per) = GradURel(unew,per) * dCapUMaxInitPer(unew,per) * AlfaIndi(unew,per);
  # AlfaVersion 6 er en videre udbygning af 5, hvor stepvektoren også reduceres ift. summen af den effektive gradient (beregnes i blokken ovenfor).
  dCapUMaxPer(unew,per) = GradURel(unew,per) * dCapUMaxInitPer(unew,per) * AlfaIndi(unew,per);

Else
  execute_unload "MECmain.gdx";
  display "ERROR:  AlfaVersion er udenfor området 1..6", AlfaVersion;
  abort "ERROR: AlfaVersion er udenfor området 1..6";
);
dCapUMaxIterPer(unew,per,iter) = dCapUMaxPer(unew,per);

display 'Evt. afgrænsning af stepvektor (dCapUMaxPer):', AlfaMinPer, AlfaPrev, Alfa, GradUCompMax, GradURel, dCapUMaxPer, dCapUMaxIterPer;

#end

#end   Beregning af effektive skyggepriser (GradU) for anlægskapaciteter.

