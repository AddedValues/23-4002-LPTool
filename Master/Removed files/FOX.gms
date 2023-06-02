#begin Parametre til specifikation af FOX-anlægget.

parameter FoxOperHours  / 8000 /;
parameter FoxRevisStart / 5448 /;  # Medio august.
parameter FoxRevisEnd;
FoxRevisEnd = FoxRevisStart + (8760 - 8000);

parameter FoxSteamFlow    'Dampflow [MWq]'       / 45.4 /;
parameter FoxSteamEtaQ    'Dampkedel virkn.grad' / 0.90 /;
parameter FoxFuelLhv      'Fox fuel LHV [GJ/ton]' / 11.0 /  # Givet ved 50 pct. tørstof.
parameter FoxFuelMax      'Fuel max [ton/år]' / 165000 /;
parameter FoxFuelConsumed 'FoxFuel forbrug [ton/år]';
FoxFuelConsumed = FoxOperHours * 3600 * (FoxSteamFlow / FoxSteamEtaQ / FoxFuelLhv) / 1000;  


parameter FoxOvPris    'Aktuel OV-pris DKK/MWqc';
parameter FoxOvPrisMin '[DKK/MWqc]' /   0 /;
parameter FoxOvPrisMax '[DKK/MWqc]' / 100 /;
parameter NFoxOvPris   '[DKK/MWqc]' /   5 /;

parameter FoxCOP / 6.5 /;  # Beregnet ved Tf=90, Tr=35, Tkin=36, Tkout=28

parameter FoxOvFlow     'Kølevandsflow [m3/h]' / 5000 /;
parameter FoxCoolHigh   'Kølevandstemperatur høj [°C]' / 36.0 /;
parameter FoxCoolLow    'Kølevandstemperatur lav [°C]' / 28.0 /;
parameter FoxQovMax     'Max. kølevandseffekt [MWqc]';
FoxQovMax = (FoxOvFlow / 3600) * 4186 * (FoxCoolHigh - FoxCoolLow);

parameter FoxFjvMax 'FJV effekt [MWq]';
FoxFjvMax = FoxCOP / (FoxCOP-1) * FoxQovMax; 
#--- parameter FoxPowIn 'Fox elforbrug vp [MWe]';
#--- FoxPowIn = 1.0 / FoxCOP * FoxFjv;

#end Parametre til specifikation af FOX-anlægget.

#begin FOX-specifikke restriktioner

positive variable FoxQov(tt)     'FOX overskudsvarme (kølevand)';
positive variable FoxQcool(tt)   'FOX bortkølet kølevarme';
positive variable FoxQovCost(tt) 'FOX købsomkostning kølevarme';

equation EQ_FoxQ(tt)        'Fjernvarme fra FOX Overskudsvarme';
equation EQ_FoxQovMax(tt)   'Øvre grænse for FOX kølevarme';
equation EQ_FoxQcool(tt)    'Bortkølet FOX kølevarme';
equation EQ_PowInUFoxHp(tt) 'Elforbrug på FOX varmepumpe';
equation EQ_FoxQovCost(tt)  'Købsomkostning FOX overskudsvarme';

EQ_FoxQ(t)        ..  Q(t,'foxhp')       =E=  FoxCOP / (FoxCOP - 1) * FoxQov(t) $OnU('foxhp');
EQ_FoxQovMax(t)   ..  FoxQov(t)          =L=  FoxQovMax $OnU('foxhp');
EQ_FoxQcool(t)    ..  FoxQcool(t)        =E=  FoxQovMax - FoxQov(t);
EQ_PowInUFoxHp(t) ..  PowInU(t,'foxhp')  =E=  1.0 / FoxCOP * Q(t,'foxhp');
EQ_FoxQovCost(t)  ..  FoxQovCost(t)      =E=  FoxQov(t) *  Brandsel('FoxOV', 'PrisMWh') $OnU('FoxHp');

#end FOX-specifikke restriktioner