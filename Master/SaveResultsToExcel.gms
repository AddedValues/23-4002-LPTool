$log Entering file: %system.incName%
  
$OnText
Projekt:        23-1002 MEC Mulighedsanalyse opdateret.
Filnavn:        SaveResultToExcel.gms
Scope:          Beregner og gemmer statistik for aktuel periode i aktuel master iteration.
Inkluderes af:  LoopPeriodPost.gms
Argumenter:     <ingen>
$OffText


# Tidsaksen er kontinuert med udgangspunkt i planperiodens starttidspunkt.
Parameter QvsTime(tt,u)      'Varmeproduktion i hvert tidsskridt';
Scalar    Timevalue2023Begin 'Excel date value of 2023-01-01 00:00.' / 44927 /;  
Scalar    YearStart          'Planperiodens startår';
Scalar    MonthStart         'Planperiodens startmåned';
Scalar    DayStart           'Planperiodens startdag';
Scalar    HourStart          'Planperiodens starttime';
Scalar    TimeValueStart     'Planperiodens kalender starttidspunkt';
Scalar    TimeValue2023Begin 'Planperiodens kalender starttidspunkt';
YearStart  = floor(TimestampStart / 1E6);
MonthStart = floor((TimestampStart - 1E6 * YearStart) / 100);
DayStart   = floor( (TimestampStart - 1E6 * YearStart - 100 * MonthStart));
HourStart  = mod(TimestampStart, 100);

Parameter OnUGlobal_L(u)        'Rådig status for hvert anlæg';
Parameter OnUprGlobal_L(upr)    'Rådig status for hvert produktionsanlæg';
Parameter OnVakGlobal_L(vak)    'Rådig status for hver VAK';
Parameter Q_L(tt,u)             'Varmeproduktion for hvert anlæg [MWhq]';
Parameter Fin_L(tt,upr)      'Indgivet energi for hvert anlæg [MWh]';
Parameter LVak_L(tt,vak)        'Lagerstand for hver VAK [MWhq]';

TimeVector('t1') = 0;
loop (tt $(ord(tt) GE 2 AND ord(tt) LE Nblock),
  TimeVector(tt) = TimeVector(tt-1) + TimeResol(tt-1);
);  
TimeVector('t1') = tiny;
display TimeVector;

TimeVector(tt) $(ord(tt) GE 2 AND ord(tt) LE Nblock) = TimeVector(tt-1) + TimeResol(tt-1);

OnUGlobal_L(u)     = max(tiny, OnUGlobal(u));
OnUprGlobal_L(upr) = max(tiny, OnUGlobal(upr));
OnVakGlobal_L(vak) = max(tiny, OnUGlobal(vak));

Q_L(tt,u) $(TimeResol(tt) GT 0) = QF.L(tt,u) * 60 / TimeResol(tt);
Q_L(tt,u) $(Q_L(tt,u) EQ 0.0)   = tiny;

Fin_L(tt,upr) $(TimeResol(tt) GT 0) = max(tiny, FF.L(tt,upr) * 60 / TimeResol(tt));
LVak_L(tt,vak) = max(tiny, LVak.L(tt,vak));

#--- QT_L(tt,tr)           = QTF.L(tt,tr);
#--- QRgk_L(tt,kv)         = QRgk.L(tt,kv);
#--- Qbypass_L(tt,kv)      = QfBypass.L(tt,kv);
#--- Qcool_L(tt,ucool)     = Qcool.L(tt,ucool);
#--- Pnet_L(tt,kv)         = PfNet.L(tt,kv);
#--- bOn_L(tt,upr)         = bOn.L(tt,upr);
#--- bOnSR_L(tt,netq)      = bOnSR.L(tt,netq);



$onecho > MECLpOutput.txt
filter=0

*begin Individuelle dataark

par=ActScen squeeze=N                rng=Overview!A9           cdim=0 rdim=1
text="ActScen"                       rng=Overview!A8:A8

par=OnUGlobal_L squeeze=N            rng=VarmeProd!I8          cdim=1 rdim=0
par=TimeVector                       rng=VarmeProd!B11         cdim=0 rdim=1
text="Timestamp(min)"                rng=VarmeProd!B10:B10
par=QDemandActual                    rng=VarmeProd!D10         cdim=1 rdim=1
text="Qdemand (MWhq)"                rng=VarmeProd!D10:D10
par=Q_L                              rng=VarmeProd!H10         cdim=1 rdim=1
text="QF (MWhq)"                      rng=VarmeProd!H10:H10

par=OnUprGlobal_L squeeze=N          rng=FF!E8             cdim=1 rdim=0
par=TimeVector                       rng=FF!B11            cdim=0 rdim=1
text="Timestamp(min)"                rng=FF!B10:B10
par=Fin_L                         rng=FF!D10            cdim=1 rdim=1
text="FF (MWh)"                  rng=FF!D10:D10

par=OnVakGlobal_L squeeze=N          rng=LVak!E8             cdim=1 rdim=0
par=TimeVector                       rng=LVak!B11            cdim=0 rdim=1
text="Timestamp(min)"                rng=LVak!B10:B10
par=LVak_L                           rng=LVak!D10            cdim=1 rdim=1
text="LVak (MWhq)"                   rng=LVak!D10:D10

$offecho

execute_unload "MECLpOutput.gdx" 
tt, t, uall, u, upr, uq, 
ActScen, OnUGlobal_L, OnUprGlobal_L, OnVakGlobal_L, TimeVector, QdemandActual, Q_L, Fin_L, LVak_L
;

execute "gdxxrw.exe MECLpOutput.gdx o=MECLpOutput.xlsm trace=1 @MECLpOutput.txt";
