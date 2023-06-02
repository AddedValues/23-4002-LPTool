$log Entering file: %system.incName%
#(

$show

#begin    Reduce listing file size

* Reduce listing file size jf. https://support.gams.com/gams:how_do_i_reduce_the_size_of_my_listing_.lst_file

* Turn off the listing of the input file
#-$offlisting

* Turn off the listing and cross-reference of the symbols used
#-$offsymxref offsymlist

option
    limrow = 10,     #/* equations listed per block */
    limcol = 10,     #/* variables listed per block */
    solprint = on,  # solvers solution output printed
    sysout = on;    # solvers system output printed

#end

# Profiling optionen kan ikke sættes indenfor loops, derfor sættes den her.
#--- option profile=3;

#)


#begin Global settings

# Shorthand for boolean constants.
Scalar FALSE 'Shorthand for false = 0 (zero)' / 0 /;
Scalar TRUE  'Shorthand for true  = 1 (one)'  / 1 /;

# Shorthand for special numerical values. Se evt.:  https://www.gams.com/latest/docs/UG_Parameters.html#UG_Parameters_mapval

Scalar NORMAL   'Non-special'     / 0 /;
Scalar UNDF     'Undefined'       / 4 /;
Scalar NAN      'Not available'   / 5 /;
Scalar INFPlus  'Plus infinity'   / 6 /;
Scalar INFMinus 'Minus infinity'  / 7 /;
Scalar EPSILON  'Epsilon'         / 8 /;
Scalar PI                         / 3.1415926 /;
Scalar TKelvin  'Kelvin ved 0C'   / 273.15 /;


# Compile-time variables
$show
Scalar DayMax          'Max. antal dage beregnet ud fra timetal';
Scalar tiny            'small number'   / 1E-14 /;
Scalar big             'big number'     / 1E+09 /;
Scalar ordt            'Ord(t) ift. ord(tt)' / 99999 /;          # OBS: ord(t) af første yes-element i t er 1 uanset om TimeBegin er større end 1.

# Arbejdsvariable
Scalar Found      'Angiver at logisk betingelse er opfyldt';
Scalar FoundError 'Angiver at fejl er fundet';
Scalar pModelStat 'Opsamler modelSlave.ModelStat';

Scalar tmp  'temporary parm' / 9E+99 /;
Scalar tmp0 'temporary parm' / 9E+99 /;
Scalar tmp1 'temporary parm' / 9E+99 /;
Scalar tmp2 'temporary parm' / 9E+99 /;
Scalar tmp3 'temporary parm' / 9E+99 /;

Scalar PeriodObjScale 'Skala af master objective' / 1.0 /;  # DKK


$show

#end

