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
  Last update Date   : [2025-05-25] -- modified to not output data attributes with empty definitions.
  Version        : 0.12
  License        : MIT License

*//*** HELP END ***/

%macro m_json1_1_to_sas(inpath=,ds=);
filename js "&inpath\&ds..json" encoding="utf-8";
libname in json fileref=js ;
proc copy in = in out = work ;
run ;
libname in clear ;
filename js clear;

%local ds_label;
data _null_;
set root;
call symputx("name",name);
if ^missing(label) then do; 
  call symputx("ds_label",cats("label='",label,"'"));
end;
run;

data dummy_columns;
length targetDataType  displayFormat $200.;
call missing(of  targetDataType  displayFormat);
run;

data _null_;
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
 set columns end=eof;
 where name ne "ITEMGROUPDATASEQ";
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

%mend m_json1_1_to_sas;
