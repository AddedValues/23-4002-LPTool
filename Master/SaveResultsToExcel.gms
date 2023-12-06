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

Parameter OnUGlobal_L(u)            'Rådig status for hvert anlæg';
Parameter OnUprGlobal_L(upr)        'Rådig status for hvert produktionsanlæg';
Parameter OnVakGlobal_L(vak)        'Rådig status for hver VAK';
Parameter QfDemandActual_L(tt,net)  'Varmebehovseffekt [MWhq]';
Parameter Qf_L(tt,u)                'Varmeproduktion for hvert anlæg [MWhq]';
Parameter Ff_L(tt,upr)              'Indgivet energi for hvert anlæg [MWh]';
Parameter Evak_L(tt,vak)            'Lagerstand for hver VAK [MWhq]';

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

QfDemandActual_L(tt,net) $(TimeResol(tt) GT 0) = QeDemandActual(tt,net) / BLen(tt);  # Varmestrømme kan være negative (VAK-opladning).
Qf_L(tt,u) $(TimeResol(tt) GT 0) = Qf.L(tt,u);  # Varmestrømme kan være negative (VAK-opladning).
Qf_L(tt,u) $(Qf_L(tt,u) EQ 0.0)  = tiny;
Ff_L(tt,upr) $(TimeResol(tt) GT 0) = max(tiny, Ff.L(tt,upr));
Evak_L(tt,vak) = max(tiny, Evak.L(tt,vak));

#--- QTf_L(tt,tr)           = QTf.L(tt,tr);
#--- QfRgk_L(tt,kv)         = QfRgk.L(tt,kv);
#--- QfBypass_L(tt,kv)      = QfBypass.L(tt,kv);
#--- PfNet_L(tt,kv)         = PfNet.L(tt,kv);
#--- bOn_L(tt,upr)          = bOn.L(tt,upr);


$onecho > MECLpOutput.txt
filter=0

*begin Individuelle dataark

par=ActScen squeeze=N                rng=Overview!A9           cdim=0 rdim=1
text="ActScen"                       rng=Overview!A8:A8

par=OnUGlobal_L squeeze=N            rng=EffektUd!I8           cdim=1 rdim=0
par=TimeVector                       rng=EffektUd!B11          cdim=0 rdim=1
text="Timestamp(min)"                rng=EffektUd!B10:B10    
par=QfDemandActual_L                 rng=EffektUd!D10          cdim=1 rdim=1
text="QfDemandActual (MWq)"          rng=EffektUd!D10:D10    
par=Qf_L                             rng=EffektUd!H10          cdim=1 rdim=1
text="Qf (MWq)"                      rng=EffektUd!H10:H10

par=OnUprGlobal_L squeeze=N          rng=EffektInd!E8          cdim=1 rdim=0
par=TimeVector                       rng=EffektInd!B11         cdim=0 rdim=1
text="Timestamp(min)"                rng=EffektInd!B10:B10     
par=Ff_L                             rng=EffektInd!D10         cdim=1 rdim=1
text="Ff (MWf)"                      rng=EffektInd!D10:D10     
                                                               
par=OnVakGlobal_L squeeze=N          rng=LagerStand!E8         cdim=1 rdim=0
par=TimeVector                       rng=LagerStand!B11        cdim=0 rdim=1
text="Timestamp(min)"                rng=LagerStand!B10:B10    
par=Evak_L                           rng=LagerStand!D10        cdim=1 rdim=1
text="Evak (MWhq)"                   rng=LagerStand!D10:D10    

$offecho

execute_unload "MECLpOutput.gdx" 
tt, t, uall, u, upr, uq, 
ActScen, OnUGlobal_L, OnUprGlobal_L, OnVakGlobal_L, TimeVector, QfDemandActual_L, Qf_L, Ff_L, Evak_L
;

execute "gdxxrw.exe MECLpOutput.gdx o=MECLpOutput.xlsm trace=1 @MECLpOutput.txt";
