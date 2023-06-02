$log Entering file: %system.incName%

$OnText
Projekt:        20-1001 MEC BHP - Fremtidens fjernvarmeproduktion.
Filnavn:        LoopMasterPre.gms
Scope:          Første del af master iteration loop
Inkluderes af:  MECmain.gms
Argumenter:     <endnu ikke defineret>

$OffText


display '>>>>>>>>>>>>>>>>  ENTERING %system.incName%  <<<<<<<<<<<<<<<<<<<';

# MOVE # Profiling optionen kan ikke sættes indenfor loops, derfor sættes den her.
# MOVE #--- option profile=3;

#begin Initializing file breakrun.txt
# BreakRun featuren gør det muligt at stoppe en batch-kørsel kontrolleret ved manuelt at redigere filen BreakRun.txt som beskrevet herunder.
# Beskrivelsen optræder også i filen og bør ikke slettes.
# Værdien 00 medfører at kørslen fortsættes.
# Værdien 00 kan ændres til 1 eller 2 afhængigt af det ønskede stop-forløb.
# Filen BreakRun.txt indlæses efter hver periodekørsel og der tages aktion derefter. 

embeddedCode Python:
import os
wkdir = os.getcwd()
fpath = os.path.join(wkdir, r'BreakRun.txt')
f = open(fpath, mode='w')
f.write('* File for signaling premature end of GAMS run')
f.write('\n* 0=None, 1=After actual slave run, 2=After actual master iteration.')
f.write('\n 00')
f.close()
#--- gams.printLog('File BreakRun.txt initialized.')
endEmbeddedCode

#end Initializing file breakrun.txt

# MOVE Scalar    iblock, ActualBlockLen, ElspotSum, GasPriceSum, TariffDsoLoadSum, TariffEigenPumpSum, THavSum, TSoilSum, TSpildeSum, PtXMaxSum;
# MOVE Parameter QDemSum(net)           'Mellemregning ifm tidsaggregering';
# MOVE Parameter SolVarmeSum(usol)      'Mellemregning ifm tidsaggregering';
# MOVE Parameter dQExtSum(produExtR)    'Mellemregning ifm tidsaggregering';
# MOVE Parameter TariffElecUSum(u)      'Mellemregning ifm tidsaggregering';
# MOVE Parameter TariffEigenUSum(u)     'Mellemregning ifm tidsaggregering';
# MOVE Parameter RevisionSum(cp)        'Mellemregning ifm tidsaggregering';
# MOVE Parameter CopSum(hp)             'Mellemregning ifm tidsaggregering';
# MOVE Parameter QhpYieldSum(hp)        'Mellemregning ifm tidsaggregering';
# MOVE Parameter TluftSum(yrFjv)        'Mellemregning ifm tidsaggregering';
# MOVE Parameter alphaTSum(tr,trkind)   'Mellemregning ifm tidsaggregering';


#begin Initialisering af startgæt til nul.

StartGaetAvailable(perA,iter) = 0;
SbOn(tt,upr,perA,iter)    = 0;
SbOnT(tt,tr,perA,iter)    = 0;
SbOnTAll(tr,perA,iter)    = 0;
SbStart(tt,upr,perA,iter) = 0;
SbBypass(tt,kv,perA,iter) = 0;
SbRgk(tt,kv,perA,iter)    = 0;

#end

OnDeAggr = FALSE;   # Kan blive aktiveret i LoopMasterPost.gms, hvis OnTimeAggr er negativ.

# ====================================  START På MASTER ITERATION LOOP (afsluttes i LoopMasterPost.gms)  ==================================
Loop (iter $(ord(iter) GE 2),
  actIter(iter) = yes;
  MasterIter = ord(iter);
  Loop (per,
    MasCapBestIter(unew,per,iter)   = MasCapBest(unew,per) $OnUPer(unew,per);
    MasCapActualIter(unew,per,iter) = MasCapActual(unew,per) $OnUPer(unew,per);
  );
  display MasterIter, MasCapActual;

  # Ovenstående loop-stmt starter master iterationen.
  # Loopet afsluttes i LoopMasterPost.gms

  # Nulstil VAK-beholdninger til nul ved starten af hver masteriteration.
  LVakPrevious(vak) = 0.0;


#begin Komponering af filen gurobi.opt med variabel mipgap tolerance.

# OBS Solver optioner bliver kun tilpasset til brug for slave-modellen. Mastermodellen har sin egen optionsfil.

embeddedCode Python:
    """ 
    Writes the file gurobi.opt with a mipgap tolerance that depends on the actual master iteration.
    Only applicable to slave model.
    The master model uses option file  gurobi.op9  (GAMS naming convention for option files)
    """
    import os
    
    wkdir = os.getcwd()  #--- wkdir = gams.wsWorkingDir  # Does not work.
    path = os.path.join(wkdir, 'gurobi.opt')
    with open(path, mode='r') as f:
        lines = f.readlines()  # OBS: Last char is a newline ASCII 10.
        
    #--- gams.printLog(f'{len(lines)=}')

    scheme        = list(gams.get('MipGapScheme'))[0]
    mingap        = list(gams.get('MipGapMin'))[0]
    maxgap        = list(gams.get('MipGapMax'))[0]
    mipIterBegin  = list(gams.get('MipIterBegin'))[0]
    mipIterEnd    = list(gams.get('MipIterEnd'))[0]
    masterIter    = list(gams.get('MasterIter'))[0]
    masterIterMax = list(gams.get('MasterIterMax'))[0]

    #--- scheme = 1
    
    if scheme <= 0:
        quit()
    
    if scheme == 1:
        # Scheme 1 for computing mipgap for the upcoming master iteration: Ramp-function from maxgap to mingap.
        #          MipGap slides linearly to its lowest value at a chosen master iteration.
        if masterIter < mipIterBegin:
            actualMipGap = maxgap
        elif masterIter < mipIterEnd:
            actualMipGap =  maxgap - (maxgap - mingap) * (masterIter - mipIterBegin) / float(mipIterEnd - mipIterBegin)
        else:
            actualMipGap = mingap

    elif scheme == 2:
        # Scheme 2 for computing mipgap for the upcoming master iteration: Step-function from maxgap to mingap.
        #          MipGap = maxgap until maxIterSlack after which it drops to mingap.
        # OBS:     Parameter mipIterBegin is NOT USED.
        maxIterShift = masterIterBegin - 2  # Master iteration where maxgap is replaced by its min. value mingap.
        if masterIter < maxIterShift:
            actualMipGap = maxgap
        else:
            actualMipGap = mingap
            
    else:
        raise ValueError(f'ERROR: MipGapScheme = {scheme} is not a valid option')
    
    replacement = f'mipgap={str(actualMipGap)} \n'

    #--- gams.printLog(f'{masterIter=}, {replacement=}')
  
    # Find the MipGap line.
    Found = False
    for iline, line in enumerate(lines):
        #--- print(f'{iline=}, {line=}')
        if 'mipgap' in  line.lower():
            lines[iline] = replacement
            Found = True
            break

    if not Found:
        lines.append(replacement)
     
    with open(path, mode='w') as f:
        for line in lines:
            f.write(line)

endEmbeddedCode
                                                                        

#end Komponering af filen gurobi.opt med variabelt mipgap tolerance.