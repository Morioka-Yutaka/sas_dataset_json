# sas_dataset_json(latest version 0.1.2 on 25may2025)
sas_dataset_json is a SAS macro package designed to support bi-directional conversion between CDISC-compliant Dataset-JSON format and SAS datasets.<br>

<img width="180" alt="Image" src="https://github.com/user-attachments/assets/efdeab76-093f-436c-a3be-516b20684426" />

# 日本ユーザー向け，日本語説明資料
 https://www.docswell.com/s/6484025/5WW7G4-2025-05-26-023206

# %m_sas_to_json1_1
  Description   : <br>
  		　Exports a SAS dataset to Dataset-JSON 
                  format (version 1.1). <br>

  Purpose       : <br>
    - To convert a SAS dataset into a structured Dataset-JSON format(version 1.1) .<br>
    - Automatically extracts metadata such as labels, data types, formats,
      and extended attributes if defined.<br>
    - Generates a metadata-rich datasetJSON with customizable elements.<br>

  Input Parameters:<br>
    outpath               : Path to output directory (default: WORK directory).<br>
    library               : Library reference for input dataset (default: WORK).<br>
    dataset               : Name of the input dataset (required).<br>
    pretty                : Whether to pretty-print the JSON (Y/N, default: Y).<br>
    originator            : Organization or system creating the file (optional).<br>
    fileOID               : File OID to uniquely identify the JSON (optional).<br>
    studyOID              : Study OID used in the Define-XML reference (optional).<br>
    metaDataVersionOID    : Metadata version OID (optional).<br>
    sourceSystem_name     : Source system name (default: SAS on &SYSSCPL.).<br>
    sourceSystem_version  : Source system version (default: from &SYSVLONG).<br>

  Features:<br>
    - Automatically detects and prioritizes extended attributes for variables.<br>
    - Adds sequential record identifiers (ITEMGROUPDATASEQ).<br>
    - Captures dataset-level metadata such as label and last modified date.<br>
    - Outputs structured "columns" and "rows" sections per dataset-JSON v1.1.0.<br>

  Dependencies:<br>
    - Requires access to `sashelp.vxattr`, `sashelp.vcolumn`, and `sashelp.vtable`.<br>
    - Uses PROC JSON, PROC SQL, PROC CONTENTS, and extended attribute inspection.<br>

  Notes:<br>
    - Extended variable attributes (label, type, format, etc.) override defaults.<br>
    - All variables are output with detailed metadata including data types,<br>
      display formats, and lengths.<br>
    - Output file is saved as "&outpath.\&dataset..json".<br>

  Example Usage:<br>
- [case 1] default, simple use<br>
%m_sas_to_json1_1(outpath =/project/json_out,<br>
                 library = adam,<br>
                 dataset = adsl,<br>
                 pretty = Y<br>
);<br>

- [case 2] setting dataset-level metadata<br>
    %m_sas_to_json1_1(<br>
      outpath=/project/json_out,<br>
      library=SDTM,<br>
      dataset=AE,<br>
      pretty=Y,<br>
      originator=ABC Pharma,<br>
      fileOID=http://example.org/studyXYZ/define,<br>
      studyOID=XYZ-123,<br>
      metaDataVersionOID=MDV.XYZ.1.0,<br>
      sourceSystem_name=SAS 9.4,<br>
      sourceSystem_version=9.4M7<br>
    );<br>

- [case 3] set metadata by SAS extended attribute<br>
proc datasets nolist;                             <br>
   modify adsl;     <br>
   xattr add ds originator="X corp."<br>
                    fileOID="www.cdisc.org/StudyMSGv2/1/Define-XML_2.1.0/2024-11-11/"<br>
          					studyOID="XX001-001"<br>
          					metaDataVersionOID="MDV.MSGv2.0.SDTMIG.3.4.SDTM.2.0"<br>
                    sourceSystem_name="SASxxxx"<br>
                    sourceSystem_version="9.4xxxx"<br>
	;  <br>
   xattr add var <br>
                    STUDYID (label="Study Identifier"<br>
                                 dataType="string"<br>
                                 length=8<br>
                                 keySequence=1) <br>
                    USUBJID (label="Unique Subject Identifier"<br>
                                 dataType="string"<br>
                                 length=7<br>
                                 keySequence=2) <br>
                    RFSTDTC (label="Subject Reference Start Date/Time"<br>
                                 dataType="date")<br>
                    AGE (label="Age"<br>
                           dataType="integer"<br>
                           length=2)<br>
                    TRTSDT (label="Date of First Exposure to Treatment"<br>
                           dataType="date"<br>
                           targetDataType="integer"<br>
                           displayFormat="E8601DA.")<br>

 ;<br>
<br>
; <br>
run;<br>
quit;<br>
 %m_sas_to_json1_1(outpath = /project/json_out,
                 library = WORK,
                 dataset = adsl,
                 pretty = Y
);

# %m_json1_1_to_sas
 Description   : <br>
 		Imports CDISC-compliant dataset-JSON v1.1 into a 
                   SAS dataset, reconstructing structure and metadata including extended attributes.<br>

  Key Features:<br>
    - Reads dataset-JSON using the FILENAME and JSON LIBNAME engine<br>
    - Extracts "root", "columns", and "rows" objects from JSON<br>
    - Dynamically generates:<br>
        - LABEL, FORMAT, and RENAME statements<br>
        - INPUT conversion logic for ISO8601 date/datetime types<br>
    - Automatically applies:<br>
        - Dataset-level metadata via PROC DATASETS and XATTR<br>
        - Variable-level extended attributes such as:<br>
            - dataType<br>
            - targetDataType<br>
            - displayFormat<br>
            - keySequence<br>
            - length<br>
    - Provides warnings for unsupported data types (e.g., decimal)<br>

  Parameters:<br>
    inpath : Path to the folder containing the dataset-JSON file<br>
    ds     : SAS dataset name to create (derived from the file name)<br>

  Requirements:<br>
    - SAS 9.4M5 or later (for JSON LIBNAME engine and extended attributes)<br>
    - Input JSON must follow the dataset-JSON v1.1 specification<br>

  Notes:
    - "decimal" targetDataType is not natively supported in SAS;
      values are read as numeric using the `best.` format with a warning
    - Date and datetime values are parsed using `E8601DA.` and `E8601DT.` formats
    - Extended metadata attributes are added using PROC DATASETS/XATTR

  Example Usage:<br>
    %m_json1_1_to_sas(inpath=/data/definejson, ds=AE);<br>

# version history<br>
0.1.2(25May2025): %m_sas_to_json1_1--Modified to not output data attributes with empty definitions.<br>
0.1.1(23May2025): Add %m_json1_1_to_sas<br>
0.1.0(22May2025): Initial version<br>

# What is SAS Packages?
sashash is built on top of **SAS Packages framework(SPF)** created by Bartosz Jablonski.<br>
For more on SAS Packages framework, see [SASPAC](https://github.com/yabwon/SAS_PACKAGES).<br>
You can also find more SAS Packages(SASPAC) in [GitHub](https://github.com/SASPAC)<br>
