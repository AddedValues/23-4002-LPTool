$log Entering file: %system.incName%
$OnText
Projekt:    20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:    SetupSlaveModel.gms
Inkluderes af:  MecLpMain.gms
Argumenter:     <endnu ikke defineret>
Repository: GitHub: <none>
$OffText

display '>>>>>>>>>>>>>>>>  ENTERING %system.incName%  <<<<<<<<<<<<<<<<<<<';


Qf.up(t,ucool) = CapQU(ucool);


# Lås ikke-aktive anlæg.
loop (upr $(NOT OnUGlobal(upr)),
  bOn.fx(t,upr)      = 0;
  bStart.fx(t,upr)   = 0;
  Qf.fx(t,upr)        = 0;
  Ff.fx(t,upr)   = 0;
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

*begin Opsætning af anlægsaktivitet bOn for produktionsanlæg.

# Tildeling af anlægstilstand forud for aktuelle RH. Nødvendigt for kunne referere tilbage til foregående RH i slave-modellen.
# StateU indeholder tilstanden på timebasis, dvs. anlægsaktivitet 
loop (upr,
  if (OnUGlobal(upr), 
    if (ord(rhStep) EQ 1,
      if (StateU(upr,'start') GE 0.0,        # Negativt tal angiver uspecificeret starttilstand.
        loop (tt $(ord(tt) EQ 1),            # Første tidspunkt i første rullende horisont (RH).
          bOn.fx('t1',upr) = StateU(upr,'start') GT 0.0; 
          bOnPrevious(upr) = StateU(upr,'start') GT 0.0; 
          #--- FfInPrevious(upr) = StateU(upr,'start') * FfMax(upr) * BLenRatio('t1');  # Aktivitetsniveau skal bringes til aktuel tidsopløsning.
          FfInPrevious(upr) = StateU(upr,'start') * FfMax(upr);
        );
      );
    else                                 # Efterfølgende RH 'kigger' tilbage på foregående RHs sidste tidspunkt.
      loop (tt $(ord(tt) EQ TimeBegin-1),
        bOn.fx(tt,upr)      = bOn.L(tt,upr);  
        bOnPrevious(upr)    = bOn.L(tt,upr);  
        #--- FfInPrevious(upr) = Ff.L(tt,upr) * BLenRatio(tt+1);    # Aktivitetsniveau skal bringes på timebasis og dernæst til aktuel tidsopløsning.
        FfInPrevious(upr) = Ff.L(tt,upr);
      );
    );
    
    # Optional fiksering af anlægstilstand i sidste tidspunkt af sidste RH-step.
    if (ord(rhStep) GE nRHstep + 1,
      #--- display "DEBUG: SolveSlaveModel rhStep = nRHstep + 1";
      if (StateU(upr,'slut') GE 0.0,        # Negativt tal angiver uspecificeret sluttilstand.
        loop (tt $(ord(tt) EQ TimeEnd),
          Ff.fx(tt,upr) = StateU(upr,'slut') * FfMax(upr); 
        );
      );
    );

  else  # Anlæg ikke til rådighed.
    bOnPrevious(upr) = 0.0;
  );

  bOnPreviousRH(upr,actRHstep) = bOnPrevious(upr);
  FinPreviousRH(upr,actRHstep) = FfInPrevious(upr);
);

*end 


#--- abort.noerror "BEVIDST STOP I SolveSlaveModel";

*begin Opsætning af VAK aktivitet.
$OffOrder

loop (vak,
  if (OnUGlobal(vak),
    # Fiksering af VAK-beholdning før første tidspunkt og i sidste tidspunkt af planperioden. 
    # Fiksering i periodens første og sidste tidspunkt gives ved StateU.
    # I de mellemliggende RH fikseres tankbeholdning i sidste time af forrige RH-step til udgangspunktet.

    if (ord(rhStep) EQ 1, 
      #--- display "DEBUG: SolveSlaveModel rhStep = 1";
      if (StateU(vak,'start') GT 0.0,
        loop (tt $(ord(tt) EQ 1),         # Tag kun det første tidspunkt i den første rullende horisont (RH).
          # remove Ingen fiksering, men fastlæggelse af foregående lagerniveau, som ikke kan være frit.
          Evak.fx(tt,vak)   = max(DataU(vak,'VakMin'), min(StateU(vak,'start'), DataU(vak,'VakMax'))) * CapQU(vak); 
          EvakPrevious(vak) = Evak.L(tt,vak);  # OBS Bør være uspecificeret.
        );    
      );    

    #--- elseif (ord(rhStep) GE 2 AND ord(rhStep) LT nRHstep + 1),
    else
      # Fiksering af vak-ladninger på deres værdi i sidste brugbare time af forrige RH-step. Bemærk loop over tt fremfor t, da t ikke kan "kigge" bagud i tid.
      #--- display "DEBUG: SolveSlaveModel 1 < rhStep < nRHstep + 1";
      loop (tt $(ord(tt) EQ TimeBegin-1),
        Evak.fx(tt,vak)   = Evak.L(tt,vak); 
        EvakPrevious(vak) = Evak.L(tt,vak);  # Fastholder VAK-beholdningen i forrige RH til brug for slave-modellen.
      );
    );
      
    # Optional fiksering af vak-ladninger i sidste tidspunkt af sidste RH-step.
    if (ord(rhStep) GE nRHstep + 1,
      #--- display "DEBUG: SolveSlaveModel rhStep = nRHstep + 1";
      if (StateU(vak,'slut') GT 0.0,
        loop (tt $(ord(tt) EQ TimeEnd),
          ordtt = ord(tt);
          Evak.fx(tt,vak) = max(DataU(vak,'VakMin'), min(StateU(vak,'slut'), DataU(vak,'VakMax'))) * CapQU(vak); 
        );
      );
    );

  else                            # VAK er ikke til rådighed.
    Evak.fx(t,vak)    = 0.0;
    Qf.fx(t,vak)      = 0.0;
    EvakPrevious(vak) = 0.0;
  );
  
  EvakPreviousRH(vak,actRHstep) = EvakPrevious(vak);
);

$OnOrder

*end

# Tvangskørsler på diverse anlæg (priority)
loop (forcedOnUpr $OnUGlobal(forcedOnUpr), 
  loop (cp $(OnUGlobal(cp) AND sameas(forcedOnUpr,cp)),
    bOn.fx(t,cp) = 1.0 $OnU(t,cp); 
  );
);


*begin Låsning af ikke-bidragende anlæg til kapacitetsreservationer

loop (uelec $OnUGlobal(uelec),
  loop (dirResv,
    if (NOT CapFAvail(uelec,dirResv), CapFAlloc.fx(t,uelec,dirResv) = 0.0; );
  );
);

*end


# Generel opsætning af rolling horizon
display "Generel opsætning af rolling horizon i SolveSlaveModel.gms"
if (ord(rhStep) GE 2,
  # Fiksering af aktiviteter i sidste time time af forrige RH-step, så det efterfølgende RH-step ikke ændrer dem.
  loop (tt $(ord(tt) EQ TimeBegin-1),
    bOn.fx(tt,upr) = round(bOn.L(tt,upr), 0);
  );
);

# Øvre grænse på varmemæssig infeasibility.
QeInfeas.up(t,net,InfeasDir) = BLen(t) * QeInfeasMax;  # Øvre grænse på virtuel varmedræn.

# Der er ingen tilskud til klassisk elproduktion i DK.
#--- ElTilskud.fx(tt,kv) = 0.0;

*begin Store grænser for at detektere unbounded model.



# OBS Upper bound sættes kun hvis modellen viser sig at være unbounded, ellers forstyrrer det solveren.

if (TRUE,
  TotalCO2Emis.up(tt,net,co2kind) = BIG $OnNetGlobal(net);   # 'Samlede regulatoriske CO2-emission [ton/h]';
  TotalCO2EmisSum.up(net,co2kind) = BIG $OnNetGlobal(net);   # 'Sum af regulatorisk CO2-emission [ton]';
  CO2KvoteOmkst.up(tt,upr)        = BIG $OnUGlobal(upr);     # 'CO2 kvote omkostning [DKK]';
                           
  Qf.lo(tt,u)                 =  0.0;                   # 'Heat delivery from unit u';
  Qf.lo(tt,vak)               = -BIG $OnUGlobal(vak);   # 'Heat delivery from vak';
  FuelCost.lo(tt,upr)         = -BIG $OnUGlobal(upr);   # 'Fuel cost til el bliver negativ, hvis elprisen går i negativ';
  TotalCostU.lo(tt,u)         = -BIG $OnUGlobal(u);     
  TotalElIncome.lo(tt,kv)     = -BIG $OnUGlobal(kv);    
  ElSales.lo(tt,kv)           = -BIG $OnUGlobal(kv);    # 'Indtægt fra elsalg';
                                                        
  Qf.up(tt,u)                 = +BIG $OnUGlobal(u);     # 'Heat delivery from unit u';
  FuelCost.up(tt,upr)         = +BIG $OnUGlobal(upr);   # 'Fuel cost til el bliver negativ, hvis elprisen går i negativ';
  TotalCostU.up(tt,u)         = +BIG $OnUGlobal(u);
  TotalElIncome.up(tt,kv)     = +BIG $OnUGlobal(kv);
  ElSales.up(tt,kv)           = +BIG $OnUGlobal(kv);    # 'Indtægt fra elsalg';
                                                        
  QTf.up(tt,tr)               = BIG $OnTrans(tr);       # 'Transmitteret varme [MWq]';
  QTeLoss.up(tt,tr)           = BIG $OnTrans(tr);       # 'Transmissionsvarmetab [MWq]';
  CostPump.up(tt,tr)          = BIG $OnTrans(tr);       # 'Pumpeomkostninger';
  
  Ff.up(tt,upr)               = BIG $OnUGlobal(upr);    # 'Indgivet effekt [MWf]';
  StartOmkst.up(tt,upr)       = BIG $OnUGlobal(upr);    # 'Startomkostning [DKK]';
  ElEgbrugOmkst.up(tt,upr)    = BIG $OnUGlobal(upr);    # 'Egetforbrugsomkostning [DKK]';
  VarDVOmkst.up(tt,u)         = BIG $OnUGlobal(u);
  DVOmkstRGK.up(tt,kv)        = BIG $OnUGlobal(kv);     # 'D&V omkostning relateret til RGK [DKK]';
  CostInfeas.up(tt,net)       = BIG $OnNetGlobal(net);  # 'Infeasibility omkostn. [DKK]';
  CostSrPenalty.up(tt,net)    = BIG $OnNetGlobal(net);  # 'Penalty på SR-varme [DKK]';
  TaxProdU.up(tt,upr,tax)     = BIG $OnUGlobal(upr);       
  TotalTaxUpr.up(tt, upr)     = BIG $OnUGlobal(upr);         
  CO2Emis.up(tt,upr,co2kind)  = BIG $OnUGlobal(upr);    # 'CO2 emission [kg]';
  FuelQty.up(tt,upr)          = BIG $OnUGlobal(upr);    # 'Drivmiddelmængde [ton]';
  FeHeat.up(tt,kv)            = BIG $OnUGlobal(kv) ;    # 'Brændsel knyttet til varmeproduktion i KV-anlæg';
                                                        
  PfNet.up(tt,kv)             = BIG $OnUGlobal(kv);     # 'Elproduktion af kraftvarmeværker';
  PfBack.up(tt,kv)            = BIG $OnUGlobal(kv);     
  PfBypass.up(tt,kv)          = BIG $OnUGlobal(kv);     
  QfBack.up(tt,kv)            = BIG $OnUGlobal(kv);     
  QfBypass.up(tt,kv)          = BIG $OnUGlobal(kv);     
  QfRgk.up(tt,kv)             = BIG $OnUGlobal(kv);     
  QBypassCost.up(tt,kv)       = BIG $OnUGlobal(kv);     
                                                        
  Evak.up(tt,vak)             = BIG $OnUGlobal(vak);    # 'Ladning på vak [MWh]';
  QfMaxVak.up(tt,vak)         = BIG $OnUGlobal(vak);    # 'Øvre grænse på opladningseffekt';
  EvakLoss.up(tt,vak)         = BIG $OnUGlobal(vak);    # 'Storage loss per hour';
  QfVakAbs.up(tt,vak)         = BIG $OnUGlobal(vak);    # 'Absolut laderate for beregning af ladeomkostninger [MW]';
  QfBase.up(tt)               = BIG;                    # 'Grundlastvarmeproduktion';
  QfBasebOnSR.up(tt,netQ)     = BIG;  

);  #

*end Store grænser for at detektere unbounded model.

$if not errorfree $exit

*end Initialisering af variable.
