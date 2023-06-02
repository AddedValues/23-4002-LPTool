$log Entering file: %system.incName%

#begin Tidsaggregering af parametre

# Tidsaggregering af parametre kan koste adskillige minutter at udføre i GAMS formulering.
# Derfor udføres den såvidt muligt kun een gang ved første masteriteration (MasterIter=2) og persisteres på en gdx-fil for indlæsning i efterfølgende masteriterationer.
# Tidsaggregeringen er principielt periodeafhængig pga. elprisfremskrivningerne, og derfor dannes en gdx-fil for hver periode fx TimeAggrParms_14.gdx for periode 14.
# Ved indlæsning kopieres gdx-filen for den aktuelle periode til en fil med navnet TimeAggrParms_Actual.gdx.
# Denne omstændelige procedure skyldes alene den ekstremt begrænsede teksthåndtering i GAMS modelsproget.
                                    
                                    

if (NOT UseTimeAggr AND NOT UseTimeExpansionAny,               

  #begin No time aggregation, just 1-on-1 mapping.

  # Parametre som indtil videre er tidsuafhængige.

  QDemandActual(tt,net)    = QDemandActual_hh(tt,net);
  ElspotActual(tt)         = ElspotActual_hh(tt);
  TariffDsoLoad(tt)        = TariffDsoLoad_hh(tt);
  TariffElecU(tt,u)        = TariffElecU_hh(tt,u);
  TariffEigenU(tt,u)       = TariffEigenU_hh(tt,u);
  TariffEigenPump(tt)      = TariffEigenPump_hh(tt);
  OnU(tt,u)                = OnU_hh(tt,u);
  THeatSource(tt,hpSource) = THeatSource_hh(tt,hpSource);
  COP(tt,hp)               = COP_hh(tt,hp);
  QhpYield(tt,hp)          = QhpYield_hh(tt,hp);
  QmaxPtX(tt)              = QmaxPtX_hh(tt);
  OnU(tt,u)                = OnU_hh(tt,u);
  alphaT(tt,tr,trkind)     = alphaT_hh(tt,tr,trkind);
  #--- GasPriceActual(tt)        = GasPriceActual_hh(tt);
  #--- dQExt(tt,produExtR)       = dQExt_hh(tt,produExtR);
  
  #end No time aggregation or expansion, just 1-on-1 mapping.

  
elseif (NOT UseTimeAggr AND UseTimeExpansionAny),      # Ingen tidsaggregering, men tidsekspansion.
  
  # Tildel parameterværdier til (evt. ekspanderede) tidspunkter. 
  # OBS Subset t(tt) er fastlagt i LoopRollHorizPre.gms.

  # Tildel forholdsmæssig andel af extensive (fx energier) og identiske værdier for intensive størrelser.
  loop (t,
    actt(tt) = ord(tt) EQ BBeg(t);     # BBeg angiver modeltimen, som det (evt. ekspanderede) tidspunkt t tilhører.
    #--- display "DEBUG: actt =", actt;
    QDemandActual(t,net)    = QDemandActual_hh(actt,net) * BLen(t);
    ElspotActual(t)         = ElspotActual_hh(actt);
    TariffDsoLoad(t)        = TariffDsoLoad_hh(actt);
    TariffElecU(t,u)        = TariffElecU_hh(actt,u);
    TariffEigenU(t,u)       = TariffEigenU_hh(actt,u);
    TariffEigenPump(t)      = TariffEigenPump_hh(actt);
    OnU(t,u)                = OnU_hh(actt,u);
    THeatSource(t,hpSource) = THeatSource_hh(actt,hpSource);
    COP(t,hp)               = COP_hh(actt,hp);
    QhpYield(t,hp)          = QhpYield_hh(actt,hp);
    QmaxPtX(t)              = QmaxPtX_hh(actt) * BLen(t); 
    alphaT(t,tr,trkind)     = alphaT_hh(actt,tr,trkind);
    #--- GasPriceActual(t)       = GasPriceActual_hh(actt);
    #--- dQExt(t,produExtR)      = dQExt_hh(actt,produExtR);
  );
  
elseif (UseTimeAggr AND NOT UseTimeExpansionAny),      # Tidsaggregering, men ingen tidsekspansion.
    
    #begin Tidsaggregering DEAKTIVERET
    abort "Tidsaggregering er p.t. deaktiveret";
    
    #--- GasPriceSum         = 0.0;
    #--- dQExtSum(produExtR) = 0.0;
    #--- Tfrem(tt) = Tfrem_hh(tt);
  
    ElspotSum            = 0.0;                                           
    QdemSum(net)         = 0.0;                                           
    TariffDsoLoadSum     = 0.0;
    TariffElecUSum(u)    = 0.0;
    TariffEigenUSum(u)   = 0.0;
    TariffEigenPumpSum   = 0.0;
    OnUSum(u)            = 0.0;
    CopSum(hp)           = 0.0;
    QhpYieldSum(hp)      = 0.0;
    QmaxPtXSum           = 0.0;
    alphaTSum(tr,trkind) = 0.0;
    
    Found =  0;
    iblock = 1;
    actb(tta) = ord(tta) EQ iblock;
    loop (tt,
      #--- GasPriceSum         = GasPriceSum + GasPriceActual_hh(tt);
      #--- dQExtSum(produExtR) = ... ;
    
      ElspotSum            = ElspotSum            + ElspotActual_hh(tt);
      QdemSum(net)         = QdemSum(net)         + QDemandActual_hh(tt,net);                                           
      TariffDsoLoadSum     = TariffDsoLoadSum     + TariffDsoLoad_hh(tt);
      TariffElecUSum(u)    = TariffElecUSum(u)    + TariffElecU_hh(tt,u);
      TariffEigenUSum(u)   = TariffEigenUSum(u)   + TariffEigenU_hh(tt,u);
      TariffEigenPumpSum   = TariffEigenPumpSum   + TariffEigenPump_hh(tt);
      OnUSum(u)            = OnUSum(u)            + OnU_hh(tt,u);
      CopSum(hp)           = CopSum(hp)           + COP_hh(tt,hp);
      QhpYieldSum(hp)      = QhpYieldSum(hp)      + QhpYield_hh(tt,hp);
      QmaxPtXSum           = QmaxPtXSum           + QmaxPtX(tt);
      alphaTSum(tr,trkind) = alphaTSum(tr,trkind) + alphaT_hh(tt,tr,trkind);
  
      if (ord(tt) EQ Bend(actb), 
        # Beregn middelværdien eller summen over tidsblokken.
        ActualBlockLen = BLen(actb);

        #--- GasPriceActual(actb)      = GasPriceSum / ActualBlockLen;
        #--- dQExt(actb,produExtR)     = dQExtSum(produExtR);

        ElspotActual(actb)      = ElspotSum            / ActualBlockLen;        
        QDemandActual(actb,net) = QdemSum(net);                        
        TariffDsoLoad(actb)     = TariffDsoLoadSum     / ActualBlockLen;
        TariffElecU(actb,u)     = TariffElecUSum(u)    / ActualBlockLen;
        TariffEigenU(actb,u)    = TariffEigenUSum(u)   / ActualBlockLen;
        TariffEigenPump(actb)   = TariffEigenPumpSum   / ActualBlockLen;
        OnU(actb,u)             = OnUSum(u)            / ActualBlockLen;
        COP(actb,hp)            = CopSum(hp)           / ActualBlockLen;
        QhpYield(actb,hp)       = QhpYieldSum(hp)      / ActualBlockLen;
        QmaxPtX(actb)            = QmaxPtXSum          / ActualBlockLen;
        alphaT(actb,tr,trkind)  = alphaTSum(tr,trkind) / ActualBlockLen;
  
        # Check at skiftetider (diskrete skift) for udetider er taget i ed (værdi skal være enten 0 eller 1).
        loop (u $OnUGlobal(u),
          if (abs(abs(OnU(actb,u) - 0.5) - 0.5) GT 1E-2, display "OnU har fejl i aggregering i blok actb", actb; Found = 1; );
        );
        
        iblock = iblock + 1;
        actb(tta) = ord(tta) EQ iblock;

        #--- GasPriceSum         = 0.0;
        #--- dQExtSum(produExtR) = 0.0;
  
        ElspotSum            = 0.0;                                       
        QdemSum(net)         = 0.0;                                       
        TariffDsoLoadSum     = 0.0;
        TariffElecUSum(u)    = 0.0;
        TariffEigenUSum(u)   = 0.0;
        TariffEigenPumpSum   = 0.0;
        OnUSum(u)            = 0.0;
        CopSum(hp)           = 0.0;
        QhpYieldSum(hp)      = 0.0;
        QmaxPtXSum           = 0.0;
        alphaTSum(tr,trkind) = 0.0;
      );
    );
    
    if (Found, 
      execute_unload "MecLpMain.gdx";
      display "ERROR in %system.incName%"; 
      abort "ERROR: Fejl i aggregering af diskrete skift. Se listing ovenfor."; 
    );
    #end Tidsaggregering DEAKTIVERET
);  # if (NOT UseTimeAggr AND NOT UseTimeExpansionAny,  #--- )

