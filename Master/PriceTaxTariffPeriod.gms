$log Entering file: %system.incName%
$OnText
Projekt:        23-1002 MEC Mulighedsanalyse FF.
Filnavn:        PriceTaxTariffPeriod.gms
Scope:          Overfører indlæste data for mastermodel.
Inkluderes af:  MecLpMain.gms
Argumenter:     <endnu ikke defineret>
$OffText

*begin Braendsels og el-tariffer
# OBS Det antages at kun SR-anlæg kan være gasfyrede, ellers skal der differentieres mellem gastarifferne.
TariffFuelMWh('NGas')    = YS('TariffNgasSLK') / LhvMWhPerUnitFuel('NGas');
TariffFuelMWh('FGO')     = YS('TariffOil')     / Brandsel('FGO',    'Densitet') / LhvMWhPerUnitFuel('FGO');
TariffFuelMWh('BioOlie') = YS('TariffOil')     / Brandsel('BioOlie','Densitet') / LhvMWhPerUnitFuel('BioOlie');

TariffDsoAll('Alow', 'low' ) = YS('TariffDsoAlowLoadLow');
TariffDsoAll('Alow', 'high') = YS('TariffDsoAlowLoadHigh');
TariffDsoAll('Alow', 'peak') = YS('TariffDsoAlowLoadPeak');
TariffDsoAll('Ahigh','low' ) = YS('TariffDsoAhighLoadLow');
TariffDsoAll('Ahigh','high') = YS('TariffDsoAhighLoadHigh');
TariffDsoAll('Ahigh','peak') = YS('TariffDsoAhighLoadPeak');
TariffDsoAll('Blow', 'low')  = YS('TariffDsoBlowLoadLow');
TariffDsoAll('Blow', 'high') = YS('TariffDsoBlowLoadHigh');
TariffDsoAll('Blow', 'peak') = YS('TariffDsoBlowLoadPeak');
TariffDsoAll('Bhigh','low')  = YS('TariffDsoBhighLoadLow');
TariffDsoAll('Bhigh','high') = YS('TariffDsoBhighLoadHigh');
TariffDsoAll('Bhigh','peak') = YS('TariffDsoBhighLoadPeak');
TariffDsoAll('A0','low')     = 0;                    
TariffDsoAll('A0','high')    = 0;
TariffDsoAll('A0','peak')    = 0;

TariffDsoFeedIn('A0')        = 0;
TariffDsoFeedIn('Ahigh')     = YS('TariffElFeedInAHigh');
TariffDsoFeedIn('Alow')      = YS('TariffElFeedInALow');
TariffDsoFeedIn('Bhigh')     = YS('TariffElFeedInBHigh');
TariffDsoFeedIn('Blow')      = YS('TariffElFeedInBLow');

TariffElRaadighed('A0')      = 0;
TariffElRaadighed('Ahigh')   = YS('TariffElRaadighedAHigh');
TariffElRaadighed('Alow')    = YS('TariffElRaadighedALow');
TariffElRaadighed('Bhigh')   = YS('TariffElRaadighedBHigh');
TariffElRaadighed('Blow')    = YS('TariffElRaadighedBLow');

TariffElEffekt('A0')         = 0;
TariffElEffekt('Ahigh')      = YS('TariffElEffektAHigh');
TariffElEffekt('Alow')       = YS('TariffElEffektALow');
TariffElEffekt('Bhigh')      = YS('TariffElEffektBHigh');
TariffElEffekt('Blow')       = YS('TariffElEffektBLow');

# Beregn DSO-tariffen for hver DSO-kundetype (dso) og hver årstime som funktion af årstimens el-last niveau (loadDso).
TariffDso_hh(tt,dso) = sum(loadDso $(ord(loadDso) EQ TariffDsoLoad_hh(tt)), TariffDsoAll(dso,loadDso));

*begin Beregning af anlægsafhængige el-tariffer.
TariffElecU_hh(tt,u)   = YS('TariffElTSO')   + YS('TariffElTrade')                          + sum(dso $(ord(dso) EQ DataU(u,'DSO')), TariffDso_hh(tt,dso));
TariffEigenU_hh(tt,u)  = YS('TariffElTSO')   + YS('TariffElTrade')  + YS('TariffElProcess') + sum(dso $(ord(dso) EQ DataU(u,'DSO')), TariffDso_hh(tt,dso));
TariffEigenPump_hh(tt) = YS('TariffElTSO')   + YS('TariffElTrade')  + YS('TariffElProcess') + TariffDso_hh(tt,'BLow');
TariffElSellU(u)       = YS('TariffElTrade') + YS('TariffElFeedIn') + sum(dso $(ord(dso) EQ DataU(u,'DSO')), TariffDsoFeedIn(dso)); 
TariffElRaadighedU(u)  = sum(dso $(ord(dso) EQ DataU(u,'DSO')), TariffElRaadighed(dso));
TariffElEffektU(u)     = sum(dso $(ord(dso) EQ DataU(u,'DSO')), TariffElEffekt(dso));

