/*** HELP START ***//*

Sas dataset convert to Dataset-JSON(default)

*//*** HELP END ***/

%m_sas_to_json1_1(outpath = %sysfunc(pathname(work)),
                 library = mylib1,
                 dataset = adsl,
                 pretty = Y
);
proc datasets lib=work memtype=data nolist;
  delete adsl_1 columns columns_0 columns_1 columns_2 Dummy_var_exattr_t Position Var_exattr Var_exattr_t ;
quit;
