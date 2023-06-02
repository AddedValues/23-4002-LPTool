* This file is intended for inclusion during compile of <project> model.
* It sets options for the GAMS solver.

$OffListing

option reslim = 60;
option solPrint = OFF;
#--- option LIMROW=0, LIMCOL=0;

option solPrint = ON;
option LIMROW=250, LIMCOL=25;

option MIP = gurobi


