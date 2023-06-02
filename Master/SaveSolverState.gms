$log Entering file: %system.incName%

#begin Run stats fra solver
$OnText
 Fil til GAMS $batInclude control option ifm. MEC-forsyning model.

 Arg1:  model navn som erklæring i GAMS model stmt.

$OffText

$log arg1 = %1

StatsSolver('DateTime')       = jnow + 1;
StatsSolver('ModelStat')      = %1.ModelStat;
StatsSolver('SolveStat')      = %1.SolveStat;
StatsSolver('TimeSolve')      = %1.etSolve;
StatsSolver('TimeSolverOnly') = %1.etSolver;
StatsSolver('NIteration')     = %1.iterUsd;
StatsSolver('NVar')           = %1.numVar;
StatsSolver('NDiscrVar')      = %1.numDvar;
StatsSolver('NEquation')      = %1.numEqu;
StatsSolver('NInfeas')        = ifthen(%1.numInfes NE 0, %1.numInfes, EPS);
StatsSolver('Objective')      = ifthen(%1.objVal NE 0, %1.objVal, EPS);
StatsSolver('ObjectiveBest')  = ifthen(%1.objEst NE 0, %1.objEst, EPS);
StatsSolver('Gap')            = 1 - StatsSolver('Objective') / StatsSolver('ObjectiveBest');
StatsSolver('SumInfeas')      = ifthen(%1.sumInfes NE 0, %1.sumInfes, EPS);

StatsInfeas(t,net,InfeasDir) = QInfeas.L(t,net,InfeasDir);

#end Run stats fra solver

#TODO Erstat med embedded python kode til omdøbning af udskrevne filer fra denne .gms fil.

#end
