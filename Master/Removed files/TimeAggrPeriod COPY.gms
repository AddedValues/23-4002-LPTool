$log Entering file: %system.incName%

#begin Tidsaggregering af parametre

# Tidsaggregering af parametre kan koste adskillige minutter at udføre i GAMS formulering.
# Derfor udføres den såvidt muligt kun een gang ved første masteriteration (MasterIter=2) og persisteres på en gdx-fil for indlæsning i efterfølgende masteriterationer.
# Tidsaggregeringen er principielt periodeafhængig pga. elprisfremskrivningerne, og derfor dannes en gdx-fil for hver periode fx TimeAggrParms_14.gdx for periode 14.
# Ved indlæsning kopieres gdx-filen for den aktuelle periode til en fil med navnet TimeAggrParms_Actual.gdx.
# Denne omstændelige procedure skyldes alene den ekstremt begrænsede teksthåndtering i GAMS modelsproget.
                                    

if (NOT UseTimeAggr,               

  #begin No time aggregation, just 1-on-1 mapping.

  # Parametre som indtil videre er tidsuafhængige.
  Tfrem(tt)               = Tfrem_hh(tt);

  # Tidsafhængige parametre.

  ElspotActual(tt)        = ElspotActual_hh(tt);
  TariffElecU(tt,u)       = TariffElecU_hh(tt,u);
  TariffEigenU(tt,u)      = TariffEigenU_hh(tt,u);
  TariffEigenPump(tt)     = TariffEigenPump_hh(tt);
  TariffDsoLoad(tt)       = TariffDsoLoad_hh(tt);
  QmaxPtX(tt)              = QmaxPtX_hh(tt);
  QDemandActual(tt,net)   = QDemandActual_hh(tt,net);
  #--- dQExt(tt,produExtR)     = dQExt_hh(tt,produExtR);
  RevisionActual(tt,cp)   = RevisionActual_hh(tt,cp);
  COP(tt,hp)              = COP_hh(tt,hp);
  QhpYield(tt,hp)         = QhpYield_hh(tt,hp);
  alphaT(tt,tr,trkind)    = alphaT_hh(tt,tr,trkind);
  
  #end No time aggregation, just 1-on-1 mapping.
  
  
elseif (UseTimeAggr),

  #begin Time aggregation active

  #begin Beregn aggregering af periode-AFHÆNGIGE parametre (udføres for hver periode i første masteriteration).

  # Parametre som indtil videre er tidsuafhængige.

  #--- GasPriceSum         = 0.0;
  #--- dQExtSum(produExtR) = 0.0;
  #--- Tfrem(tt) = Tfrem_hh(tt);

  ElspotSum           = 0.0;                                           
  QdemSum(net)        = 0.0;                                           
  Found =  0;
  iblock = 1;
  actb(tta) = ord(tta) EQ iblock;
  loop (tt,
    #--- GasPriceSum         = GasPriceSum       + GasPriceActual_hh(tt);
    #--- dQExtSum(produExtR) = dQExtSum(produExtR) + dQExt_hh(tt,produExtR);

    ElspotSum         = ElspotSum         + ElspotActual_hh(tt);       
    QdemSum(net)      = QdemSum(net)      + QDemandActual_hh(tt,net);  
    
    if (ord(tt) EQ Bend(actb), 
      # Beregn middelværdien hhv. sum over tidsblokken.
      ActualBlockLen = BLen(actb);
      ElspotActual(actb)        = ElspotSum   / ActualBlockLen;        
      QDemandActual(actb,net)   = QdemSum(net);                        

      #--- GasPriceActual(actb)      = GasPriceSum / ActualBlockLen;
      #--- dQExt(actb,produExtR)     = dQExtSum(produExtR);
      
      iblock = iblock + 1;
      actb(tta) = ord(tta) EQ iblock;
      ElspotSum           = 0.0;                                       
      QdemSum(net)        = 0.0;                                       

      #--- GasPriceSum         = 0.0;
      #--- dQExtSum(produExtR) = 0.0;
    );
  );
  
  #end   Beregn aggregering af periode-AFHÆNGIGE parametre (udføres for hver periode i første masteriteration).
  

  if ((AggrKind EQ 0 AND ActualPeriod EQ PeriodFirst) OR (AggrKind NE 0),

    #begin Beregn aggregering af periode-UAFHÆNGIGE parametre.

    TariffDsoLoadSum     = 0.0;
    TariffElecUSum(u)    = 0.0;
    TariffEigenUSum(u)   = 0.0;
    TariffEigenPumpSum   = 0.0;
    RevisionSum(cp)      = 0.0;
    CopSum(hp)           = 0.0;
    QhpYieldSum(hp)      = 0.0;
    QmaxPtXSum            = 0.0;
    alphaTSum(tr,trkind) = 0.0;
    
    Found =  0;
    iblock = 1;
    actb(tta) = ord(tta) EQ iblock;
    loop (tt,

      TariffDsoLoadSum     = TariffDsoLoadSum     + TariffDsoLoad_hh(tt);
      TariffElecUSum(u)    = TariffElecUSum(u)    + TariffElecU_hh(tt,u);
      TariffEigenUSum(u)   = TariffEigenUSum(u)   + TariffEigenU_hh(tt,u);
      TariffEigenPumpSum   = TariffEigenPumpSum   + TariffEigenPump_hh(tt);
      RevisionSum(cp)      = RevisionSum(cp)      + RevisionActual_hh(tt,cp);
      CopSum(hp)           = CopSum(hp)           + COP_hh(tt,hp);
      QhpYieldSum(hp)      = QhpYieldSum(hp)      + QhpYield_hh(tt,hp);
      QmaxPtXSum            = QmaxPtXSum            + QmaxPtX(tt);
      alphaTSum(tr,trkind) = alphaTSum(tr,trkind) + alphaT_hh(tt,tr,trkind);
  
      if (ord(tt) EQ Bend(actb), 
        # Beregn middelværdien eller summen over tidsblokken.
        ActualBlockLen = BLen(actb);

        TariffDsoLoad(actb)     = TariffDsoLoadSum     / ActualBlockLen;
        TariffElecU(actb,u)     = TariffElecUSum(u)    / ActualBlockLen;
        TariffEigenU(actb,u)    = TariffEigenUSum(u)   / ActualBlockLen;
        TariffEigenPump(actb)   = TariffEigenPumpSum   / ActualBlockLen;
        RevisionActual(actb,cp) = RevisionSum(cp)      / ActualBlockLen;
        COP(actb,hp)            = CopSum(hp)           / ActualBlockLen;
        QhpYield(actb,hp)       = QhpYieldSum(hp)      / ActualBlockLen;
        QmaxPtX(actb)            = QmaxPtXSum            / ActualBlockLen;
        alphaT(actb,tr,trkind)  = alphaTSum(tr,trkind) / ActualBlockLen;
  
        # Check at skiftetider (diskrete skift) for udetider er taget i ed (værdi skal være enten 0 eller 1).
        loop (cp $OnUGlobal(cp),
          if (abs(abs(RevisionActual(actb,cp) - 0.5) - 0.5) GT 1E-2, display "RevisionActual har fejl i aggregering i blok actb", actb; Found = 1; );
        );
        
        iblock = iblock + 1;
        actb(tta) = ord(tta) EQ iblock;
  
        TariffDsoLoadSum     = 0.0;
        TariffElecUSum(u)    = 0.0;
        TariffEigenUSum(u)   = 0.0;
        TariffEigenPumpSum   = 0.0;
        RevisionSum(cp)      = 0.0;
        CopSum(hp)           = 0.0;
        QhpYieldSum(hp)      = 0.0;
        QmaxPtXSum            = 0.0;
        alphaTSum(tr,trkind) = 0.0;
      );
    );
    
    if (Found, 
      execute_unload "MecLpMain.gdx";
      display "ERROR in %system.incName%"; 
      abort "ERROR: Fejl i aggregering af diskrete skift. Se listing ovenfor."; 
    );
  
    #end Beregn aggregering af periode-uafhængige parametre (udføres for første periode i første masteriteration).
    
  );  # if ( (AggrKind EQ 0 AND ActualPeriod EQ PeriodFirst) OR (AggrKind NE 0),  #--- )
  
  else  # Aggregeringen er uændret.
    display "INFO: Aggregeringen er uændret fra forrige periode.";

  #end Time aggregation active
 
);  # if (NOT UseTimeAggr,  #--- )


