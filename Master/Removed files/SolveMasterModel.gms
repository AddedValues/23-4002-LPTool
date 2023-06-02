$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        SolveMasterModel.gms
Scope:          Udfører optimering af master model.
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText

#begin solve fasen for Master-modellen

option threads = 1;
option reslim  = 1E+6;
#--- option MIP = cplex;
option MIP = gurobi;
option solPrint = ON; # = %oMasterSolPrint%;
option LIMROW=50, LIMCOL=50;
modelMaster.optFile = 1;

solve modelMaster maximizing zMaster using MIP;


#TODO Denne blok bør udskilles som batInclude-fil, da den repeteres ved Alfa-version 4 længere nede.
#TODO Blokken kan indlejres i SaveMasterResults.gms

$batInclude 'SaveMasterResults.gms' modelMaster iter StatsMaster
display StatsMaster;
display zMaster.L, dCapU.L, zMaster.L, CapU.L, CapUExcess.L;

# Penalty på overflødig kapacitet "betales tilbage" til den reelle objektfunktion.
zMasterIter(iter)               = zMaster.L;
MasObjIter(iter)                = zMaster.L + sum(per, MasPenaltyCost.L(per));
MasCapU(unew,per,iter)          = CapU.L(unew,per) $OnUPer(unew,per);
MasdCapU(unew,per,iter)         = dCapU.L(unew,per) $OnUPer(unew,per);
ExcessCapUIter(net,per,iter)    = max(tiny, CapUExcess.L(net,per));
dCapUCostIter(per,iter)         = dCapUCost.L(per);
dMargObjUIter(per,iter)         = dMargObjU.L(per);
CapUIter(unew,per,iter)         = CapU.L(unew,per) $OnUPer(unew,per);
dCapUIter(unew,per,iter)        = dCapU.L(unew,per) $OnUPer(unew,per);
dCapUOfzIter(unew,per,iter)     = dCapUOfz.L(unew,per) $OnUPer(unew,per);
dCapUOfzAggrIter(unew,per,iter) = dCapUOfzAggr.L(unew,per) $OnUPer(unew,per);
MasPenaltyCostActual(iter)      = sum(per, MasPenaltyCost.L(per));

# Opsamling af antal anlægsprojekter.
NProjNetIter(net,iter)         = NProjNet.L(net);
NProjUIter(unew,iter)          = NProjU.L(unew);
bOnInvestUIter(unew,perA,iter) = bOnInvestU.L(unew,perA);

#begin Individuel tilpasning af stepvektor grænser.

#--- display "DEBUG BEFORE:", AlfaVersion, dCapUMaxPer, AlfaIndi;

# Hvis alfaversion = 4 eller = 5, så kør master igen hvor AlfaIndi(viduel) modificeres for unew hvor dCapUOfz har skiftet fortegn ift. forrige masteriteration.

If ( [(AlfaVersion EQ 4 OR AlfaVersion EQ 5 OR AlfaVersion EQ 6) AND stop EQ 0 AND ord(iter) GT 2],
  loop (per,
    loop (unew $OnUPer(unew,per),
      if ( dCapUOfzIter(unew,per,iter-1) * dCapUOfzIter(unew,per,iter) LT 0.0,             # Fortegnsskift i dCapUOfz ift. forrige masteriteration.
        AlfaIndi(unew,per) = AlfaIndi(unew,per) * AlfaReducIndiv;

        #'--- if ( dCapUInitPer(unew,per) * AlfaIndi(unew,per) LT 1,                       '
        #'---   AlfaIndi(unew,per) = min(AlfaIndi(unew,per),  1.0 / dCapUInitPerMax(unew));'
        #'--- );                                                                           '

        #--- if ( dCapUMaxInitPer(unew,per) * AlfaIndi(unew,per) LT 0.25,
        #---   AlfaIndi(unew,per) = 1 / dCapUMaxInitPer(unew,per);
        #--- );
        
        #'--- if ( dCapUInitPer(unew,per) * AlfaIndi(unew,per) LT 1,     '
        #'---   AlfaIndi(unew,per) = AlfaReducIndiv * AlfaIndi(unew,per);'
        #'--- );                                                         '
        
      ElseIf (dCapUOfzIter(unew,per,iter-1) * dCapUOfzIter(unew,per,iter) GT 0.0),
        #'--- AlfaIndi(unew,per) = min(1.0, AlfaIndi(unew,per) * 1.25);'
        AlfaIndi(unew,per) = min(1.0, AlfaIndi(unew,per) * AlfaExpandIndiv);
      );
    );
  );
  dCapUMaxPer(unew,perA) = dCapUMaxInitPer(unew,perA) * AlfaIndi(unew,perA); 


  option LIMROW=60, LIMCOL=60;
  #---- option LIMROW=0, LIMCOL=0;

  solve modelMaster maximizing zMaster using MIP;

  if (bestIter(iter), execute_unload "MECOptimSolution.gdx"; );

  #DISABLED # Put an entry into the GAMS log file:
  #DISABLED put gamslog / "Iter= ", MasterIter, ",  zMaster= ", zMaster.L  / ;

$batInclude 'SaveMasterResults.gms' modelMaster iter StatsMaster

  display StatsMaster;

  display zMaster.L, dCapU.L, zMaster.L, CapU.L, CapUExcess.L;

  # Penalty på overflødig kapacitet "betales tilbage" til den reelle objektfunktion.
  zMasterIter(iter)               = zMaster.L;
  MasObjIter(iter)                    = zMaster.L + sum(per, MasPenaltyCost.L(per));
  MasCapU(unew,per,iter)          = CapU.L(unew,per) $OnUPer(unew,per);
  MasdCapU(unew,per,iter)         = dCapU.L(unew,per) $OnUPer(unew,per);
  ExcessCapUIter(net,per,iter)    = CapUExcess.L(net,per);
  dCapUCostIter(per,iter)         = dCapUCost.L(per);
  dMargObjUIter(per,iter)         = dMargObjU.L(per);
  CapUIter(unew,per,iter)         = CapU.L(unew,per) $OnUPer(unew,per);
  dCapUIter(unew,per,iter)        = dCapU.L(unew,per) $OnUPer(unew,per);
  dCapUOfzIter(unew,per,iter)     = dCapUOfz.L(unew,per) $OnUPer(unew,per);
  dCapUOfzAggrIter(unew,per,iter) = dCapUOfzAggr.L(unew,per) $OnUPer(unew,per);
  MasPenaltyCostActual(iter)      = sum(per, MasPenaltyCost.L(per));

  # Opsamling af antal anlægsprojekter.
  NProjNetIter(net,iter)         = NProjNet.L(net);
  NProjUIter(unew,iter)          = NProjU.L(unew);
  bOnInvestUIter(unew,perA,iter) = bOnInvestU.L(unew,perA);

);
AlfaIndiIter(unew,per,iter) = AlfaIndi(unew,per);

#end   

#end solve fasen for Master-modellen
