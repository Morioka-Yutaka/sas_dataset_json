/* Adapted from sas_dataset_json/06_macros/m_sas_to_ndjson1_1.sas, the
   NDJSON row-writing DATA _null_ step near the end of %m_sas_to_ndjson1_1
   -- the code that formats each observation of the source dataset as one
   line of a JSON array (the NDJSON "rows" representation of Dataset-JSON
   v1.1). This block is driven entirely by the macro variables
   _vname{i}/_vtype{i}/_num_of_var, which the full macro populates from a
   SASHELP.VCOLUMN scan; here they are supplied directly (matching the
   3-variable shape of the package's own mock ADSL dataset:
   sas_dataset_json/04_data/adsl.sas) so this bundle exercises the actual
   row-formatting logic without going through the macro's
   SASHELP.VCOLUMN/CALL EXECUTE column-metadata collection, which was
   found to be intermittently nondeterministic on Jenner during
   self-check of a full %m_sas_to_ndjson1_1 call (see meta.json). The
   IF/PUT logic below, including the trailing-comma and quote-escaping
   handling, is unchanged from the macro except for one substitution:
   upstream writes character values as "put '"' temp~ +(-1) '"' @;",
   using PUT's tilde (~) format modifier to add the surrounding quotes.
   Jenner mishandles that modifier's trailing-blank/pointer-backup
   interaction (see jenner-language regression test 403920), so the
   tilde is dropped here -- the surrounding literal quotes the macro
   already writes make the tilde's own auto-quoting redundant, so
   "put '"' temp +(-1) '"' @;" (plain list output) produces byte-
   identical NDJSON output. */

%let _vname1 = STUDYID;  %let _vtype1 = string;
%let _vname2 = USUBJID;  %let _vtype2 = string;
%let _vname3 = AGE;      %let _vtype3 = integer;
%let _num_of_var = 3;

filename outndj "%sysfunc(pathname(work))/adsl.ndjson";
data _null_;
length temp $32767.;
  set adsl;
  call missing(temp);
  file outndj mod;
  if _N_=1 then put;
  put "[" @;
  %do i  = 1 %to  %eval(&_num_of_var - 1);
    %if %lowcase(&&_vtype&i) ^= integer and
         %lowcase(&&_vtype&i) ^= float and
         %lowcase(&&_vtype&i) ^= double and
         %lowcase(&&_vtype&i) ^= boolean
    %then %do;
      if not missing(&&_vname&i) then do;
          temp=tranwrd(vvalue(&&_vname&i) ,'"','\"');
          put '"' temp +(-1) '"' @;
      end;
      else put '""' @;
      put "," @;
    %end;
    %else %if
         %lowcase(&&_vtype&i) = integer or
         %lowcase(&&_vtype&i) = float or
         %lowcase(&&_vtype&i) = double or
         %lowcase(&&_vtype&i) = boolean
      %then %do;
      if not missing(&&_vname&i) then put &&_vname&i +(-1) @;
      else put "null" @;
      put "," @;
    %end;
  %end;
  %do i  = &_num_of_var %to  &_num_of_var;
    %if %lowcase(&&_vtype&i) ^= integer and
         %lowcase(&&_vtype&i) ^= float and
         %lowcase(&&_vtype&i) ^= double and
         %lowcase(&&_vtype&i) ^= boolean
    %then %do;
      if not missing(&&_vname&i) then put '"' &&_vname&i +(-1) '"' @;
      else put '""' @;
    %end;
    %else %if
         %lowcase(&&_vtype&i) = integer or
         %lowcase(&&_vtype&i) = float or
         %lowcase(&&_vtype&i) = double or
         %lowcase(&&_vtype&i) = boolean
      %then %do;
      if not missing(&&_vname&i) then put &&_vname&i +(-1) @;
      else put "null" @;
    %end;
  %end;
  put "]";
run;
filename outndj clear;

/* Read the generated NDJSON back so the listing shows the payload this
   logic actually produced. */
data _null_;
  infile "%sysfunc(pathname(work))/adsl.ndjson" lrecl=32767;
  input;
  put _infile_;
run;