*end
                                                                                          
*end Braendsels- og el-tariffer

*MBL: Kedel-afgifterne er baseret dels på brændselsmængde (m3, Liter), dels på varmeproduktionen (GJ).
TaxRateMWh('BioOlie','co2','kedel') = YS('TaxCO2BioOlieKedel') / Brandsel('BioOlie','Densitet') / LhvMWhPerUnitFuel('BioOlie');      # Convert from Liter to MWh base.
TaxRateMWh('BioOlie','nox','kedel') = YS('TaxNOxBioOlieKedel') / Brandsel('BioOlie','Densitet') / LhvMWhPerUnitFuel('BioOlie');      # Convert from Liter to MWh base.
TaxRateMWh('BioOlie','sox','kedel') = YS('TaxSOxBioOlie') / Brandsel('BioOlie','Densitet') / LhvMWhPerUnitFuel('BioOlie');           # Convert from Liter to MWh base.
TaxRateMWh('BioOlie','enr','kedel') = YS('TaxEnergiBioOlieKedel') / Brandsel('BioOlie','Densitet') / LhvMWhPerUnitFuel('BioOlie');   # Convert from Liter to MWh base.
TaxRateMWh('BioOlie','ets','kedel') = YS('TaxCO2Kvote') * CO2ProdTonMWh('BioOlie') ;
      
TaxRateMWh('FGO','co2','kedel') = YS('TaxCO2FGOKedel') / Brandsel('FGO','Densitet') / LhvMWhPerUnitFuel('FGO');      # Convert from Liter to MWh base.
TaxRateMWh('FGO','nox','kedel') = YS('TaxNOxFGOKedel') / Brandsel('FGO','Densitet') / LhvMWhPerUnitFuel('FGO');      # Convert from Liter to MWh base.
TaxRateMWh('FGO','sox','kedel') = YS('TaxSOxFGO') / Brandsel('FGO','Densitet') / LhvMWhPerUnitFuel('FGO');           # Convert from Liter to MWh base.
TaxRateMWh('FGO','enr','kedel') = YS('TaxEnergiFGOKedel') / Brandsel('FGO','Densitet') / LhvMWhPerUnitFuel('FGO');   # Convert from Liter to MWh base.
TaxRateMWh('FGO','ets','kedel') = YS('TaxCO2Kvote') * CO2ProdTonMWh('FGO') ;
      
TaxRateMWh('NGas','ch4','kedel') = YS('TaxCH4Kedel') / LhvMWhPerUnitFuel('NGas');                                                  # Convert from m3 to MWh base.
TaxRateMWh('NGas','co2','kedel') = YS('TaxCO2NGasKedel') / LhvMWhPerUnitFuel('NGas');                                              # Convert from m3 to MWh base.
TaxRateMWh('NGas','nox','kedel') = YS('TaxNOxNGasKedel') * (1 - YS('TaxNOxRefusionPctNGasKedel')/100) / LhvMWhPerUnitFuel('NGas'); # Convert from m3 to MWh base.
TaxRateMWh('NGas','enr','kedel') = YS('TaxEnergiNGasKedel') / LhvMWhPerUnitFuel('NGas');                                           # Convert from GJ to MWh base.
TaxRateMWh('NGas','ets','kedel') = YS('TaxCO2Kvote') * CO2ProdTonMWh('NGas');
      
TaxRateMWh('NGas','ch4','kv') = YS('TaxCH4Motor') * (1 - YS('TaxCH4RefusionPctMotor')/100) / LhvMWhPerUnitFuel('NGas');          # Convert from m3 to MWh base.
TaxRateMWh('NGas','nox','kv') = YS('TaxNOxNGasMotor') * (1 - YS('TaxNOxRefusionPctNGasMotor')/100) / LhvMWhPerUnitFuel('NGas');  # Convert from m3 to MWh base.
TaxRateMWh('NGas','co2','kv') = YS('TaxCO2NGasMotor') / LhvMWhPerUnitFuel('NGas');                                               # Convert from m3 to MWh base.
TaxRateMWh('NGas','enr','kv') = YS('TaxEnergiNGasMotor') / LhvMWhPerUnitFuel('NGas');                                            # Convert from m3 to MWh base.
TaxRateMWh('NGas','ets','kv') = YS('TaxCO2Kvote') * CO2ProdTonMWh('NGas');

