$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        LoopMasterPost.gms
Scope:          Sidste del af master iteration loop
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText


#begin Konvergensvurdering EFTER Master-model.

$OnText
Konvergens vurderes på følgende kriterier:
1: Max. antal master-iterationer er opbrugt.
2: Ændringen i planperiodens nutidsværdi ift. forrige iteration var mindre end EpsDeltaNPVLower.
3: Ændringen i stepvektoren var mindre end EpsDeltaCap.
$OffText

display "START På KONVERGENS-VURDERING EFTER MASTER-MODEL";
dCapUOfzLen(per)          = smax(unew, abs(dCapUOfz.L(unew,per)) );
dCapUOfzLenIter(per,iter) = dCapUOfzLen(per);
stepULen                  = smax(per,  abs(dCapUOfzLen(per)) );
StepULenIter(iter)        = stepULen;
MasObjRel                 = abs(MasObjIter(iter) / NPVIter(iter));
display MasterIter, NPVIter, NPVBestIter, stepULen, dCapUOfzLen, dCapU.L, MasObjRel;

If (stepULen LE EpsDeltaCap AND MasterIter GE 3,
  display "KONVERGENS-POST-MASTER 1: Stop på EpsDeltaCap", stepULen, EpsDeltaCap;
  ConvergenceCode(iter) = 101;
  stop = 1;

ElseIf (MasterIter GE MasterIterMax),
  # Nødvendigt med GE operator, da deaggregering så har mulighed for at tage en ekstra masteriteration.
  display "KONVERGENS-POST-MASTER 2: Stop på MasterIterMax", MasterIter, MasterIterMax;
  ConvergenceCode(iter) = 102;
  stop = 1;

ElseIf (ord(iter) GE 2 AND [(abs(MasObjIter(iter)) LE MasObjMinTotal) OR (MasObjRel LE MasObjMinRel)]),
  display "KONVERGENS-POST-MASTER 3: Stop på MasObjMinAbs eller MssObjMinRel";
  ConvergenceCode(iter) = 103;
  ConvCode103 = 1;
  # Stop hvis dette kriterium tidligere har været opfyldt.
  #OVERRIDDEN Erfaringsmæssigt er det spildt indsats at køre en ekstra master iteration.
  stop = 0;
  #--- stop = 1;
  #--- loop(iterAlias $(ord(iterAlias) LT ord(iter)),
    #--- if (ConvergenceCode(iterAlias) EQ ConvergenceCode(iter), 
    #--- if (ConvergenceCode(iter-1) EQ ConvergenceCode(iter), 
    
    # MasObjMin-kravet og EpsDeltaCap-kravet er for restriktivt, da StepULen er max. komposanten af stepvektoren.   #--- EpsDeltaCap-kravet er obligatoriske.
    if (ConvergenceCode(iter-1) EQ ConvergenceCode(iter) AND (MasterIter GE 3), #--- AND (stepULen LE EpsDeltaCap AND MasterIter GE 3), 
      stop = 1; 
      display 'stop = 1: ConvergenceCode=103 MasObjMin underskredet i nuv. og tidl. iteration', MasterIter, stop;
    );
    
  #--- );
  #--- if (stop NE 0, display 'stop = 1: ConvergenceCode=103 MasObjMin underskredet i nuv. iteration.', MasterIter, stop; );

ElseIf (nHourMarginals EQ 0),
  display "KONVERGENS-POST-MASTER 4: Stop på manglende marginaler (følsomheder) på nye kapaciteter.";
  ConvergenceCode(iter) = 104;
  stop = 1;
);


# Opdatering af MasCapActual til brug for beregning af PowInMax i næste periode-optimering.
MasCapActual(unew,per)            = max(MinCapacUforMarginals, MasCapU(unew,per,iter));
MasCapActualIter(unew,per,iter+1) = MasCapActual(unew,per);

display MasterIter, stop, dCapUOfzLen, EpsDeltaCap;
display MasCapU, MasdCapU, MasObjIter, PerMargObj, MasCapActual;

#end   Konvergensvurdering EFTER Master-model.

#begin Udskriv statistik for master modellen 

$Include SaveMasterStats.gms

#end

# Afbryd master iterationer hvis blot ét stopkriterium er opfyldt.
# Det er underforstået, at masteriterationerne kører i et loop, som kan afbrydes af break-stmt.
# Afbrydelse håndteres i de følgende kodelinjer.
#--- break $(stop GT 0);

# Dump modellen i gdx for hver masteriteration, hvis antal masteriterationer er over 2.
if (MasterIterMax GE 3, execute_unload "MECmain.gdx"; );


#begin Check for manuel afbrydelse af kørsel efter aktuel masteriteration.

display BreakRun;

if (BreakRun GE 1, 
  display "INFO: Breaking run after actual master iteration", BreakRun;
  break $(BreakRun GE 1); 
);

#end   Check for manuel afbrydelse af kørsel.


# Gennemfør endnu en master-iteration, hvis tids-deaggregering skal udføres (OnTimeAggr LT 0).
# Udføres kun hvis master-iterationer er afsluttet.
# Hvis OnDuplicatePeriods er negativ, ophæves duplikering/interpolation, hvis tidsaggregering i sidste masteriteration er ophævet.
display "INFO: STOP-kriterier:", iter, ConvergenceCode, stop, OnTimeAggr, OnDeAggr;

If ((ConvergenceCode(iter) LT 999) AND (stop NE 0) AND (OnTimeAggr LT 0) AND (NOT OnDeAggr),
  display "INFO: STARTING DeAggregation";
  OnDeAggr    = TRUE;
  UseTimeAggr = FALSE;
  if (OnDuplicatePeriods LE -1, 
    OnDuplicatePeriods = 0;
    display "INFO: Duplikering/interpolation af perioder ophæves."
  );
  MasterIterMax = MasterIterMax + 1;
  execute_unload "MECmain.gdx";
ElseIf (OnDeAggr),
  display "INFO: STOP After DeAggregation";
  break;
ElseIf (stop NE 0),
  display "INFO: Generelt STOP hvis stop = TRUE", stop;
  break;
ElseIf (MasterIterMax GE 3),
  # Check at mindst eet nyt anlæg er globalt aktivt hvis master-iterationen kan fortsætte.
  NactiveNewPlant = sum(unewuq $OnUGlobal(unewuq), 1);
  display NactiveNewPlant;
  if (NactiveNewPlant EQ 0,
    display "WARNING: NactiveNewPlant er lig nul, og master-iteration giver ikke mening, og kørslen stoppes.", NactiveNewPlant;
    ConvergenceCode(iter) = 999.2;
    stop = 1;
    break;
  );
);

); # loop iter ...

execute_unload "MECmain.gdx";

#end Master iterationer

