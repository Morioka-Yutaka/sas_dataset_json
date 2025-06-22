/*** HELP START ***//*

Macro Name    : %m_ndjson1_1_to_sas
  Description   : Imports CDISC-compliant NDJSON (Representation of Dataset-JSON) format (version 1.1) into a 
                   SAS dataset, reconstructing structure and metadata including extended attributes.

  Key Features:
	- Convert ndjson to dataset-json once internally
    - Reads dataset-JSON using the FILENAME and JSON LIBNAME engine
    - Extracts "root", "columns", and "rows" objects from JSON
    - Dynamically generates:
        - LABEL, FORMAT, and RENAME statements
        - INPUT conversion logic for ISO8601 date/datetime types
    - Automatically applies:
        - Dataset-level metadata via PROC DATASETS and XATTR
        - Variable-level extended attributes such as:
            - dataType
            - targetDataType
            - displayFormat
            - keySequence
            - length
    - Provides warnings for unsupported data types (e.g., decimal)

  Parameters:
    inpath : Path to the folder containing the dataset-JSON file
    ds     : SAS dataset name to create (derived from the file name)

  Requirements:
    - SAS 9.4M5 or later (for JSON LIBNAME engine and extended attributes)
    - Input JSON must follow the dataset-JSON v1.1 specification

  Notes:
    - "decimal" targetDataType is not natively supported in SAS;
      values are read as numeric using the `best.` format with a warning
    - Date and datetime values are parsed using `E8601DA.` and `E8601DT.` formats
    - Extended metadata attributes are added using PROC DATASETS/XATTR

  Example Usage:
    %m_ndjson1_1_to_sas(inpath=/data/definejson, ds=AE);

  Author         : [Yutaka Morioka]
  Created Date   : [2025-06-23]
  Version        : 0.13 (first)
  License        : MIT License

*//*** HELP END ***/

%macro m_ndjson1_1_to_sas(inpath=,ds=);

filename nljson "&inpath\&ds..ndjson";
filename json temp;
filename map temp;

/* Convert the NDJSON to JSON */
data ___wk1;
	infile nljson end=eof;
	do until (eof);
		input;
		line = _infile_;
    output;
	end;
run;

data ___wk2;
set ___wk1 end=eof;
file json;
if _N_= 1 then do;
  line =tranwrd(line,'}]}','}],"rows":[');
end;
if 1 < _N_ and ^eof then do;
   line =tranwrd(line, ']' , '],');
end;
if eof then do;
    line =tranwrd(line, ']' , ']]}');
end;
put line @;
run;

libname in json fileref=json ;
proc copy in = in out = work ;
run ;
libname in clear ;
filename json clear;

%local ds_label;
data _null_;
set root;
call symputx("name",name);
if ^missing(label) then do; 
  call symputx("ds_label",cats("label='",label,"'"));
end;
run;

data dummy_columns;
length targetDataType  displayFormat label  $200. keySequence 8.;
call missing(of  targetDataType  displayFormat label keySequence);
run;

data _null_;
length targetDataType  displayFormat label  $200. keySequence 8.;
set columns end=eof;
if 0 then set dummy_columns;
if ^missing(displayFormat) and index(displayFormat,".") = 0 then displayFormat = cats(displayFormat,".");

if missing(targetDataType) then do;
 call symputx( cats("rename",ordinal_columns), cats("rename element",ordinal_columns)||"="|| name||";" );
 call symputx( cats("label",ordinal_columns), cats("element",ordinal_columns)||"='"|| cats(label,"'") );
 if ^missing(displayFormat) then do;
  call symputx( cats("format",ordinal_columns), cats("element",ordinal_columns)||" "|| cats(displayFormat,"") );
 end;
 else do;
  call symputx( cats("format",ordinal_columns),"");
 end;
end;
else if ^missing(targetDataType) then do;
 if lowcase(targetDataType) = "integer" then do;
   if lowcase(dataType) = "date" then call symputx( cats("rename",ordinal_columns), name||"= input("||cats("element",ordinal_columns)||",?? E8601DA.); drop "||cats("element",ordinal_columns)||";" );
   else if lowcase(dataType) = "datetime" then call symputx( cats("rename",ordinal_columns), name||"= input("||cats("element",ordinal_columns)||",?? E8601DT.); drop "||cats("element",ordinal_columns)||";" );
end; 
 else if lowcase(targetDataType) = "decimal" then do;
   put "WARNING: The decimal type is not supported in SAS. Temporarily numerical in best. format." +2 name = ;
   call symputx( cats("rename",ordinal_columns), name||"= input("||cats("element",ordinal_columns)||",best.); drop "||cats("element",ordinal_columns)||";" );
 end; 

 call symputx( cats("label",ordinal_columns), name||"='"|| cats(label,"'") );
 if ^missing(displayFormat) then do;
  call symputx( cats("format",ordinal_columns), name||" "|| cats(displayFormat,"") );
 end;
 else do;
  call symputx( cats("format",name),"");
 end;
end;
if eof then call symputx("last_ordinal_columns",ordinal_columns);
run;
options mprint;

%macro create;
data &name(&ds_label drop= ordinal_root ordinal_rows );
  label
 %do i = 1 %to &last_ordinal_columns;
  &&label&i
 %end;
 ;
 set rows;
 %do i = 1 %to &last_ordinal_columns;
  &&rename&i
 %end;
 format
 %do i = 1 %to &last_ordinal_columns;
  &&format&i
 %end;
 ;
 ;
 run;

data _null_;
 set root;
 if _N_ = 1 then do;
  call execute("proc datasets nolist;");
  call execute("modify &ds;;");
  call execute("xattr add ds ");
  call execute(cats("datasetJSONCreationDateTime= '",datasetJSONCreationDateTime,"'"));
  call execute(cats("datasetJSONVersion= '",datasetJSONVersion,"'"));
  call execute(cats("fileOID= '",fileOID,"'"));
  call execute(cats("dbLastModifiedDateTime= '",dbLastModifiedDateTime,"'"));
  call execute(cats("originator= '",originator,"'"));
  call execute(cats("studyOID= '",studyOID,"'"));
  call execute(cats("metaDataVersionOID= '",metaDataVersionOID,"'"));
  call execute(cats("metaDataRef= '",metaDataRef,"'"));
  call execute(cats("itemGroupOID= '",itemGroupOID,"'"));
  call execute(cats("records= ",records,""));
  call execute(";run;quit;");
 end; 
run;

data _null_;
length targetDataType  displayFormat label $200.;
 set columns end=eof;
if 0 then set dummy_columns;
 if _N_ = 1 then do;
  call execute("proc datasets nolist;");
  call execute("modify &ds;");
  call execute("xattr add var ");
 end;
  call execute(cats(name,"("));
  if ^missing(dataType) then call execute(cats("dataType='",dataType,"'")); 
  if ^missing(targetDataType) then call execute(cats("targetDataType='",targetDataType,"'"));  
  if ^missing(displayFormat) then call execute(cats("displayFormat='",displayFormat,"'"));  
  if ^missing(length) then call execute(cats("length='",length,"'")); 
  if ^missing(keySequence) then call execute(cats("keySequence=",keySequence,""));  
  call execute(") ");
if eof then do;
  call execute(";run;quit;");
end;
run;
 
%mend create;

%create;

%mend m_ndjson1_1_to_sas;
