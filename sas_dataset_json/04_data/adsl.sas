/*** HELP START ***//*

[Sample data] dummy-adsl

*//*** HELP END ***/

data mylib1.adsl(label="Subject-Level Analysis Dataset");
attrib
 STUDYID label="Study Identifier" length=$20.
 USUBJID label="Unique Subject Identifier" length=$20.
 RFSTDTC label="Subject Reference Start Date/Time" length=$10.
 AGE label="Age" length=8.
 TRTSDT label="Date of First Exposure to Treatment" length=8. format=E8601DA.
;
STUDYID ="XXXX-001";USUBJID="YYYY-01";RFSTDTC="2025-01-01";AGE=41;TRTSDT="01Jun2025"d;output;
STUDYID ="XXXX-001";USUBJID="YYYY-02";RFSTDTC="2025-02-01";AGE=51;TRTSDT="01Feb2025"d;output;
run;
