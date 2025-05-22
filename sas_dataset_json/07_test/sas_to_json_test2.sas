/*** HELP START ***//*

Sas dataset convert to Dataset-JSON(using SAS extended value)

*//*** HELP END ***/

proc datasets lib=mylib1 nolist;                             
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
%m_sas_to_json1_1(outpath = %sysfunc(pathname(work)),
                 library = mylib1,
                 dataset = adsl,
                 pretty = Y
);
