* This file is intended for inclusion during compile of <project> model.
* It sets options for the GAMS solver.

$OffListing


if (OnTracing, 
  option solPrint = ON;
  option LIMROW=250;
  option LIMCOL=25;
else
  option solPrint = OFF;
  option LIMROW=0;
  option LIMCOL=0;
);

option reslim = 60;

option MIP = gurobi


