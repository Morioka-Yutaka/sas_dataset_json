# sas_dataset_json
sas_dataset_json is a SAS macro package designed to support bi-directional conversion between CDISC-compliant Dataset-JSON format and SAS datasets.<br>

# %m_sas_to_json1_1
  Description   : Exports a SAS dataset to Dataset-JSON 
                  format (version 1.1). This macro is designed to
                  support clinical data interchange by generating<br>

  Purpose       : <br>
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
