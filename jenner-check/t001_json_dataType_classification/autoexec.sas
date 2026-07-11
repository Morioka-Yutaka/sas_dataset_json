/* options obs=100; caps input rows for the captured run */
options obs=100;

/* ---- mock SASHELP.VCOLUMN-shaped input, standing in for the real
   dictionary-view read. This bundle exercises
   sas_dataset_json/06_macros/m_sas_to_json1_1.sas's dataType/
   targetDataType classification block directly, working around Jenner
   gaps hit while building this bundle: SASHELP.VCOLUMN rows for a
   non-WORK/non-SASHELP libref are unreliable when read through some
   paths (see jenner-language regression tests 403881/403896), the full
   macro's CALL EXECUTE-driven column-metadata loop was found to be
   intermittently nondeterministic during self-check, and a bare
   assignment to a variable named "format" is currently parsed as a
   FORMAT statement (see jenner-language regression test 403892) -- so
   the mock's format column is named _fmt below and read back as
   "format" only via the rename= used in script.sas's SET statement.
   The five mock rows reproduce the shapes of columns SASHELP.VCOLUMN
   would actually report for the package's own ADSL sample
   (sas_dataset_json/04_data/adsl.sas): two plain character columns,
   one numeric, and two columns whose SAS display formats are what the
   classification logic keys on (E8601DA. for a date, E8601DT. for a
   datetime) -- so real branches of the real logic fire, not just the
   "no format" default path. ---- */
data mock_vcolumn;
  length _name $32 Type $4 _fmt $49;
  length label $256;
  _name="STUDYID"; Type="CHAR"; _fmt="";         label="Study Identifier";                    _length=20; varnum=1; output;
  _name="USUBJID"; Type="CHAR"; _fmt="";         label="Unique Subject Identifier";            _length=20; varnum=2; output;
  _name="AGE";     Type="NUM";  _fmt="";         label="Age";                                  _length=8;  varnum=3; output;
  _name="RFSTDTC"; Type="NUM";  _fmt="E8601DA."; label="Subject Reference Start Date/Time";    _length=8;  varnum=4; output;
  _name="TRTSDTM"; Type="NUM";  _fmt="E8601DT."; label="Date/Time of First Exposure";          _length=8;  varnum=5; output;
run;
