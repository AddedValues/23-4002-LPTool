$log Entering file: %system.incName%

display '>>>>>>>>>>>>>>>>  ENTERING %system.incName%  <<<<<<<<<<<<<<<<<<<';

$OnText
Denne fil LoopPeriods.gms styrer optimeringen af samtlige perioder i den aktuelle master-iteration,
herunder duplikerer af den foregående periodes resultater, hvis det er angivet

$OffText

#--- execute_unload "BeforeLoopPeriods.gdx";

#begin Startgæt for binære variable indlæses.

# TODO MBL 2020-06-0p8 22:04: Startgæt skal være specifikke for den aktuelle periode.

#--- StartGaetAvailable(perA,iter) = 0;
#--- SbOn(t,u,perA,iter) = 0;
#--- SbStart(t,chp,perA,iter) = 0;

#OBS MBL 2020-08-24 20:58: Startgæt indlæsning unødvendigt, når der kun arbejdes med én periode, da variablene holdes i memory.
#--- if (ord(iter) GE 3,
#---   execute_load 'StartGaetOutputGDX.gdx' ttStartMin, ttStartMax, SbOn, SbStart, StartGaetAvailable;
#--- );

#end

# Nulstilling af indikatorer for duplikerede / interpolerede perioderesultater.
PeriodIsDuplicate(actPer,iter) = 0;
  
# -------------------------------------- PERIODE LOOP STARTER HER --------------------------------------------------

Loop (perL $(ord(perL) GE PeriodFirst AND ord(perL) LE PeriodLast),

  actPer(perAlias) = (ord(perAlias) EQ ord(perL));
  ActualPeriod = ord(perL);
  DurationPeriod = min(card(tt), Periods('PeriodHours', actPer));
  actYrPlan(yrPlan) = ord(yrPlan) EQ (ord(perL) - PeriodFirst + 1);
  
  #--- # OBS Skrivning på GAMS-loggen optræder først efter den øvrige kørselslog !!!
  #--- put log / "Starting period loop: Iter=", MasterIter, ", ActualPeriod=", ActualPeriod, ", DurationPeriod=", DurationPeriod /;
  
  # Bestem kalenderår, som svarer til aktuelle periode.
  actYr(yr) = no;
  loop (yr,
    if (YearScenActual('CalYear',yr) EQ [YearStart + ord(perL) - PeriodFirst],
      actYr(yr) = yes;
      loop (yrPlan, if (sameas(yrPlan, yr), actYrPlan(yrPlan) = yes; break; ); );
      break;
    );
  );
  display MasterIter, actPer, ActualPeriod, actYr, actYrPlan;
  

  PeriodIsDuplicate(actPer,iter) = (OnDuplicatePeriods GT 0) AND (DuplicateUntilIteration(actPer) GT 0) AND (MasterIter LE DuplicateUntilIteration(actPer));
  
  display "DEBUG LoopPeriods.gms: OnDuplicatePeriods, MasterIter, DuplicateUntilIteration, PeriodIsDuplicate", 
                                  OnDuplicatePeriods, MasterIter, DuplicateUntilIteration, PeriodIsDuplicate;
  
  
  if ( NOT PeriodIsDuplicate(actPer,iter),   

    # Beregn periodens bidrag til master-modellen.

    PeriodIsDuplicate(actPer,iter) = 0;   # Angiver, at perioden ikke er duplikeret.
  
# MOVE $Include LoopPeriodPre.gms
# MOVE $Include TimeAggrPeriod.gms
# MOVE #--- $Include PriceTaxTariffPeriod.gms   # Inkluderes af LoopPeriodPre.gms
# MOVE $Include LoopRollHorizPre.gms
# MOVE $Include SetupSlaveModel.gms             # Opsætter modellen for den aktuelle periode.
# MOVE $Include SolveSlaveModel.gms
# MOVE $Include LoopRollHorizPost.gms
# MOVE $Include LoopPeriodPost.gms

  );  #   if (PeriodIsDuplicate(actPer,iter),   #--- )

  
  # Sammenfatning og betinget persistering (%DumpStatsToExcel%) af periodens resultater. 
  
  #---   # DUMP til Excel output. Sikrer at Stats-parametre bliver beregnet også for duplikerede perioder.
  #--- $Include DumpPeriodsToExcel.gms
  #--- 
  #---   # Udskrivning af slaveresultat i gdx-format for aktuel periode.
  #--- $batInclude 'SavePeriodResults.gms' 
  
  #begin Indlæs og reager på evt. afbrydelsessignal manuelt skrevet i filen BreakRun.txt 
  
  embeddedCode Python:
  
  import os
  wkdir = os.getcwd()
  fpath = os.path.join(wkdir, r'BreakRun.txt')
  
  if not os.path.exists(fpath):
    breakrun = 0
    #--- gams.printLog('WARNING: No such file: ' + fpath)
  else:
    f = open(fpath, mode='r')
    lines = f.readlines()
    f.close()
    
    breakrun = list()
    for line in lines:
      line = line.strip()
      if line.startswith('*'):
        continue
      else:
        breakrun.append(int(line))
        break
    
    #--- gams.printLog('BreakRun = ' + str(breakrun[0]))
    #--- if breakrun == 1:
    #---   gams.printLog('\r\nRun will be halted after actual period.\r\n')
    #--- elif breakrun == 2:
    #---   gams.printLog('\r\nRun will be halted after actual master iteration.\r\n')
    
  gams.set('BreakRun', breakrun)
  
  endEmbeddedCode BreakRun
  
  display BreakRun
  
  if (BreakRun EQ 1, 
    display 'Breaking run after actual period', BreakRun;
  );
  break $(BreakRun EQ 1); 
  
  #end  Indlæs og reager på evt. afbrydelsessignal manuelt skrevet i filen BreakRun.txt 
  
  
); # Loop perL ...


