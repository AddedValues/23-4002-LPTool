$OnText
 Fil til GAMS $batInclude control option ifm. DIN-forsyning model.

 Arg1:  model navn  (uden pings)
 Arg2:  master iteration som set member  (uden pings).
 Arg3:  navn på modtagende parametger (uden pings)
  
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
%3('Gap', %2)            = 1 - %3('Objective', %2) / %3('ObjectiveBest', %2);
%3('SumInfeas', %2)      = ifthen(%1.sumInfes NE 0, %1.sumInfes, EPS);

#- StatsMaster('DateTime', %2)       = jnow + 1;
#- StatsMaster('ModelStat', %2)      = %1.ModelStat;
#- StatsMaster('SolveStat', %2)      = %1.SolveStat;
#- StatsMaster('TimeSolve', %2)      = %1.etSolve;
#- StatsMaster('TimeSolverOnly', %2) = %1.etSolver;
#- StatsMaster('NIteration', %2)     = %1.iterUsd;
#- StatsMaster('NVar', %2)           = %1.numVar;
#- StatsMaster('NDiscrVar', %2)      = %1.numDvar;
#- StatsMaster('NEquation', %2)      = %1.numEqu;
#- StatsMaster('NInfeas', %2)        = ifthen(%1.numInfes NE 0, %1.numInfes, EPS);
#- StatsMaster('Objective', %2)      = ifthen(%1.objVal NE 0, %1.objVal, EPS);
#- StatsMaster('ObjectiveBest', %2)  = ifthen(%1.objEst NE 0, %1.objEst, EPS);
#- StatsMaster('Gap', %2)            = 1 - StatsMaster('Objective', %2) / StatsMaster('ObjectiveBest', %2);
#- StatsMaster('SumInfeas', %2)      = ifthen(%1.sumInfes NE 0, %1.sumInfes, EPS);

#- StatsMasterIter('DateTime')       = jnow + 1;
#- StatsMasterIter('ModelStat')      = %1.ModelStat;
#- StatsMasterIter('SolveStat')      = %1.SolveStat;
#- StatsMasterIter('TimeSolve')      = %1.etSolve;
#- StatsMasterIter('TimeSolverOnly') = %1.etSolver;
#- StatsMasterIter('NIteration')     = %1.iterUsd;
#- StatsMasterIter('NVar')           = %1.numVar;
#- StatsMasterIter('NDiscrVar')      = %1.numDvar;
#- StatsMasterIter('NEquation')      = %1.numEqu;
#- StatsMasterIter('NInfeas')        = ifthen(%1.numInfes NE 0, %1.numInfes, EPS);
#- StatsMasterIter('Objective')      = ifthen(%1.objVal NE 0, %1.objVal, EPS);
#- StatsMasterIter('ObjectiveBest')  = ifthen(%1.objEst NE 0, %1.objEst, EPS);
#- StatsMasterIter('Gap')            = 1 - StatsMasterIter('Objective') / StatsMasterIter('ObjectiveBest');
#- StatsMasterIter('SumInfeas')      = ifthen(%1.sumInfes NE 0, %1.sumInfes, EPS);


