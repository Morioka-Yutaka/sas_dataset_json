/*** HELP START ***//*

Macro Name    : %m_sas_to_json1_1
  Description   : Exports a SAS dataset to Dataset-JSON 
                  format (version 1.1). This macro is designed to
                  support clinical data interchange by generating

  Purpose       : 
    - To convert a SAS dataset into a structured Dataset-JSON format(version 1.1) .
    - Automatically extracts metadata such as labels, data types, formats,
      and extended attributes if defined.
    - Generates a metadata-rich datasetJSON with customizable elements.

  Input Parameters:
    outpath               : Path to output directory (default: WORK directory).
    library               : Library reference for input dataset (default: WORK).
    dataset               : Name of the input dataset (required).
    pretty                : Whether to pretty-print the JSON (Y/N, default: Y).
    originator            : Organization or system creating the file (optional).
    fileOID               : File OID to uniquely identify the JSON (optional).
    studyOID              : Study OID used in the Define-XML reference (optional).
    metaDataVersionOID    : Metadata version OID (optional).
    sourceSystem_name     : Source system name (default: SAS on &SYSSCPL.).
    sourceSystem_version  : Source system version (default: from &SYSVLONG).

  Features:
    - Automatically detects and prioritizes extended attributes for variables.
    - Adds sequential record identifiers (ITEMGROUPDATASEQ).
    - Captures dataset-level metadata such as label and last modified date.
    - Outputs structured "columns" and "rows" sections per dataset-JSON v1.1.0.

  Dependencies:
    - Requires access to `sashelp.vxattr`, `sashelp.vcolumn`, and `sashelp.vtable`.
    - Uses PROC JSON, PROC SQL, PROC CONTENTS, and extended attribute inspection.

  Notes:
    - Extended variable attributes (label, type, format, etc.) override defaults.
    - All variables are output with detailed metadata including data types,
      display formats, and lengths.
    - Output file is saved as "&outpath.\&dataset..json".

  Example Usage:

- [case 1] default, simple use
%m_sas_to_json1_1(outpath =/project/json_out,
                 library = adam,
                 dataset = adsl,
                 pretty = Y
);

- [case 2] setting dataset-level metadata
    %m_sas_to_json1_1(
      outpath=/project/json_out,
      library=SDTM,
      dataset=AE,
      pretty=Y,
      originator=ABC Pharma,
      fileOID=http://example.org/studyXYZ/define,
      studyOID=XYZ-123,
      metaDataVersionOID=MDV.XYZ.1.0,
      sourceSystem_name=SAS 9.4,
      sourceSystem_version=9.4M7
    );

- [case 3] set metadata by SAS extended attribute
proc datasets nolist;                             
   modify adsl;     
   xattr add ds originator="X corp."
                    fileOID="www.cdisc.org/StudyMSGv2/1/Define-XML_2.1.0/2024-11-11/"
          					studyOID="XX001-001"
          					metaDataVersionOID="MDV.MSGv2.0.SDTMIG.3.4.SDTM.2.0"
                    sourceSystem_name="SASxxxx"
                    sourceSystem_version="9.4xxxx"
	;  
   xattr add var 
                    STUDYID (label="Study Identifier"
                                 dataType="string"
                                 length=8
                                 keySequence=1) 
                    USUBJID (label="Unique Subject Identifier"
                                 dataType="string"
                                 length=7
                                 keySequence=2) 
                    RFSTDTC (label="Subject Reference Start Date/Time"
                                 dataType="date")
                    AGE (label="Age"
                           dataType="integer"
                           length=2)
                    TRTSDT (label="Date of First Exposure to Treatment"
                           dataType="date"
                           targetDataType="integer"
                           displayFormat="E8601DA.")

 ;

; 
run;
quit;
 %m_sas_to_json1_1(outpath = /project/json_out,
                 library = WORK,
                 dataset = adsl,
                 pretty = Y
);

Required SAS 9.4 and above

  Author         : [Yutaka Morioka]
  Created Date   : [2025-05-22]
  Last update Date   : [2025-05-23] -- delete ITEMGROUPDATASEQ 
  Version        : 0.1.2
  License        : MIT License

*//*** HELP END ***/

%macro m_sas_to_json1_1(
outpath=,
library=WORK,
dataset=,
pretty=Y,
originator=,
fileOID=,
studyOID=,
metaDataVersionOID=,
sourceSystem_name=,
sourceSystem_version=
);
%local outpath library dataset L_dataset pretty originator fileOID metaDataVersionOID sourceSystem_name sourceSystem_version;

/*Setting the output file storage location and dataset name*/
%if %length(&outpath) eq 0 %then %do;
 %let outpath = %sysfunc(pathname(WORK));
%end;
%let library=%upcase(&library);
%let dataset=%upcase(&dataset);
%let L_dataset=%lowcase(&dataset);

/*Inspect the extended attributes of the dataset part and prioritise them if any.*/
data _null_;
 set sashelp.vxattr;
 where missing(name);
 where same libname = "&library";
 where same memname = "&dataset";
 call symputx(xattr,xvalue,"L");
run;
/*Default value if no parameters are specified and no extended attributes*/
%if %length(&originator) eq 0 %then %do;
  %let originator = DUMMY Corporation;
%end;
%if %length(&fileOID) eq 0 %then %do;
  %let fileOID = www.cdisc.org/StudyMSGv2/1/Define-XML_2.1.0/2024-11-11/;
%end;
%if %length(&studyOID) eq 0 %then %do;
  %let studyOID = DUMMY-111;
