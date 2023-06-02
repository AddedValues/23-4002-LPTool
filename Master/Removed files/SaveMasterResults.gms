$log Entering file: %system.incName%

$OnText
Projekt:        20-1004 SEP Sønderjylland - Analysefase.
Filnavn:        SaveMasterResults.gms
Scope:          Beregner og gemmer statistik for aktuel master iteration.
Inkluderes af:  SEPmain.gms
Argumenter:     <endnu ikke defineret>
                %1:  model navn  (uden pings)
                %2:  master iteration som set member  (uden pings).
                %3:  navn på modtagende parameter (uden pings)
$OffText

$OnText
 Fil til GAMS $batInclude control option ifm. SILK-forsyning model.

 Arg1:  model navn  (uden pings)
 Arg2:  master iteration som set member  (uden pings).
 Arg3:  navn på modtagende parameter (uden pings)
  
$OffText

%3('DateTime', %2)       = jnow + 1;
%3('ModelStat', %2)      = %1.ModelStat;
%3('SolveStat', %2)      = %1.SolveStat;
%3('TimeSolve', %2)      = %1.etSolve;
%3('TimeSolverOnly', %2) = %1.etSolver;
%3('NIteration', %2)     = %1.iterUsd;
%3('NVar', %2)           = %1.numVar;
%3('NDiscrVar', %2)      = %1.numDvar;
%3('NEquation', %2)      = %1.numEqu;
%3('NInfeas', %2)        = ifthen(%1.numInfes NE 0, %1.numInfes, EPS);
%3('Objective', %2)      = ifthen(%1.objVal NE 0, %1.objVal, EPS);
%3('ObjectiveBest', %2)  = ifthen(%1.objEst NE 0, %1.objEst, EPS);
if (%3('ObjectiveBest', %2) EQ 0.0,
  %3('Gap', %2) = 0.0;
else  
  %3('Gap', %2)            = 1 - %3('Objective', %2) / %3('ObjectiveBest', %2);
);
%3('SumInfeas', %2)      = ifthen(%1.sumInfes NE 0, %1.sumInfes, EPS);