TaxRateMWh('flis','enr','kedel') = YS('TaxEnergiBiomasse') * 3.6; 
TaxRateMWh('flis','nox','kedel') = YS('TaxNOxFlisKedel')   * 3.6; 
TaxRateMWh('flis','sox','kedel') = YS('TaxSOxFlis')        * 3.6; 
TaxRateMWh('flis','co2','kedel') = YS('TaxCO2Biomasse')    * 3.6; 
TaxRateMWh('flis','enr','kv')    = YS('TaxEnergiBiomasse') * 3.6; 
TaxRateMWh('flis','nox','kv')    = YS('TaxNOxFlisKedel')   * 3.6; 
TaxRateMWh('flis','sox','kv')    = YS('TaxSOxFlis')        * 3.6;
TaxRateMWh('flis','co2','kv')    = YS('TaxCO2Biomasse')    * 3.6;  
TaxRateMWh('flis','VE', 'kv')    = YS('TaxBioElProd');                                # Dataværdien skal være negativt tal da det er et tilskud.
         

# OBS  : Halm forventes ikke pålagt CO2-afgift, da det er bæredygtig biomasse, som skal bortskaffes.
TaxRateMWh('Halm','enr','kedel') = YS('TaxEnergiBiomasse') * 3.6; 
TaxRateMWh('Halm','nox','kedel') = YS('TaxNOxHalm')        * 3.6; 
TaxRateMWh('Halm','sox','kedel') = YS('TaxSOxHalm')        / LhvMWhPerUnitFuel('Halm'); 
TaxRateMWh('Halm','co2','kedel') = YS('TaxCO2Biomasse')    * 3.6; 
TaxRateMWh('Halm','enr','kv')    = YS('TaxEnergiBiomasse') * 3.6; 
TaxRateMWh('Halm','nox','kv')    = YS('TaxNOxHalm')        * 3.6; 
TaxRateMWh('Halm','sox','kv')    = YS('TaxSOxHalm')        / LhvMWhPerUnitFuel('Halm');
TaxRateMWh('Halm','co2','kv')    = YS('TaxCO2Biomasse')    * 3.6; 
TaxRateMWh('Halm','VE', 'kv')    = YS('TaxBioElProd');                                # Dataværdien skal være negativt tal da det er et tilskud.

TaxRateMWh('Pellet','enr','kedel') = YS('TaxEnergiBiomasse') * 3.6; 
TaxRateMWh('Pellet','nox','kedel') = YS('TaxNOxPelletKedel') * 3.6; 
TaxRateMWh('Pellet','sox','kedel') = YS('TaxSOxPellet')      / LhvMWhPerUnitFuel('Pellet'); 
TaxRateMWh('Pellet','co2','kedel') = YS('TaxCO2Biomasse')    * 3.6;  
TaxRateMWh('Pellet','enr','kv')    = YS('TaxEnergiBiomasse') * 3.6; 
TaxRateMWh('Pellet','nox','kv')    = YS('TaxNOxPelletKedel') * 3.6; 
TaxRateMWh('Pellet','sox','kv')    = YS('TaxSOxPellet')      / LhvMWhPerUnitFuel('Pellet');
TaxRateMWh('Pellet','co2','kv')    = YS('TaxCO2Biomasse')    * 3.6; 
TaxRateMWh('Pellet','VE', 'kv')    = YS('TaxBioElProd');                                # Dataværdien skal være negativt tal da det er et tilskud.


#--- TaxRateMWh('Stenkul','co2','kv') = YS('TaxCO2StenkulKV')    * 3.6;
#--- TaxRateMWh('Stenkul','nox','kv') = YS('TaxNOxStenkul')      * 3.6;
#--- TaxRateMWh('Stenkul','sox','kv') = YS('TaxSOxStenkul')      * 3.6;
#--- TaxRateMWh('Stenkul','enr','kv') = YS('TaxEnergiStenkulKV') * 3.6;
#--- TaxRateMWh('Stenkul','ets','kv') = YS('TaxCO2Kvote') * CO2ProdTonMWh('Stenkul');
                         
TaxRateMWh('Elec',   'enr','kedel') = YS('TaxEnergiEl') - YS('TaxEnergiElReduc');
TaxRateMWh('Elec',   'enr','vp')    = YS('TaxEnergiEl') - YS('TaxEnergiElReduc');
#---TaxRateMWh('Elec',   'Oversk', 'vp')= YS('TaxOverskudsVarme') * 3.6; # Converts from GJ to MWh. 

TaxRateMWh('Affald','afv','kv') = YS('TaxAffaldVarmeNetto')   * 3.6;  # Convert from GJ to MWh base.
TaxRateMWh('Affald','atl','kv') = YS('TaxAffaldTillaegNetto') * 3.6;  # Convert from GJ to MWh base.


# NB: Kvote-omfattede værker får godtgjort CO2-afgiften på brændsel til elproduktion opgjort efter E/V-formel.
# Kvote-omfattelse styres af en positiv kvotepris "TaxCO2Kvote".
# Der er refusionsmulighed for CO2-afgift til procesvarme fx varmholdelse.

TaxRateMWh('Elec', 'enr', 'kedel')  = Min([YS('TaxEnergiEl') - YS('TaxEnergiElReduc')], YS('TaxEnergiElQMax'));  # DKK/MWh-el input.
#- display TaxRateMWh;

