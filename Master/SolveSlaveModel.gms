$log Entering file: %system.incName%

display '>>>>>>>>>>>>>>>>  ENTERING %system.incName%  <<<<<<<<<<<<<<<<<<<';

# Lås ikke-aktive anlæg.
loop (upr $(NOT OnUGlobal(upr)),
  bOn.fx(t,upr)      = 0;
  bStart.fx(t,upr)   = 0;
  Q.fx(t,upr)        = 0;
  PowInU.fx(t,upr)   = 0;
  FuelCost.fx(t,upr) = 0;
);

loop (u $(NOT OnUGlobal(u)),
  TotalCostU.fx(t,u) = 0;
);

loop (kv $(NOT OnUGlobal(kv)),
  ElSales.fx(t,kv)       = 0.0;
  #--- ElTilskud.fx(t,kv)     = 0.0;
  TotalElIncome.fx(t,kv) = 0.0;
);

  
# Gør brændselsomkostninger for ikke-eldrevne anlæg ikke-negativ.
TotalCostU.lo(t,vak) = 0.0;
loop (uq $OnUGlobal(uq),
  # Anlæg, som ikke drives af el, har ikke-negativ brændselspris hhv. totale marginalomkostninger.
  if (FuelMix(uq,'Elec'),
    FuelCost.lo(t,uq)   = -INF;
    TotalCostU.lo(t,uq) = -INF;
  else
    FuelCost.lo(t,uq)   = 0;
    TotalCostU.lo(t,uq) = 0;
  );
);

# Transmission always on at any time if the line is available.
bOnT.fx(t,tr) = 1 $OnTrans(tr);

#begin Opsætning af anlægsaktivitet bOn.

# Tildeling af anlægstilstand forud for aktuelle RH. Nødvendigt for kunne referere tilbage til foregående RH i slave-modellen.
# StateU indeholder tilstanden på timebasis, dvs. anlægsaktivitet 
loop (upr,
  if (OnUGlobal(upr), 
    if (ord(rhStep) EQ 1,
      loop (tt $(ord(tt) EQ 1),          # Første tidspunkt i første rullende horisont (RH).
        bOnPrevious(upr)    = StateU(upr,'start') NE 0; 
        #--- PowInUPrevious(upr) = StateU(upr,'start') * PowInUMax(upr) * BLenRatio('t1');  # Aktivitetsniveau skal bringes til aktuel tidsopløsning.
        PowInUPrevious(upr) = StateU(upr,'start') * PowInUMax(upr);
      );
    else                                 # Efterfølgende RH 'kigger' tilbage på foregående RHs sidste tidspunkt.
      loop (tt $(ord(tt) EQ TimeBegin-1),
        bOn.fx(tt,upr)      = bOn.L(tt,upr);  
        bOnPrevious(upr)    = bOn.L(tt,upr);  
        #--- PowInUPrevious(upr) = PowInU.L(tt,upr) * BLenRatio(tt+1);    # Aktivitetsniveau skal bringes på timebasis og dernæst til aktuel tidsopløsning.
        PowInUPrevious(upr) = PowInU.L(tt,upr);
      );
    );
	
    # Optional fiksering af anlægstilstand i sidste tidspunkt af sidste RH-step.
    if (ord(rhStep) GE nRHstep + 1,
      #--- display "DEBUG: SolveSlaveModel rhStep = nRHstep + 1";
      loop (tt $(ord(tt) EQ TimeEnd),
        ordtt = ord(tt);
        # Negativ state angiver at den skal holdes fri (dvs. ikke fikseres).
        if (StateU(upr,'slut') GE 0.0, PowInU.fx(tt,upr) = StateU(upr,'slut') * PowInUMax(upr); );
      );
    );

  else  # Anlæg ikke til rådighed.
    bOnPrevious(upr) = 0.0;
  );

  bOnPreviousRH(upr,actRHstep)    = bOnPrevious(upr);
  PowInUPreviousRH(upr,actRHstep) = PowInUPrevious(upr);
);

#end 

#--- abort.noerror "BEVIDST STOP I SolveSlaveModel";

#begin Opsætning af VAK aktivitet.
$OffOrder