%end;
%if %length(&metaDataVersionOID) eq 0 %then %do;
  %let metaDataVersionOID = MDV.MSGv2.0.SDTMIG.3.3.SDTM.1.7;
%end;
%if %length(&sourceSystem_name) eq 0 %then %do;
  %let sourceSystem_name = SAS on &SYSSCPL.;
%end;
%if %length(&sourceSystem_version) eq 0 %then %do;
  %let	sourceSystem_version =%sysfunc(scan( &SYSVLONG,1,P));
%end;


/*Set dataset labels and last update dates*/
data _null_;
set sashelp.vtable;
 where same libname = "&library";
 where same memname = "&dataset";
call symputx("DS_LABEL",memlabel);
call symputx("dbLastModifiedDateTime",modate);
run;

/*Setting the creation date and time of the JSON file.*/
data _null_;
call symputx("creationDateTime",put(datetime(),e8601dt.));
run;

/*Obtaining the number of observations*/
proc sql  ;
 select count(*) into: tot_obs
 from &library..&dataset
;
quit;

/*Getting extended attributes of variables*/
data var_exattr;
 set sashelp.vxattr;
 where^ missing(name);
 where same libname = "&library";
 where same memname = "&dataset";
run;
proc sort data=var_exattr;
 by name;
run;
proc transpose data=var_exattr out=var_exattr_t(where=(^missing(NAME))) prefix=_;
var  xvalue;
 id xattr;
 by name;
run;

/*Avoiding initialisation WARNING.*/
data columns_0;
length itemOID name label dataType targetDataType  displayFormat format  $200. length keySequence 8. ;
call missing(of _all_);
run;
/*Setting variable definitions*/
data columns_1;
length itemOID name label dataType targetDataType  displayFormat  format $200. 
length keySequence 8. ;
 if 0 then set columns_0;
set sashelp.vcolumn(rename=(name=_name label=_label length=_length));
where libname = upcase("&library.");
where same memname = upcase("&dataset.");
  call missing(of displayFormat);
  itemOID = cats("IT.","&dataset..",_name);
  name = _name;  
  label=_label;
  displayFormat=format;
  if upcase(Type) in ("NUM") then dataType="integer";
  else if upcase(Type) in ("CHAR") then dataType="string";
  length = _length;
  keySequence = .;
  num =varnum;
 if index(upcase(displayFormat),"TIME") > 0
    | index(upcase(displayFormat),"TOD") > 0
    | index(upcase(displayFormat),"HOUR") > 0
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



  keep Num itemOID name label dataType targetDataType  length displayFormat length keySequence ;
run;

proc sort data=columns_1;
 by name;
run;
/*Avoiding initialisation WARNING.*/
data dummy_Var_exattr_t;
length _label _dataType _targetDataType _displayFormat _length _keySequence $200. ;
call missing(of _all_);
run;
/*Extended attributes, if any, take precedence.*/
data columns_2;
 merge columns_1 Var_exattr_t;
 by name;
 if 0 then set dummy_Var_exattr_t;
 if ^missing(_label) then label=_label;
 if ^missing(_dataType) then dataType=_dataType;
 if ^missing(_targetDataType) then targetDataType=_targetDataType;
 if ^missing(_displayFormat) then displayFormat=_displayFormat;
 if ^missing(_length) then length=input(_length,best.);
 if ^missing(_keySequence) then keySequence=input(_keySequence,best.);

run;
proc sort data=columns_2 out=columns(drop =num _:);
 by num;
run;
data columns;
 set columns;
 dummyn=.;
 dummyc="";
run;

data _null_;
  set columns end=eof;
  dummyn=.;
  dummyc="";
  call execute(cats("data r",_N_,"_columns;"));
  call execute("set columns;");
  call execute(cats("where monotonic() =",_N_,";"));
  array arc _character_;
  array arn _numeric_;
  do over arc;
    if missing(arc) then call execute(catx(" ","drop",vname(arc),";"));
  end;
  do over arn;
    if missing(arn) then call execute(catx(" ","drop",vname(arn),";"));
  end;
  if eof then call symputx("columns_n",_N_);
  call execute("run;");
run;

/*==================
Output JSON
====================*/
proc json out = "&outpath.\&L_dataset..json" 
  %if %upcase(&pretty)=Y %then %do;pretty %end;
  nofmtdatetime;
write open object ;
write values "datasetJSONCreationDateTime"  "&creationDateTime";
write values  "datasetJSONVersion"  "1.1.0";
write values  "fileOID"  "&fileOID./&L_dataset.";
write values  "dbLastModifiedDateTime"  "&dbLastModifiedDateTime";
write values  "originator"  "&originator";
write values   "sourceSystem";
 write open object;
   write values  "name" "&sourceSystem_name";
   write values "version" "&sourceSystem_version";
  write close;
write values "studyOID"  "&studyOID";
write values  "metaDataVersionOID"  "&metaDataVersionOID";
write values  "metaDataRef"  "define.xml";
write values "itemGroupOID" "IG.&dataset";
write values "records" &tot_obs. ;
write values "name" "&dataset" ;
write values "label" "&DS_LABEL" ;

write values "columns" ;/* attribute array */
 write open array;
  %do i = 1 %to &columns_n.;
    export r&i._columns /   nosastags;
  %end;
write close;

 write values "rows" ;/* record array */
 write open array;
      export &library..&dataset. / nokeys fmtdatetime nosastags;
  write close;
write close;
run ;

%mend m_sas_to_json1_1;
