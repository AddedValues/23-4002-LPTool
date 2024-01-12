$log Entering file: %system.incName%

display '>>>>>>>>>>>>>>>>  ENTERING %system.incName%  <<<<<<<<<<<<<<<<<<<';


*begin Opsætning af tidsaggregering for aktuelle periode.

if (abs(OnTimeAggr GT card(aggr)),
  execute_unload "MecLpMain.gdx";
  display "FEJL: OnTimeAggr skal ligge mellem -card(aggr) og +card(aggr).", OnTimeAggr;
  abort "FEJL: OnTimeAggr skal ligge mellem -card(aggr) og +card(aggr).";
);

BLen(tt) = 0;
actBlock(aggr) = (ord(aggr) EQ abs(OnTimeAggr));

#--- if (NOT UseTimeAggr AND NOT UseTimeExpansionAny,    # TidsAggr: Ingen tidsaggregering eller tidsekspansion.
if (NOT UseTimeAggr,                     

  #---   # Hver time er en blok af længde 1.
  #---   NblockHour(planZone) = 1;
  #---   Nblock   = DurationPeriod;
  #---   t(tt)    = ord(tt) LE DurationPeriod;
  #---   Bbeg(tt) = ord(tt);
  #---   Bend(tt) = Bbeg(tt);
  #---   BLen(tt) = 1;
  #---   IsBidDay(tt) = ord(tt) GE HourBeginBidDay AND ord(tt) LE HourEndBidDay;
  #--- 
  #--- elseif (UseTimeExpansionAny),                       # Ingen tidsaggregering, men tidsekspansion i driftsdøgnet omfattet af budindmeldingen.

  # OBS Bbeg har en anden betydning i tidsekspansion end i tidsaggregering.
  
  NblockHour(planZone) = round(TimeScale(planZone));
  Nblock = 0;             
  tend   = 0;  

  # Trin 1: Timer før BidDay
  tbegin = 1;
  tend   = NblockHour('Default') * (HourBeginBidDay - 1);
  if (OnTracing, display "DEBUG: Trin 1: tbegin, tend", tbegin, tend; );
  loop (tt $(ord(tt) GE tbegin AND ord(tt) LE tend),
    BLen(tt)     = TimeScaleInv('Default');
    BBeg(tt)     = 1 + trunc((ord(tt) - tbegin) * TimeScaleInv('Default') + 1E-8);  # Model time, som tidspunkt tt tilhører.
    BEnd(tt)     = BBeg(tt);
    Nblock       = Nblock + 1;
    IsBidDay(tt) = FALSE;
  );

  # Trin 2: Timer indenfor BidDay (antal = HoursBidDay)
  tbegin = tend + 1;
  tend   = tend + NblockHour('Bid') * HoursBidDay;
  if (OnTracing, display "DEBUG: Trin 2: tbegin, tend", tbegin, tend; );
  loop (tt $(ord(tt) GE tbegin AND ord(tt) LE tend),
    BLen(tt)    = TimeScaleInv('Bid');
    BBeg(tt)    = HourBeginBidDay + trunc((ord(tt) - tbegin) * TimeScaleInv('Bid') + 1E-8);      # Model time, som tidspunkt tt tilhører.
    BEnd(tt)    = BBeg(tt);
    Nblock      = Nblock + 1;
    IsBidDay(tt) = TRUE;
  );
  
  # Trin 3: Timer efter BidDay
  tbegin = tend + 1;
  tend   = tend + NblockHour('Default') * (DurationPeriod - HourEndBidDay);
  if (OnTracing, display "DEBUG: Trin 3: tbegin, tend", tbegin, tend; );
  loop (tt $(ord(tt) GE tbegin AND ord(tt) LE tend),
    BLen(tt)    = TimeScaleInv('Default');
    BBeg(tt)    = HourEndBidDay + 1 + trunc((ord(tt) - tbegin) * TimeScaleInv('Default') + 1E-8);  # Model time, som tidspunkt tt tilhører.
    BEnd(tt)    = BBeg(tt);
    Nblock      = Nblock + 1;
    IsBidDay(tt) = FALSE;
  );

  t(tt)   = ord(tt) LE Nblock;
  BLen(tt) $(ord(tt) GT Nblock) = 0.0;
  if (OnTracing, display "DEBUG: t(tt), BLen, Bbeg, Bend", t, BLen, Bbeg, Bend; );

  # Kobling mellem tt og tbid, dvs. tidspunkter og auktionstimer.
  tt2tbid(tt,tbid) = no;
  loop (tbid $(ord(tbid) LE HoursBidDay),   # Øvre grænse for tbid skyldes muligheden for at arbejde med døgn under 24 timer (til debugging).
    tbegin = TimeIndexBeginBidDay + (ord(tbid) - 1) * NblockHour('Bid');
    tend   = tbegin + NblockHour('Bid') - 1;
    #--- display "DEBUG tt2bid: tbegin, tend", tbegin, tend;
    tt2tbid(tt,tbid) $(ord(tt) GE tbegin AND ord(tt) LE tend) = yes;   # Gennemløb tidspunkter indenfor tbid-timen.
  );
    
  # Kobling mellem tt og th, dvs. tidspunkter og timer.
  tt2hh(tt,tta) = no;
  loop (tta $(ord(tta) LE DurationPeriod),   #  tta er på timebasis.
    thh(ttb) = BBeg(ttb) EQ ord(tta);
    #--- display "DEBUG tt2hh: thh", thh;
    tt2hh(tt,tta) = thh(tt);                 # Gennemløb tidspunkter indenfor den aktuelle time tta.
  );
  if (OnTracing,
    display NblockHour, TimeIndexBeginBidDay, tt2tbid, tt2hh;
  );
  
elseif (UseTimeAggr AND NOT UseTimeExpansionAny),       # Tidsaggregering, men ingen tidsekspansion.

  abort "Tidsaggregering er p.t. deaktiveret";
*begin DISABLED
  # DISABLED   # Bestem antal tidsblokke i aggregeringen.
  # DISABLED   Nblock = 0;
  # DISABLED   loop (tt,
  # DISABLED     if (TimeBlocks(tt, actBlock) EQ 0,
  # DISABLED       Nblock = ord(tt) - 1;
  # DISABLED       break;
  # DISABLED     );
  # DISABLED   );
  # DISABLED   t(tt) = ord(tt) LE Nblock;
  # DISABLED 
  # DISABLED   # Opret blokkenes sluttime og længde på basis af starttime.
  # DISABLED   Bbeg(t) = TimeBlocks(t,actBlock);
  # DISABLED 
  # DISABLED $OffOrder
  # DISABLED   loop (t $(ord(t) LT Nblock),
  # DISABLED     BLen(t) = Bbeg(t+1) - Bbeg(t);
  # DISABLED   );
  # DISABLED   loop (t $(ord(t) EQ Nblock),
  # DISABLED     BLen(t) = card(tt) + 1 - Bbeg(t);
  # DISABLED   );
  # DISABLED $OnOrder
  # DISABLED 
  # DISABLED   Bend(t) = Bbeg(t) + BLen(t) - 1;
  # DISABLED   NblockAggr = Nblock;
*end  

else                           # Denne else-blok skal ikke kunne nåes.
  abort "ERROR: Logisk fejl i LoopPeriodPre, da Else-blok aktiveret"
  
);  # if (NOT UseTimeAggr ... )

