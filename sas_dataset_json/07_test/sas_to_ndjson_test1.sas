/*** HELP START ***//*

Sas dataset convert to ndjson(default)

*//*** HELP END ***/

%m_sas_to_jndson1_1(outpath = %sysfunc(pathname(work)),
                 library = mylib1,
                 dataset = adsl,
);
proc datasets lib=work memtype=data nolist;
  delete 
ADSL
COLUMNS
COLUMNS_0
COLUMNS_1
COLUMNS_2
COLUMNS_3
DUMMY_VAR_EXATTR_T
R1_COLUMNS
R2_COLUMNS
R3_COLUMNS
R4_COLUMNS
R5_COLUMNS
VAR_EXATTR
VAR_EXATTR_T
 ;
quit;
