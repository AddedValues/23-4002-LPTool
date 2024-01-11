$log Entering file: %system.incName%

display '>>>>>>>>>>>>>>>>  ENTERING %system.incName%  <<<<<<<<<<<<<<<<<<<';


*begin Udfør optimering af slave-model

execute_unload "MecLpMain.gdx";

modelSlave.optFile = 1;
$include options.inc

solve modelSlave maximizing zSlave using MIP;

pModelStat = modelSlave.ModelStat; display pModelStat;

$batInclude 'SaveSolverState.gms' modelSlave

If (pModelStat EQ 3, 
  display "Solveren overskred tidsbegrænsningen. Se option .reslim hhv. option for den specifikke solver.";
ElseIf (pModelStat GT 2 AND pModelStat NE 8), 
  execute_unload "MEC_SlaveSolveFailed.gdx";
  display pModelStat;
  abort "Solve af slave model mislykkedes. Model skrevet til: MEC_SlaveSolveFailed.gdx";
);

*end Udfør optimering af slave-model
  


*begin Post calculation of results.
$OffOrder
# MBL: Hvis startomk = 0, så er bStart arbitrært 0 eller 1. Derfor beregnes korrekte værdier for start(ON=1) og stop (ON=2) herunder.
bStartStop(t,upr,startstop) = 0;
loop (upr $OnUGlobal(upr),
  loop (tt $(ord(tt) GE TimeBegin AND ord(tt) LE TimeEnd),
    if (ord(tt) EQ TimeBegin AND ord(rhStep) EQ 1,  # Første time i første RHoriz.
      bStartStop(tt,upr,'start') = bOn.L(tt,upr);
    elseif (bOn.L(tt,upr) GT bOn.L(tt-1,upr)), 
      bStartStop(tt,upr,'start') = 1;
    elseif (bOn.L(tt,upr) LT bOn.L(tt-1,upr)), 
      bStartStop(tt,upr,'stop') = 2;
    );
  );
);
$OnOrder
*end   Post calculation of results.
