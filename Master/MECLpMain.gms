$log Entering file: %system.incName%
$Title 23-4002 MEC Load planning tool
$eolcom #
$OnText
Projekt:    23-4002 MEC Load Planning Tool
Filnavn:    MecLpMain.gms
Scope:      Controls build-up of GAMS model
Date:       2023-05-20 14:56
$OffText
#(
$set oDumpStatsToExcel 0
$set oDumpMasterStatsToExcel 1
$set oAlfaVersion 5

#$set oOptCa 64E-4  # Se beskrivelse herover.
option optcr = 0.005;  # relativ gap tolerance

$If not errorfree $exit

$Include GlobalSettings.gms
$Include DeclareGlobalSets.gms
$Include Declarations.gms
$Include DeclareSlave.gms
$Include ReadScenarios.gms
$Include PrepareSlave.gms          # Indeholder validering af input og opsætning af periode-uafh. parametre.
$If not errorfree $exit

# OBS Alle erklæringer skal være udført før denne kodeblok (erklæringer må ikke forekomme indenfor loops).

$Include LoopPeriodPre.gms

execute_unload "MecLpMain.gdx";

# TODO PriceTaxTariffPeriod.gms skal omformes til at h�ndtere en tabel (lblScenYear, tShift), hvor tShift angiver tidspunkter ord(t), hvorefter en kolonne er gyldig.
$Include PriceTaxTariffPeriod.gms   # Inkluderes aktuelt af LoopPeriodPre.gms

# TODO TimeAggrPeriod.gms skal omformes til at h�ndtere en enkelt k�rsel.
$Include TimeAggrPeriod.gms

# TODO LoopRollHorizPre.gms skal omformes, så RH-parametre indlæses direkte.
$Include LoopRollHorizPre.gms
execute_unload "MecLpMain.gdx";
$If not errorfree $exit

$Include SetupSlaveModel.gms             # Opsætter modellen for den aktuelle rullende horisont.
$If not errorfree $exit

$Include SolveSlaveModel.gms             
$If not errorfree $exit

$Include LoopRollHorizPost.gms
$If not errorfree $exit

$Include LoopPeriodPost.gms

$include SaveResultsToExcel.gms
$If not errorfree $exit

execute_unload "MecLpMain.gdx";

#)