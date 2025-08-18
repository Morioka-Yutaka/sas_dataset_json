# sas_dataset_json
sas_dataset_json is a SAS macro package designed to support bi-directional conversion between CDISC-compliant Dataset-JSON format and SAS datasets.<br>

![sas_dataset_json](./sas_dataset_json_small.png)  
<img width="180" height="180" alt="Image" src="https://github.com/user-attachments/assets/b382f951-7c50-47aa-9a24-8ae7ba07260b" />

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


  Parameters:<br>
~~~text  
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
~~~
  Features:<br>
    - Automatically detects and prioritizes extended attributes for variables.<br>
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
~~~sas  
%m_sas_to_json1_1(outpath =/project/json_out,
                 library = adam,
                 dataset = adsl,
                 pretty = Y);
~~~
<br>

- [case 2] setting dataset-level metadata<br>
~~~sas  
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
~~~

- [case 3] set metadata by SAS extended attribute<br>
~~~sas  
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
                           displayFormat="E8601DA.") ;
   ;
run;
quit;
 %m_sas_to_json1_1(outpath = /project/json_out,
                 library = WORK,
                 dataset = adsl,
                 pretty = Y);
~~~


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
~~~text 
    inpath : Path to the folder containing the dataset-JSON file
    ds     : SAS dataset name to create (derived from the file name)
~~~
  Requirements:<br>
    - SAS 9.4M5 or later (for JSON LIBNAME engine and extended attributes)<br>
    - Input JSON must follow the dataset-JSON v1.1 specification<br>

  Notes:
    - "decimal" targetDataType is not natively supported in SAS;
      values are read as numeric using the `best.` format with a warning
    - Date and datetime values are parsed using `E8601DA.` and `E8601DT.` formats
    - Extended metadata attributes are added using PROC DATASETS/XATTR

  Example Usage:
~~~sas  
    %m_json1_1_to_sas(inpath=/data/definejson, ds=AE);
~~~

# %m_sas_to_ndjson1_1
  Description   : Exports a SAS dataset to NDJSON (Representation of Dataset-JSON) 
                  format (version 1.1). This macro is designed to
                  support clinical data interchange by generating

  Purpose       : 
    - To convert a SAS dataset into a structured NDJSON format(subset of Dataset-JSON version 1.1) .
    - Automatically extracts metadata such as labels, data types, formats,
      and extended attributes if defined.
    - Generates a metadata-rich datasetJSON with customizable elements.

  Parameters:
 ~~~text 
    outpath               : Path to output directory (default: WORK directory).
    library               : Library reference for input dataset (default: WORK).
    dataset               : Name of the input dataset (required).
    originator            : Organization or system creating the file (optional).
    fileOID               : File OID to uniquely identify the JSON (optional).
    studyOID              : Study OID used in the Define-XML reference (optional).
    metaDataVersionOID    : Metadata version OID (optional).
    sourceSystem_name     : Source system name (default: SAS on &SYSSCPL.).
    sourceSystem_version  : Source system version (default: from &SYSVLONG).]]
~~~

  Features:
    - Automatically detects and prioritizes extended attributes for variables.
    - Captures dataset-level metadata such as label and last modified date.
    - Outputs structured "columns" and rows part sections per dataset-JSON v1.1.0.

  Dependencies:
    - Requires access to `sashelp.vxattr`, `sashelp.vcolumn`, and `sashelp.vtable`.
    - Uses PROC JSON, PROC SQL, PROC CONTENTS, and extended attribute inspection.

  Notes:
    - Extended variable attributes (label, type, format, etc.) override defaults.
    - All variables are output with detailed metadata including data types,
      display formats, and lengths.
    - Output file is saved as "&outpath.\&dataset..ndjson".

  Example Usage:

- [case 1] default, simple use
~~~sas  
%m_sas_to_ndjson1_1(outpath =/project/json_out,
                 library = adam,
                 dataset = adsl,
);
~~~

- [case 2] setting dataset-level metadata
~~~sas  
    %m_sas_to_ndjson1_1(
      outpath=/project/json_out,
      library=SDTM,
      dataset=AE,
      originator=ABC Pharma,
      fileOID=http://example.org/studyXYZ/define,
      studyOID=XYZ-123,
      metaDataVersionOID=MDV.XYZ.1.0,
      sourceSystem_name=SAS 9.4,
      sourceSystem_version=9.4M7
    );
~~~

- [case 3] set metadata by SAS extended attribute
~~~sas  
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
                           displayFormat="E8601DA.");
 ; 
run;
quit;
 %m_sas_to_ndjson1_1(outpath = /project/json_out,
                 library = WORK,
                 dataset = adsl);
~~~

# %m_ndjson1_1_to_sas
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
~~~text 
    inpath : Path to the folder containing the dataset-JSON file
    ds     : SAS dataset name to create (derived from the file name)
~~~
  Requirements:
    - SAS 9.4M5 or later (for JSON LIBNAME engine and extended attributes)
    - Input JSON must follow the dataset-JSON v1.1 specification

  Notes:
    - "decimal" targetDataType is not natively supported in SAS;
      values are read as numeric using the `best.` format with a warning
    - Date and datetime values are parsed using `E8601DA.` and `E8601DT.` formats
    - Extended metadata attributes are added using PROC DATASETS/XATTR

  Example Usage:
  ~~~sas  
    %m_ndjson1_1_to_sas(inpath=/data/definejson, ds=AE);
~~~
# version history<br>
0.2.0(13Auguat2025):Bug Fix.  
0.1.3(23Jun2025): Support NDJSON, add %m_sas_to_ndjson1_1 and %m_ndjson1_1_to_sas
		  %m_sas_to_json1_1--Apply the e8601DT format to the LastModifiedDateTime.<br>
0.1.2(25May2025): %m_sas_to_json1_1--Modified to not output data attributes with empty definitions.<br>
0.1.1(23May2025): Add %m_json1_1_to_sas<br>
0.1.0(22May2025): Initial version<br>

## What is SAS Packages?  
The package is built on top of **SAS Packages framework(SPF)** developed by Bartosz Jablonski.
For more information about SAS Packages framework, see [SAS_PACKAGES](https://github.com/yabwon/SAS_PACKAGES).  
You can also find more SAS Packages(SASPACs) in [SASPAC](https://github.com/SASPAC).

## How to use SAS Packages? (quick start)
### 1. Set-up SPF(SAS Packages Framework)
Firstly, create directory for your packages and assign a fileref to it.
~~~sas      
filename packages "\path\to\your\packages";
~~~
Secondly, enable the SAS Packages Framework.  
(If you don't have SAS Packages Framework installed, follow the instruction in [SPF documentation](https://github.com/yabwon/SAS_PACKAGES/tree/main/SPF/Documentation) to install SAS Packages Framework.)  
~~~sas      
%include packages(SPFinit.sas)
~~~  
### 2. Install SAS package  
Install SAS package you want to use using %installPackage() in SPFinit.sas.
~~~sas      
%installPackage(packagename, sourcePath=\github\path\for\packagename)
~~~
(e.g. %installPackage(ABC, sourcePath=https://github.com/XXXXX/ABC/raw/main/))  
### 3. Load SAS package  
Load SAS package you want to use using %loadPackage() in SPFinit.sas.
~~~sas      
%loadPackage(packagename)
~~~
### Enjoy😁
