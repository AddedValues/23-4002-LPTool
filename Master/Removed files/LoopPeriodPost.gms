$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        LoopPeriodPost.gms
Scope:          Sidste del af periode opsætningsloop
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText


# Sæt medlemskab af set t, så det dækker hele perioden, men stadig respekterer evt. tidsaggregering.
# REMOVE #--- t(tt) = ord(tt) LE Periods('PeriodHours',actPer);
t(tt) = ord(tt) LE NblockActual;


#begin Beregn perioderesultater, som ikke kan indgå i slave-modellen med rullende horisont.

PowInUSum(upr) = sum(t, PowInU.L(t,upr));

CO2emisFuelSum(f,co2kind) = sum(upr $(OnU(upr) AND (FuelMix(upr,f) GT 0)), 
                                PowInUSum(upr) *  
                                  [FuelMix(upr,f) * Brandsel(f,'CO2EmisMWh') * 
                                    [Brandsel(f,'FossilAndel') * (1-sum(cc $sameas(upr,cc), uCC(cc))) $sameas(co2kind,'regul') 
                                     + (1.0 - 0.8 * sum(cc $sameas(upr,cc), uCC(cc))) $sameas(co2kind,'phys')]
                                  ]  
                                  + [YS('CO2ElecMix') $(sameas(f,'elec') AND sameas(co2kind,'phys'))]                 
                                ) / 1000;


#begin Beregn perioderesultater, som ikke kan indgå i slave-modellen med rullende horisont.



#begin Beregning af driftsmæssige skyggepriser for kapaciteter.

# REMOVE # TODO PerMargObj tilpasses restriktioner, som giver følsomheder på kapaciteter.
# REMOVE 
# REMOVE PerMargObj(actPer,iter) = PeriodObjScale * ObjSumRH;
# REMOVE 
# REMOVE # TODO Skal evt. udvides / dubleres til også at omfatte lagre og transmissionsledninger.
# REMOVE GradUMarg(unew,actPer) = PeriodObjScale * sum(uq $sameas(unew,uq), sum(t, BLen(t) * EQ_QProdUmax.m(t,uq) * bOn.L(t,uq)));
# REMOVE display "DEBUG: GradUMarg:", MasterIter, actPer, GradUMarg;
# REMOVE 
# REMOVE 
# REMOVE #--- display "Før kompensering for manglende marginaler", GradUMarg;
# REMOVE 
# Marginaler udtrækkes af kapacitetsligninger
# Der tages højde for at solveren ikke har beregnet marginaler, idet disse så har værdien UNDF eller NA
# GAMS har en funktion mapVal(x), som leverer en integer-kode for typen af x (se:  https://www.gams.com/latest/docs/UG_Parameters.html#UG_Parameters_mapval )
#    0:  x is not a special value
#    4:  x is UNDF (undefined)
#    5:  x is NA (not available)
#    6:  x is INF ( )
#    7:  x is -INF ( )
#    8:  x is EPS

# REMOVE # Manglende marginaler vil omfatte en hel RH.
# REMOVE # Spørgsmål: Hvordan skal manglende marginaler håndteres?
# REMOVE # Et forslag er at erstatte de manglende marginaler med en forholdsmæssig andel af de øvrige tidsrums marginaler.
# REMOVE # Det har i et eksempel med 40 % manglende marginaler vist sig i betydelig GradU at ændre gradientens størrelse og især retning.
# REMOVE # En simpel negligering har givet mindre afvigelser og i høj GradU bevaret gradientens retning.
# REMOVE # OBS: Empiri har vist, at manglende marginaler provokeres af små værdier af mipgap (< 0.01)
# REMOVE 
# REMOVE # Her beregnes marginaler for alle RH, hvor de er til rådighed.
# REMOVE GradUMarg(unew,actPer) = 0.0;
# REMOVE loop (rhStep $(ord(rhStep) LE nRHstep + 1),
# REMOVE   if (HasMarginalsRH(rhStep),
# REMOVE     TimeBegin = RHIntv(rhStep,'begin');
# REMOVE     TimeEnd   = RHIntv(rhStep,'endStep');
# REMOVE     #--- display "Beregning af rådige marginaler", actPer, TimeBegin, TimeEnd;
# REMOVE     GradUMarg(unew,actPer) = GradUMarg(unew,actPer) + PeriodObjScale * sum(uq $sameas(unew,uq), sum(tt $(ord(tt) GE TimeBegin AND ord(tt) LE TimeEnd), BLen(tt) * EQ_QProdUmax.m(tt,uq) * bOn.L(tt,uq)));
# REMOVE   );
# REMOVE );

# Beregn timegennemsnit af marginaler for de RH, hvor de er til rådighed.
nHourMarginals = sum(rhStep $(ord(rhStep) LE nRHstep + 1), RHIntv(rhStep,'lenstep') $HasMarginalsRH(rhStep));
if (nHourMarginals EQ 0,
  display "ERROR: Der er ingen marginaler i nogen rullende horisonter";
else 
  loop (unew $OnU(unew), MarginalsHour(unew, actPer) = GradUMarg(unew,actPer) / nHourMarginals; );
  display "GradUMarg baseret på rådige marginaler", GradUMarg;
);
# TODO Kompensering for manglende marginaler aktiveres herunder, når kapacitetsrestriktionerne er identificeret.