loop (vak,
  if (OnUGlobal(vak),
    # Fiksering af VAK-beholdning før første tidspunkt og i sidste tidspunkt af planperioden. 
    # Fiksering i periodens første og sidste tidspunkt gives ved StateU.
    # I de mellemliggende RH fikseres tankbeholdning i sidste time af forrige RH-step til udgangspunktet.

    if (ord(rhStep) EQ 1, 
      #--- display "DEBUG: SolveSlaveModel rhStep = 1";
      loop (t $(ord(t) EQ 1),         # Tag kun det første tidspunkt i den første rullende horisont (RH).
        # Ingen fiksering, men fastlæggelse af foregående lagerniveau, som ikke kan være frit.
        LVakPrevious(vak) = StateU(vak,'start') * CapQU(vak); 
      );    

    elseif (ord(rhStep) GE 2 AND ord(rhStep) LT nRHstep + 1),
      # Fiksering af vak-ladninger til værdien fra sidste time af forrige RH-step. Bemærk loop over tt fremfor t, da t ikke kan "kigge" bagud i tid.
      #--- display "DEBUG: SolveSlaveModel 1 < rhStep < nRHstep + 1";
      loop (tt $(ord(tt) EQ TimeBegin-1),
        LVak.fx(tt,vak)   = LVak.L(tt,vak); 
        LVakPrevious(vak) = LVak.L(tt,vak);  # Fastholder VAK-beholdningen i forrige RH til brug for slave-modellen.
      );
    );
      
    # Optional fiksering af vak-ladninger i sidste tidspunkt af sidste RH-step.
    if (ord(rhStep) GE nRHstep + 1,
      #--- display "DEBUG: SolveSlaveModel rhStep = nRHstep + 1";
      loop (tt $(ord(tt) EQ TimeEnd),
        ordtt = ord(tt);
        # Negativ state angiver at den skal holdes fri.
        if (StateU(vak,'slut') GE 0.0, LVak.fx(tt,vak) = StateU(vak,'slut') * CapQU(vak); );
      );
    );

  else                            # VAK er ikke til rådighed.
    LVak.fx(t,vak)    = 0.0;
    Q.fx(t,vak)       = 0.0;
    LVakPrevious(vak) = 0.0;
  );
  
  LVakPreviousRH(vak,actRHstep) = LVakPrevious(vak);
);

$OnOrder

#end

# Tvangskørsler på diverse anlæg (priority)
loop (forcedOnUpr $OnUGlobal(forcedOnUpr), 
  loop (cp $(OnUGlobal(cp) AND sameas(forcedOnUpr,cp)),
    bOn.fx(t,cp) = 1.0 $OnU(t,cp); 
  );
);


#begin Låsning af ikke-bidragende anlæg til kapacitetsreservationer

loop (uelec $OnUGlobal(uelec),
  loop (updown,
    if (NOT CapEAvail(uelec,updown), CapEAlloc.fx(t,uelec,updown) = 0.0; );
  );
);

#end


# Generel opsætning af rolling horizon
display "Generel opsætning af rolling horizon i SolveSlaveModel.gms"
if (ord(rhStep) GE 2,
  # Fiksering af aktiviteter i sidste time time af forrige RH-step, så det efterfølgende RH-step ikke ændrer dem.
  loop (tt $(ord(tt) EQ TimeBegin-1),
    bOn.fx(tt,upr) = round(bOn.L(tt,upr), 0);
  );
);

# Øvre grænse på varmemæssig infeasibility.
QInfeas.up(t,net,InfeasDir) = BLen(t) * QInfeasMax;  # Øvre grænse på virtuel varmedræn.

# Der er ingen tilskud til klassisk elproduktion i DK.
#--- ElTilskud.fx(tt,kv) = 0.0;

#begin Store grænser for at detektere unbounded model.

# OBS Upper bound sættes kun hvis modellen viser sig at være unbounded, ellers forstyrrer det solveren.