TimeResol(tt) = BLen(tt) * 60;   # Tidsopløsning [min] per tidspunkt t. Bruges ifm. rampetidsrestriktioner.
BLen(tt) $(ord(tt) GT Nblock) = 0.0;
display Nblock, NblockAggr, NblockHour, BLen;

# Sæt tidspunkter t(tt) til aggregeret niveau.
# OBS t(tt) kan blive reduceret i LoopRollHorizPre.gms, hvis DurationPeriod er mindre end 8760 timer.
t(tt) = yes;
t(tt) = ord(tt) LE Nblock;
if (OnTracing, display "LoopPeriodPre.gms (2) DEBUG: ", Nblock; );

BLenMax = smax(t, BLen(t));
BLenRatio(tt) $(ord(tt) GE 2 AND ord(tt) LE Nblock) = BLen(tt) / BLen(tt-1);
BLenRatio('t1') = BLen('t1');  # Antager at tilstande i tidspunktet lige før planperioden angives i timer.


# REMOVE UseFullYear = (NOT UseTimeAggr AND DurationPeriod EQ card(tt)) OR (LenRHhoriz EQ card(tt));
# REMOVE display UseFullYear;

*end Opsætning af tidsaggregering for aktuelle periode.


#--- execute_unload "MecLpMain.gdx";
#--- abort.noerror "BEVIDST STOP i LoopPeriodPre.gms";