# Opsætning af månedsbaserede tidspunkter. 
MonthTimeAccumAggr(mo) = MonthHoursAccum(mo);

if (UseTimeAggr,
  # Bestem aggr. starttidspunkt for hver måned.
  tmp = 0;   # Angiver aggr. tidspunkt tal for slutning af foregående måned.
  loop (mo,
    # Tidsaggregeringen har blokgrænse på hvert månedsskift.
    Found = FALSE;

$OffOrder    
    loop (t $(ord(t) GT tmp),
      if (Bend(t) EQ MonthHoursAccum(mo),
        MonthTimeAccumAggr(mo) = ord(t);
        tmp = ord(t);
        Found = TRUE;
        break;
      );
    );
$OnOrder    

    if (NOT Found,
      execute_unload "MecLpMain.gdx";
      abort "ERROR: MonthTimeAccumAggr kan ikke beregnes, Bend mangler månedsskift."
    );  
  );
);
display "INFO: MonthTimeAccumAggr", MonthTimeAccumAggr, MonthHoursAccum;

#end Tidsaggregering

# Beregn om begge eksisterende affaldsanlæg er til rådighed til et givet tidspunkt.
BothAffAvailable(t) = RevisionActual(t,'MaAff1') EQ 0 AND RevisionActual(t,'MaAff2') EQ 0;

