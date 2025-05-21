/*** HELP START ***//*

Sas dataset convert to Dataset-JSON(default)

*//*** HELP END ***/

%m_sas_to_json1_1(outpath = %sysfunc(pathname(work)),
                 library = mylib1,
                 dataset = adsl,
                 pretty = Y
);
