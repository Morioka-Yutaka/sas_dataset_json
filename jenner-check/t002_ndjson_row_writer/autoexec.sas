/* options obs=100; caps input rows for the captured run */
options obs=100;

/* ---- mock ADSL-shaped input rows, matching the shape and content of
   sas_dataset_json/04_data/adsl.sas's sample dataset, standing in for
   what %m_sas_to_ndjson1_1's caller would already have on hand. ---- */
data adsl;
  length STUDYID $20 USUBJID $20 RFSTDTC $10;
  STUDYID="XXXX-001"; USUBJID="YYYY-01"; RFSTDTC="2025-01-01"; AGE=41; output;
  STUDYID="XXXX-001"; USUBJID="YYYY-02"; RFSTDTC="2025-02-01"; AGE=51; output;
run;
