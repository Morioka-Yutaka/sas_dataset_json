/* Adapted from sas_dataset_json/06_macros/m_sas_to_json1_1.sas, the
   "Setting variable definitions" DATA step inside %m_sas_to_json1_1
   (the column-metadata block that classifies each SAS variable into a
   CDISC Dataset-JSON v1.1 dataType/targetDataType pair from its SAS
   display format). The logic below -- the four IF/INDEX/UPCASE blocks
   -- is unchanged from upstream. Only the input source changed: it
   reads the mock_vcolumn dataset built in autoexec.sas (standing in
   for a SASHELP.VCOLUMN row set) instead of SASHELP.VCOLUMN itself,
   and a few small variable-naming/declaration-order adjustments work
   around Jenner parser gaps hit while building this bundle: the
   working length variable is called _len rather than length, and the
   working display-format variable is renamed from mock_vcolumn's _fmt
   to format only via SET's rename= (never assigned as a bare
   statement) -- Jenner currently parses a bare "length = expr;" or
   "format = expr;" assignment as the start of the corresponding
   global statement rather than a plain assignment (jenner-language
   regression test 403892), and reading format as a plain right-hand
   value (never assigning to it) is unaffected. The LENGTH statement
   below also lists FORMAT before LABEL rather than the upstream order
   (LABEL immediately followed by FORMAT in one LENGTH statement's
   variable list currently fails to parse -- jenner-language regression
   test 403910). None of these affect the exported column names or
   values -- only how the intermediate working variables are declared
   and populated. */

data columns_1;
length itemOID name format dataType targetDataType displayFormat label $200.;
length _len 8.;
set mock_vcolumn(rename=(label=_label _fmt=format));
  itemOID = cats("IT.","ADSL.",_name);
  name = _name;
  label = _label;
  displayFormat = format;
  if upcase(Type) in ("NUM") then dataType="integer";
  else if upcase(Type) in ("CHAR") then dataType="string";
  _len = _length;
  keySequence = .;
  num = varnum;
 if index(upcase(displayFormat),"TIME") > 0
    | index(upcase(displayFormat),"TOD") > 0
    | index(upcase(displayFormat),"HOUR") > 0
    | index(upcase(displayFormat),"TIMEAMPM") > 0
    | index(upcase(displayFormat),"8601TM") > 0
    then do;
    dataType = "time";
    targetDataType ="integer";
  end;
 if index(upcase(displayFormat),"DATE") > 0
    | index(upcase(displayFormat),"DDMMYY") > 0
    | index(upcase(displayFormat),"MMDDYY") > 0
    | index(upcase(displayFormat),"YYMMDD") > 0
    | index(upcase(displayFormat),"8601DA") > 0
    then do;
    dataType = "date";
    targetDataType ="integer";
  end;
 if index(upcase(displayFormat),"DATETIME") > 0
    | index(upcase(displayFormat),"DATEAMPM") > 0
    | index(upcase(displayFormat),"8601DT") > 0
    then do;
    dataType = "datetime";
    targetDataType ="integer";
  end;
  keep Num itemOID name label dataType targetDataType _len displayFormat keySequence;
  rename _len = length;
run;

proc sort data=columns_1 out=columns_1_sorted;
  by num;
run;

proc print data=columns_1_sorted noobs;
  var name dataType targetDataType displayFormat length;
run;