#begin DISABLED
#--- # Opsætning af månedsbaserede tidspunkter. 
#--- MonthTimeAccumAggr(mo) = MonthHoursAccum(mo);

#--- if (UseTimeAggr,
#---   # Bestem aggr. starttidspunkt for hver måned.
#---   tmp = 0;   # Angiver aggr. tidspunkt tal for slutning af foregående måned.
#---   loop (mo,
#---     # Tidsaggregeringen har blokgrænse på hvert månedsskift.
#---     Found = FALSE;
#--- 
#--- $OffOrder    
#---     loop (t $(ord(t) GT tmp),
#---       if (Bend(t) EQ MonthHoursAccum(mo),
#---         MonthTimeAccumAggr(mo) = ord(t);
#---         tmp = ord(t);
#---         Found = TRUE;
#---         break;
#---       );
#---     );
#--- $OnOrder    
#--- 
#---     if (NOT Found,
#---       execute_unload "MecLpMain.gdx";
#---       abort "ERROR: MonthTimeAccumAggr kan ikke beregnes, Bend mangler månedsskift."
#---     );  
#---   );
#--- );
#--- display "INFO: MonthTimeAccumAggr", MonthTimeAccumAggr, MonthHoursAccum;
#end DISABLED

#end Tidsaggregering

# Beregn om begge eksisterende affaldsanlæg er til rådighed til et givet tidspunkt.
BothAffAvailable(t) = OnU(t,'MaAff1') AND OnU(t,'MaAff2');


#begin Beregning af tidsafhængig elektrisk kapacitet for uelec anlæg.

loop (kv $OnUGlobal(kv),   CapEU(t,uelprod) $sameas(uelprod,kv)  = EtaPU(kv) * PowInUMax(kv);  );
loop (uek $OnUGlobal(uek), CapEU(t,uelcons) $sameas(uelcons,uek) = PowInUMax(uek); );
loop (hp $OnUGlobal(hp),   CapEU(t,uelcons) $sameas(uelcons,hp)  = PowInUMax(hp) / COP(t,hp); );  

#end