if (FALSE,
  TotalCO2Emis.up(tt,net,co2kind)          = BIG;  # 'Samlede regulatoriske CO2-emission [ton/h]';
  TotalCO2EmisSum.up(net,co2kind)          = BIG;  # 'Sum af regulatorisk CO2-emission [ton]';
  CO2KvoteOmkst.up(tt,upr) $OnUGlobal(upr) = BIG;  # 'CO2 kvote omkostning [DKK]';
                                           
  Q.lo(tt,u)              $OnUGlobal(u)    = -BIG;  # 'Heat delivery from unit u';
  FuelCost.lo(tt,upr)     $OnUGlobal(upr)  = -BIG;  # 'Fuel cost til el bliver negativ, hvis elprisen går i negativ';
  TotalCostU.lo(tt,u)     $OnUGlobal(u)    = -BIG;
  TotalElIncome.lo(tt,kv) $OnUGlobal(kv)   = -BIG;
  ElSales.lo(tt,kv)       $OnUGlobal(kv)   = -BIG;  # 'Indtægt fra elsalg';
                                           
  Q.up(tt,u)              $OnUGlobal(u)    = +BIG;  # 'Heat delivery from unit u';
  FuelCost.up(tt,upr)     $OnUGlobal(upr)  = +BIG;  # 'Fuel cost til el bliver negativ, hvis elprisen går i negativ';
  TotalCostU.up(tt,u)     $OnUGlobal(u)    = +BIG;
  TotalElIncome.up(tt,kv) $OnUGlobal(kv)   = +BIG;
  ElSales.up(tt,kv)       $OnUGlobal(kv)   = +BIG;  # 'Indtægt fra elsalg';
                                           
  QT.up(tt,tr)                             = BIG;  # 'Transmitteret varme [MWq]';
  QTloss.up(tt,tr)                         = BIG;  # 'Transmissionsvarmetab [MWq]';
  CostPump.up(tt,tr)                       = BIG;  # 'Pumpeomkostninger';
  
  QCool.up(tt,ucool)          $OnUGlobal(ucool) = BIG;
  PowInU.up(tt,upr)           $OnUGlobal(upr)   = BIG;  # 'Indgivet effekt [MWf]';
  StartOmkst.up(tt,upr)       $OnUGlobal(upr)   = BIG;  # 'Startomkostning [DKK]';
  ElEgbrugOmkst.up(tt,upr)    $OnUGlobal(upr)   = BIG;  # 'Egetforbrugsomkostning [DKK]';
  VarDVOmkst.up(tt,u)         $OnUGlobal(u)     = BIG;
  DVOmkstRGK.up(tt,kv)        $OnUGlobal(kv)    = BIG;  # 'D&V omkostning relateret til RGK [DKK]';
  CostInfeas.up(tt,net)                         = BIG;  # 'Infeasibility omkostn. [DKK]';
  CostSrPenalty.up(tt,net)                      = BIG;  # 'Penalty på SR-varme [DKK]';
  TaxProdU.up(tt,upr,tax)     $OnUGlobal(upr)   = BIG;       
  TotalTaxUpr.up(tt, upr)     $OnUGlobal(upr)   = BIG;       
  CO2Emis.up(tt,upr,co2kind)  $OnUGlobal(upr)   = BIG;  # 'CO2 emission [kg]';
  FuelQty.up(tt,upr)          $OnUGlobal(upr)   = BIG;  # 'Drivmiddelmængde [ton]';
  FuelHeat.up(tt,kv)          $OnUGlobal(kv)    = BIG;  # 'Brændsel knyttet til varmeproduktion i KV-anlæg';
                                                
  Pnet.up(tt,kv)              $OnUGlobal(kv)    = BIG;  # 'Elproduktion af kraftvarmeværker';
  Pback.up(tt,kv)             $OnUGlobal(kv)    = BIG;
  Pbypass.up(tt,kv)           $OnUGlobal(kv)    = BIG;
  Qback.up(tt,kv)             $OnUGlobal(kv)    = BIG;
  Qbypass.up(tt,kv)           $OnUGlobal(kv)    = BIG;
  QRgk.up(tt,kv)              $OnUGlobal(kv)    = BIG;
  QbypassCost.up(tt,kv)       $OnUGlobal(kv)    = BIG;
                                                
  LVak.up(tt,vak)             $OnUGlobal(vak)   = BIG;  # 'Ladning på vak [MWh]';
  QMaxVak.up(tt,vak)          $OnUGlobal(vak)   = BIG;  # 'Øvre grænse på opladningseffekt';
  VakLoss.up(tt,vak)          $OnUGlobal(vak)   = BIG;  # 'Storage loss per hour';
  QVakAbs.up(tt,vak)          $OnUGlobal(vak)   = BIG;  # 'Absolut laderate for beregning af ladeomkostninger [MW]';
  Qbase.up(tt)                                  = BIG;  # 'Grundlastvarmeproduktion';
  QbasebOnSR.up(tt,netq)                        = BIG;  # 'Product af Qbase og bOnSR';

);  #

#end Store grænser for at detektere unbounded model.

$if not errorfree $exit

#end Initialisering af variable.


execute_unload "MecLpMain.gdx";


#begin Udfør optimering af slave-model

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

#end Udfør optimering af slave-model
  


#begin Post calculation of results.
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
#end   Post calculation of results.