# REMOVE # Her tildeles en forholdsmæssig andel for de RH, som ikke har marginaler til rådighed.
# REMOVE display "Før kompensering af manglende marginaler:", MarginalsHour;
# REMOVE loop (rhStep $(ord(rhStep) LE nRHstep + 1),
# REMOVE   if (NOT HasMarginalsRH(rhStep),
# REMOVE     TimeBegin  = RHIntv(rhStep,'begin');
# REMOVE     TimeEnd    = RHIntv(rhStep,'endStep');
# REMOVE     DurationRH = TimeEnd - TimeBegin + 1;
# REMOVE     display "Kompensering af manglende marginaler", actPer, TimeBegin, TimeEnd, DurationRH;
# REMOVE     GradUMarg(unew,actPer) = GradUMarg(unew,actPer) + MarginalsHour(unew,actPer) * sum(upr $(OnU(upr) AND sameas(upr,unew)), sum(tt $(ord(tt) GE TimeBegin AND ord(tt) LE TimeEnd), 1.0 $bOn.L(tt,upr)));
# REMOVE   );
# REMOVE );
# REMOVE display "GradUMarg efter kompensation af manglende marginaler", GradUMarg;
# REMOVE 
# REMOVE display MasterIter, zSlave.L, PowInMaxU, PerMargObj, GradUMarg;
# REMOVE 
# REMOVE #--- abort.noerror " BEVIDST STOP I LoopPeriodPost.gms";
# REMOVE 
#end

#begin DUMP til Excel output

# REMOVE #begin Kapacitetsomkostninger for aktuel periode.
# REMOVE                                                                 
# REMOVE rate = ActScen('InterestRate');
# REMOVE loop (unew,
# REMOVE   nTerm   = Capex(unew, 'invLen');               # Antal terminer [år].
# REMOVE   fDeprec = rate / (1 - (1+rate)**(-nTerm));     # Amortiseringsfaktor.
# REMOVE   DeprecCost(unew) = fDeprec * CapQU(unew) * Capex(unew, 'capex1') * 1E6; 
# REMOVE );
# REMOVE DeprecCost(uexist) = DeprecExistPer(uexist,actPer) * 1E6;
# REMOVE   
# REMOVE 
# REMOVE #end Kapacitetsomkostninger for aktuel periode.

#begin Dump options - full or partial model dumped to Excel, Gdx

$Include DumpPeriodsToExcel.gms

$Include SavePeriodResults.gms

$Include SavePeriodstats.gms

#end   DUMP til Excel output


#begin Udskrivning af slaveresultat i gdx-format for aktuel periode.

#DISABLED for at vinde tid.
$batInclude 'SavePeriodResults.gms' 

#end   Udskrivning af slaveresultat i gdx-format for aktuel periode.


# REMOVE #begin Check for manuel afbrydelse af kørsel.
# REMOVE 
# REMOVE #begin Indlæs afbrydelsessignal fra filen BreakRun.txt
# REMOVE 
# REMOVE 
# REMOVE embeddedCode Python:
# REMOVE 
# REMOVE import os
# REMOVE wkdir = os.getcwd()
# REMOVE fpath = os.path.join(wkdir, r'BreakRun.txt')
# REMOVE 
# REMOVE if not os.path.exists(fpath):
# REMOVE   breakrun = 0
# REMOVE   #--- gams.printLog('WARNING: No such file: ' + fpath)
# REMOVE else:
# REMOVE   f = open(fpath, mode='r')
# REMOVE   lines = f.readlines()
# REMOVE   f.close()
# REMOVE   
# REMOVE   breakrun = list()
# REMOVE   for line in lines:
# REMOVE     line = line.strip()
# REMOVE     if line.startswith('*'):
# REMOVE       continue
# REMOVE     else:
# REMOVE       breakrun.append(int(line))
# REMOVE       break
# REMOVE   
# REMOVE   sval = str(breakrun[0])
# REMOVE   #--- gams.printLog('BreakRun = ' + sval)
# REMOVE   #--- if sval == '1':
# REMOVE   #---   gams.printLog('\r\nRun will be halted after actual period.\r\n')
# REMOVE   #--- elif sval == '2':
# REMOVE   #---   gams.printLog('\r\nRun will be halted after actual master iteration.\r\n')
# REMOVE   
# REMOVE gams.set('BreakRun', breakrun)
# REMOVE 
# REMOVE endEmbeddedCode BreakRun
# REMOVE 
# REMOVE display BreakRun
# REMOVE 
# REMOVE #end 
# REMOVE 
# REMOVE #begin Check for manuel afbrydelse af kørsel efter aktuel periode.
# REMOVE 
# REMOVE if (BreakRun EQ 1, 
# REMOVE   display 'Breaking run after actual period', BreakRun;
# REMOVE );
# REMOVE break $(BreakRun EQ 1); 
# REMOVE 
# REMOVE #end   Check for manuel afbrydelse af kørsel.
# REMOVE 
# REMOVE 
# REMOVE #DISABLED # Deaktiver aktuel periode, så den ikke fejlagtigt kan anvendes udenfor sit scope.
# REMOVE #DISABLED actPer(perA) = no;


