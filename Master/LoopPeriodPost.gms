$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        LoopPeriodPost.gms
Scope:          Sidste del af periode opsætningsloop
Inkluderes af:  MecLpMain.gms
Argumenter:     <endnu ikke defineret>

$OffText


# Sæt medlemskab af set t, så det dækker hele perioden, men stadig respekterer evt. tidsaggregering.
t(tt) = ord(tt) LE NblockActual;


*begin Beregn perioderesultater, som ikke kan indgå i slave-modellen med rullende horisont.

FinSum(upr) = sum(t, FF.L(t,upr));

CO2emisFuelSum(f,co2kind) = sum(upr $(OnUGlobal(upr) AND (FuelMix(upr,f) GT 0)), 
                                FinSum(upr) *  
                                  [FuelMix(upr,f) * Brandsel(f,'CO2EmisMWh') * 
                                    #--- [Brandsel(f,'FossilAndel') * (1-sum(cc $sameas(upr,cc), uCC(cc))) $sameas(co2kind,'regul') 
                                    #--- + (1.0 - 0.8 * sum(cc $sameas(upr,cc), uCC(cc))) $sameas(co2kind,'phys')]
                                    [Brandsel(f,'FossilAndel') * (1-0) $sameas(co2kind,'regul') 
                                     + (1.0 - 0.8 * (0)) $sameas(co2kind,'phys')]
                                  ]  
                                  + [YS('CO2ElecMix') $(sameas(f,'elec') AND sameas(co2kind,'phys'))]                 
                                ) / 1000;


*begin Beregn perioderesultater, som ikke kan indgå i slave-modellen med rullende horisont.



*begin Beregning af driftsmæssige skyggepriser for kapaciteter.

# Marginaler udtrækkes af kapacitetsligninger
# Der tages højde for at solveren ikke har beregnet marginaler, idet disse så har værdien UNDF eller NA
# GAMS har en funktion mapVal(x), som leverer en integer-kode for typen af x (se:  https://www.gams.com/latest/docs/UG_Parameters.html#UG_Parameters_mapval )
#    0:  x is not a special value
#    4:  x is UNDF (undefined)
#    5:  x is NA (not available)
#    6:  x is INF ( )
#    7:  x is -INF ( )
#    8:  x is EPS

*end

*begin DUMP til Excel output


*begin Dump options - full or partial model dumped to Excel, Gdx

$Include DumpPeriodsToExcel.gms

#--- $Include SavePeriodstats.gms

*end   DUMP til Excel output


*begin Udskrivning af slaveresultat i gdx-format for aktuel periode.

#DISABLED for at vinde tid.
$batInclude 'SavePeriodResults.gms'       

*end   Udskrivning af slaveresultat i gdx-format for aktuel periode.