#begin Interpolation af de resultater, som skal bruges i master-modellen, fra originalperioden. 

display "DEBUG LoopPeriods.gms: OnDuplicatePeriods, MasterIter, DuplicateUntilIteration, PeriodIsDuplicate", 
                                OnDuplicatePeriods, MasterIter, DuplicateUntilIteration, PeriodIsDuplicate;
                                
# Bestem slutperiode, om nogen, til brug for interpolation, og beregn hældningskoefficienten PeriodWeight. Hvis ingen slutperiode, så er hældningskoefficienten lig nul, dvs. ren duplikering .
# Interpolation:  Values(peri) = Values(perBegin) + PeriodWeight(peri) * (values(perEnd) - values(perBegin));
# Denne opgørelse er nødt til at blive gentaget efter afslutning af periode-iterationer, da duplikering kan ændre sig i løbetg af master-iterationen.
# PeriodIsDuplicate er i periode-iterationen initialiseret med værdien 1, hvis en given periode skal duplikeres / interpoleres.

if (OnDuplicatePeriods,
  NDuplicates = 0;
  BeginOrig   = PeriodFirst;
  EndOrig     = -1;
  PeriodWeight(perA) = 0.0;
  
  # Initialiser start- og slutperiode til perioden selv (default for non-dubletter).
  PeriodOriginal(perA,begend) $(ord(perA) GE PeriodFirst AND ord(perA) LE PeriodLast) = ord(perA);
  
  loop (perA $(ord(perA) GE PeriodFirst + 1 AND ord(perA) LE PeriodLast),
    if (PeriodIsDuplicate(perA,iter),
      NDuplicates = NDuplicates + 1;
      PeriodOriginal(perA,'begin') = BeginOrig;
    else
      EndOrig = ord(perA);
      loop (perAlias $(ord(perAlias) GE BeginOrig + 1 AND ord(perAlias) LE EndOrig - 1),
        PeriodWeight(perAlias) = (ord(perAlias) - BeginOrig) / (NDuplicates + 1);
        PeriodOriginal(perAlias,'end') = EndOrig;
      );
      BeginOrig = ord(perA);
      NDuplicates = 0;
    );
  );
  
  display OnDuplicatePeriods, DuplicateUntilIteration, PeriodOriginal, PeriodWeight;


  # Udfør duplikering/interpolation af perioder.
  Loop (perA $(ord(perA) GE PeriodFirst  + 1 AND ord(perA) LE PeriodLast),
    actPer(perAlias) = (ord(perAlias) EQ ord(perA));
    ActualPeriod = ord(perA);
    if (PeriodIsDuplicate(actPer,iter),   
      
      perBegin(perAlias) = (ord(perAlias) EQ PeriodOriginal(actPer,'begin'));
      perEnd(perAlias)   = (ord(perAlias) EQ PeriodOriginal(actPer,'end'));
      
      display "DEBUG LoopPeriods.gms: MasterIter, actPer, perBegin, perEnd",  MasterIter, actPer, perBegin, perEnd;
    
      # Interpolation af de periode-resultater, som indgår i master-modellen.
      # PeriodWeight == 0 angiver, at periode-resultaterne duplikeres fra første originale (beregnede) periode.
      PerMargObj(actPer,iter)     = PerMargObj(perBegin,iter)    + PeriodWeight(actPer) * (PerMargObj(perEnd,iter)    - PerMargObj(perBegin,iter));
      GradUMarg(unew,actPer)      = GradUMarg(unew,perBegin)     + PeriodWeight(actPer) * (GradUMarg(unew,perEnd)     - GradUMarg(unew,perBegin));
      MarginalsHour(unew, actPer) = MarginalsHour(unew,perBegin) + PeriodWeight(actPer) * (MarginalsHour(unew,perEnd) - MarginalsHour(unew,perBegin));  
    );
  );
  
);  # if (OnDuplicatePeriods   #-)

#end Interpolation af de resultater, som skal bruges i master-modellen, fra originalperioden.                                


#--- execute_unload "Main.gdx";
#--- abort "BEVIDST STOP i LoopPeriods.gms";