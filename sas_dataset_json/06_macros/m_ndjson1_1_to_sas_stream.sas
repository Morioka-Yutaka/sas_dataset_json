/*** HELP START ***//*

Macro Name : %m_ndjson1_1_to_sas_stream

Description:
  Imports a CDISC Dataset-JSON 1.1 NDJSON file into a SAS dataset while
  processing the data portion in chunks.  The first physical line is treated
  as the Dataset-JSON metadata line.  Each remaining physical line is treated
  as one NDJSON data line.

Parameters:
  inpath   : Directory containing <ds>.ndjson
  ds       : Input file stem and output SAS dataset name
  outlib   : Output SAS library (default: WORK)
  chunksize: Number of NDJSON data lines processed per chunk (default: 10000)
  obs      : Optional maximum number of data lines to read from the beginning.
             If omitted, all data lines are read.
  where    : Optional SAS expression evaluated after conversion, for example
             %str(SEXN = 1 and AGE >= 65)
  keep     : Optional SAS variable list retained in the completed dataset, for
             example USUBJID PARAMCD AVAL or %str(USUBJID PARAM:)

Requirements:
  - SAS 9.4M5 or later
  - Dataset-JSON 1.1 NDJSON representation
  - The first line contains root/columns metadata and each subsequent line
    contains a JSON row array

Notes:
  - CHUNKSIZE counts physical NDJSON data lines, not necessarily observations.
  - OBS counts data lines only; the first metadata line is not included.
    When OBS is specified, lines after that limit are not scanned or parsed.
  - WHERE reduces the records written to the output dataset.  It does not
    reduce the amount of input read or JSON parsed.
  - KEEP is applied after WHERE in each chunk.  A variable used only by WHERE
    therefore does not need to be included in KEEP.
  - The output dataset is replaced only after all chunks complete.

Example:
  %m_ndjson1_1_to_sas_stream(
      inpath=C:\data,
      ds=ADSL,
      outlib=OUTLIB,
      chunksize=10000,
      obs=1000,
      where=%str(SEXN = 1),
      keep=USUBJID AGE SEX
  );

*//*** HELP END ***/

%macro m_ndjson1_1_to_sas_stream(
    inpath=,
    ds=,
    outlib=WORK,
    chunksize=10000,
    obs=,
    where=,
    keep=
  );

%local
  _ndj_abort
  _ndj_path
  _ndj_nlines
  _ndj_nchunks
  _ndj_chunk
  _ndj_firstobs
  _ndj_obs
  _ndj_nvars
  _ndj_label_stmt
  _ndj_expected
  _ndj_actual
  _ndj_i
  _ndj_tmpds
  _ndj_nlabels
  _ndj_nformats
  _ndj_filtered
  _ndj_rename_list
  _ndj_keep_rc
;
  %let _ndj_abort=0;
  %let _ndj_nlines=0;
  %let _ndj_nchunks=0;
  %let _ndj_expected=.;
  %let _ndj_actual=0;
  %let _ndj_filtered=0;
  %let _ndj_label_stmt=;
  %let _ndj_nlabels=0;
  %let _ndj_nformats=0;
  %let _ndj_rename_list=;
  %let _ndj_keep_rc=0;

  %let _ndj_tmpds=___ndj_inprogress;

  /* Basic parameter validation. */

  %if %superq(inpath)= %then %do;
    %put ERROR: [NDJSON STREAM] INPATH is required.;
    %let _ndj_abort=1;
  %end;
  %if %superq(ds)= %then %do;
    %put ERROR: [NDJSON STREAM] DS is required.;
    %let _ndj_abort=1;
  %end;
  %if %sysfunc(libref(&outlib)) ne 0 %then %do;
    %put ERROR: [NDJSON STREAM] Library &outlib is not assigned.;
    %let _ndj_abort=1;
  %end;
  %if %sysevalf(%superq(chunksize) < 1) %then %do;
    %put ERROR: [NDJSON STREAM] CHUNKSIZE must be a positive integer.;
    %let _ndj_abort=1;
  %end;
  %if %length(%superq(obs)) %then %do;
    %if %sysfunc(prxmatch(%str(/^[0-9]+$/),%superq(obs))) ne 1 %then %do;
      %put ERROR: [NDJSON STREAM] OBS must be a positive integer.;
      %let _ndj_abort=1;
    %end;
    %else %if %sysevalf(%superq(obs) < 1) %then %do;
      %put ERROR: [NDJSON STREAM] OBS must be a positive integer.;
      %let _ndj_abort=1;
    %end;
  %end;

  %if &_ndj_abort %then %goto ndj_exit;

  %let _ndj_path=&inpath/%superq(ds).ndjson;
  filename _ndjin "&_ndj_path" encoding='UTF-8' lrecl=32767; /* For metadata, number of data lines */
  filename _ndjdat "&_ndj_path" encoding='UTF-8' lrecl=32767; /* For chunking */

  /* Check if ndjson file exists */
  %if not %sysfunc(fexist(_ndjin)) %then %do;
    %put ERROR: [NDJSON STREAM] Input file does not exist: &_ndj_path;
    %let _ndj_abort=1;
    %goto ndj_cleanup;
  %end;

  /*
     Count the physical data lines that will be processed.  The first physical
     line is metadata.  With OBS=, stop the scan after OBS data lines.
  */
  data _null_;
    infile _ndjin
      %if %length(%superq(obs)) %then %do;
        obs=%eval(%superq(obs) + 1)
      %end;
      end=_ndj_eof truncover;

    retain _ndj_count 0;
    input;
    if _n_ > 1 then do;
      _ndj_count + 1;
      call symputx('_ndj_nlines', _ndj_count, 'L');
    end;
  run;

  /* Check if one or more data lines exist */
  %if %sysevalf(&_ndj_nlines=0) %then %do;
    %put ERROR: [NDJSON STREAM] No NDJSON data lines were found.;
    %let _ndj_abort=1;
    %goto ndj_cleanup;
  %end;

  /* Number of chunks */
  %let _ndj_nchunks=%sysfunc(ceil(%sysevalf(&_ndj_nlines/&chunksize)));

  /* Read and parse the metadata line only once. */
  filename _ndjmeta temp lrecl=32767;
  data _null_;
    infile _ndjin obs=1 truncover; /* only the first line(metadata) */
    file _ndjmeta;
    input;
    put _infile_;
  run;

  libname _ndjm json fileref=_ndjmeta;

  data work.___ndj_root;
    set _ndjm.root; /* root from JSON */
  run;
  data work.___ndj_columns;
    set _ndjm.columns; /* columns from JSON */
  run;

  libname _ndjm clear;
  filename _ndjmeta clear;

  /* Prepare optional metadata columns that may not be created by JSON. */
  data work.___ndj_dummy_root;
    length name label datasetJSONCreationDateTime datasetJSONVersion fileOID
           dbLastModifiedDateTime originator studyOID metaDataVersionOID
           metaDataRef itemGroupOID $500 records 8;
    call missing(of _all_);
  run;
  data work.___ndj_root;
    if 0 then set work.___ndj_dummy_root;
    set work.___ndj_root;
  run;

  data work.___ndj_dummy_columns;
    length targetDataType displayFormat label $200 keySequence length 8;
    call missing(of _all_);
  run;
  data work.___ndj_columns;
    if 0 then set work.___ndj_dummy_columns;
    set work.___ndj_columns;
  run;

  /* Dataset metadata. */
  data _null_;
    set work.___ndj_root(obs=1);
    if not missing(label) then
		call symputx('_ndj_label_stmt', trim(label), 'L'); 
    if not missing(records) then call symputx('_ndj_expected', records, 'L');
  run;

  /*
     Generate code fragments once.  They are reused for every chunk.
     The JSON engine exposes row-array members as ELEMENT1, ELEMENT2, etc.
  */

	data _null_;

	  length
	    _ndj_source   $32
	    _ndj_informat $12
	    _ndj_convert  $1000
	    _ndj_rename   $1000
	    _ndj_rename_list $32767
	    _ndj_label    $1000
	    _ndj_format   $1000
	    _ndj_length   $1000
	  ;

	  set work.___ndj_columns end=_ndj_eof;

	  /* Variables name on JSON engine(element1, element2,...) */
	  _ndj_source = cats("element", ordinal_columns);

	  retain _ndj_rename_list "";

	  /* Character length using the final variable name. */
	  _ndj_length = "";

	  if lowcase(dataType) = "string" and not missing(length) then
	    _ndj_length = catx(
	      " ",
	      "length",
	      nliteral(strip(name)),
	      cats("$", strip(put(length, best.)), ";")
	    );

	  call symputx(
	    cats("_ndj_length", ordinal_columns),
	    _ndj_length,
	    "L"
	  ); /* e.g. _ndj_length1 = "length USUBJID $20;" */

	  /*
	     Rename ordinary variables as they enter the PDV. This makes the final
	     names available to the optional WHERE expression in the same DATA step.
	  */
	  _ndj_rename = cats(_ndj_source, "=", nliteral(strip(name)));
	  _ndj_convert = "";

	  if lowcase(targetDataType) in ("integer", "decimal") then do;
	    _ndj_rename = "";

	    _ndj_informat = "best32.";

	    select (lowcase(dataType));
	      when ("date")
	        _ndj_informat = "e8601da.";
	      when ("datetime")
	        _ndj_informat = "e8601dt.";
	      when ("time")
	        _ndj_informat = "e8601tm.";
	      otherwise;
	    end;

	    _ndj_convert = catx(
	      " ",
	      cats(
	        nliteral(strip(name)),
	        "=input(cats(", _ndj_source, "),"
	      ),
	      "??",
	      cats(_ndj_informat, ");"),
	      "drop",
	      cats(_ndj_source, ";")
	    );

	  end;

	  if not missing(_ndj_rename) then
	    _ndj_rename_list = catx(" ", _ndj_rename_list, _ndj_rename);

	  call symputx(
	    cats("_ndj_convert", ordinal_columns),
	    _ndj_convert,
	    "L"
	  ); /* e.g. _ndj_convert = "SEXN=input(cats(element2),?? best32.); drop element2;" */

	/* Variable label */
	  _ndj_label = "";

		if not missing(label) then
		  _ndj_label = cats(
		    nliteral(strip(name)),
		    "='",
		    tranwrd(strip(label), "'", "''"),
		    "'"
		  );

	  call symputx(
	    cats("_ndj_label", ordinal_columns),
	    _ndj_label,
	    "L"
	  ); /* e.g. _ndj_label = "SEXN='Gender';" */

	/* display format */

	  _ndj_format = "";

	  if not missing(displayFormat) then do;

	    if index(displayFormat, ".") = 0 then
	      displayFormat = cats(displayFormat, ".");

	    _ndj_format = catx(
	      " ", nliteral(strip(name)), displayFormat
	    );

	  end;

	  call symputx(
	    cats("_ndj_format", ordinal_columns),
	    _ndj_format,
	    "L"
	  );


	  /* Number of variables and SET RENAME= list. */
	  if _ndj_eof then do;
	    call symputx("_ndj_nvars", ordinal_columns, "L");
	    call symputx("_ndj_rename_list", _ndj_rename_list, "L");
	  end;

	run;

  /* Number of labels, formats */
  proc sql noprint;
    select count(*) into :_ndj_nlabels trimmed
    from work.___ndj_columns
    where not missing(label);

    select count(*) into :_ndj_nformats trimmed
    from work.___ndj_columns
    where not missing(displayFormat);
  quit;

  /* Remove a stale in-progress dataset from a prior call with the same suffix. */
  proc datasets library=&outlib nolist;
    delete &_ndj_tmpds;
  quit;

  /* Process data lines in bounded chunks. */
  %do _ndj_chunk=1 %to &_ndj_nchunks;
    %let _ndj_firstobs=%eval(2 + (&_ndj_chunk - 1) * &chunksize);
    %let _ndj_obs=%sysfunc(min(%eval(&_ndj_firstobs + &chunksize - 1), %eval(&_ndj_nlines + 1)));

    filename _ndjjson temp lrecl=32767;

    /*
       Construct one valid Dataset-JSON document for this chunk.
	   NDJSON -> JSON (meta + chunk)
    */
    data _null_;
      length _ndj_line $32767;
      file _ndjjson lrecl=32767;

      /* Metadata line: replace the final columns closure with ROWS opening. */
      infile _ndjin obs=1 truncover;
      input;
      _ndj_line=tranwrd(_infile_, '}]}', '}],"rows":[');
      put _ndj_line @;

      /* Reopen input for only the current data-line range. */
      do _ndj_line_no=&_ndj_firstobs to &_ndj_obs;
        infile _ndjdat firstobs=&_ndj_firstobs obs=&_ndj_obs
               truncover end=_ndj_chunk_eof;
        input;
        _ndj_line=_infile_;
        if not _ndj_chunk_eof then _ndj_line=tranwrd(_ndj_line,']','],');
        else _ndj_line=tranwrd(_ndj_line,']',']]}');
        put _ndj_line @;
      end;
      stop;
    run;

    libname _ndjc json fileref=_ndjjson; /* read JSON */

    data work.___ndj_chunk;
	  /* variables length */
      %do _ndj_i=1 %to &_ndj_nvars;
        &&_ndj_length&_ndj_i
      %end;

      set _ndjc.rows
        %if %length(%superq(_ndj_rename_list)) %then %do;
          (rename=(&_ndj_rename_list))
        %end;
      ;

	  /* convert variables */
      %do _ndj_i=1 %to &_ndj_nvars;
        &&_ndj_convert&_ndj_i
      %end;

	  /* where */
	  %if %length(%superq(where)) %then %do;
        if not (%unquote(&where)) then delete;
      %end;

      /* Keep only the requested output variables after evaluating WHERE. */
      %if %length(%superq(keep)) %then %do;
        keep %unquote(&keep);
      %end;

      drop ordinal_root ordinal_rows;
    run;

    %let _ndj_keep_rc=&syserr;
    %if %sysevalf(&_ndj_keep_rc > 4) %then %do;
      %put ERROR: [NDJSON STREAM] KEEP contains an invalid variable list: %superq(keep).;
      %let _ndj_abort=1;
      %goto ndj_cleanup;
    %end;

    libname _ndjc clear;
    filename _ndjjson clear;

	/* append chunk data */
    %if &_ndj_chunk=1 %then %do;
      data &outlib..&_ndj_tmpds;
        set work.___ndj_chunk;
      run;
    %end;
    %else %do;
      proc append base=&outlib..&_ndj_tmpds
                  data=work.___ndj_chunk;
      run;
    %end;

    proc datasets library=work nolist;
      delete ___ndj_chunk;
    quit;

  %end;

  /* Keep metadata only for variables that are present in the output. */
  proc sql;
    create table work.___ndj_kept_columns as
    select c.*
    from work.___ndj_columns as c
    inner join dictionary.columns as d
      on upcase(c.name)=upcase(d.name)
     and d.libname=upcase("&outlib")
     and d.memname=upcase("&_ndj_tmpds")
    order by c.ordinal_columns;
  quit;

  /* Apply the dataset label. */
  proc datasets library=&outlib nolist;
    modify &_ndj_tmpds
	  %if %length(%superq(_ndj_label_stmt)) %then %do;  (label="&_ndj_label_stmt") %end;
	  ;
  quit;

  /* Apply labels and formats only to retained variables. */
  data _null_;
    set work.___ndj_kept_columns end=_ndj_eof;

    if _n_=1 then do;
      call execute("proc datasets library=&outlib nolist;");
      call execute("modify &_ndj_tmpds;");
    end;

    if not missing(label) then
      call execute(catx(
        " ",
        "label",
        cats(
          nliteral(strip(name)), "='",
          tranwrd(strip(label), "'", "''"), "';"
        )
      ));

    if not missing(displayFormat) then do;
      if index(displayFormat, ".")=0 then
        displayFormat=cats(displayFormat, ".");
      call execute(catx(
        " ",
        "format",
        nliteral(strip(name)),
        cats(strip(displayFormat), ";")
      ));
    end;

    if _ndj_eof then call execute("quit;");
  run;

  /* Dataset-level extended attributes. */
	data _null_;

	  set work.___ndj_root(obs=1);

	  call execute("proc datasets library=&outlib nolist;");
	  call execute("modify &_ndj_tmpds;");
	  call execute("xattr add ds");

	  if not missing(datasetJSONCreationDateTime) then
	    call execute(cats(
	      "datasetJSONCreationDateTime='",
	      tranwrd(strip(datasetJSONCreationDateTime), "'", "''"),
	      "'"
	    ));
	  if not missing(datasetJSONVersion) then
	    call execute(cats(
	      "datasetJSONVersion='",
	      tranwrd(strip(datasetJSONVersion), "'", "''"),
	      "'"
	    ));
	  if not missing(fileOID) then
	    call execute(cats(
	      "fileOID='",
	      tranwrd(strip(fileOID), "'", "''"),
	      "'"
	    ));
	  if not missing(dbLastModifiedDateTime) then
	    call execute(cats(
	      "dbLastModifiedDateTime='",
	      tranwrd(strip(dbLastModifiedDateTime), "'", "''"),
	      "'"
	    ));
	  if not missing(originator) then
	    call execute(cats(
	      "originator='",
	      tranwrd(strip(originator), "'", "''"),
	      "'"
	    ));
	  if not missing(studyOID) then
	    call execute(cats(
	      "studyOID='",
	      tranwrd(strip(studyOID), "'", "''"),
	      "'"
	    ));
	  if not missing(metaDataVersionOID) then
	    call execute(cats(
	      "metaDataVersionOID='",
	      tranwrd(strip(metaDataVersionOID), "'", "''"),
	      "'"
	    ));
	  if not missing(metaDataRef) then
	    call execute(cats(
	      "metaDataRef='",
	      tranwrd(strip(metaDataRef), "'", "''"),
	      "'"
	    ));
	  if not missing(itemGroupOID) then
	    call execute(cats(
	      "itemGroupOID='",
	      tranwrd(strip(itemGroupOID), "'", "''"),
	      "'"
	    ));
	  if not missing(records) then
	    call execute(cats(
	      "records=",
	      strip(put(records, best32.))
	    ));

	  call execute("; quit;");
	run;

  /* Variable-level extended attributes. */
  data _null_;
    length _ndj_value $500;
    set work.___ndj_kept_columns end=_ndj_eof;
    if _n_=1 then do;
      call execute('proc datasets library=&outlib nolist;');
      call execute('modify &_ndj_tmpds;');
      call execute('xattr add var');
    end;
    call execute(cats(nliteral(trim(name)), '('));
    if not missing(dataType) then
      call execute(cats("dataType='",tranwrd(trim(dataType),"'","''"),"'"));
    if not missing(targetDataType) then
      call execute(cats("targetDataType='",tranwrd(trim(targetDataType),"'","''"),"'"));
    if not missing(displayFormat) then
      call execute(cats("displayFormat='",tranwrd(trim(displayFormat),"'","''"),"'"));
    if not missing(length) then
      call execute(cats("length='",strip(put(length,best.)),"'"));
    if not missing(keySequence) then
      call execute(cats('keySequence=',strip(put(keySequence,best.))));
    call execute(')');
    if _ndj_eof then call execute('; quit;');
  run;

  /* Validate the final number of observations. */
  proc sql noprint;
    select count(*) into :_ndj_actual trimmed
    from &outlib..&_ndj_tmpds;
  quit;

  %if %length(%superq(where))=0 and
      %length(%superq(obs))=0 and
      %sysevalf(%superq(_ndj_expected) ne .,boolean) %then %do;
    %if %sysevalf(&_ndj_actual ne &_ndj_expected) %then
      %put WARNING: [NDJSON STREAM] Metadata RECORDS=&_ndj_expected but &_ndj_actual observations were imported.;
  %end;

  /* Publish the completed dataset only after every chunk succeeds. */
	%if %sysfunc(exist(&outlib..&ds)) %then %do;
	  proc datasets library=&outlib nolist;
	    delete &ds;
	  quit;
	%end;

	proc datasets library=&outlib nolist;
	  change &_ndj_tmpds=&ds;
	quit;

%ndj_cleanup:
  filename _ndjin clear;
  filename _ndjdat clear;
  /* Clear only references that are still assigned. */
  %if %sysfunc(fileref(_ndjmeta)) = 0 %then %do;
    filename _ndjmeta clear;
  %end;
  %if %sysfunc(fileref(_ndjjson)) = 0 %then %do;
    filename _ndjjson clear;
  %end;
  %if %sysfunc(libref(_ndjm)) = 0 %then %do;
    libname _ndjm clear;
  %end;
  %if %sysfunc(libref(_ndjc)) = 0 %then %do;
    libname _ndjc clear;
  %end;

  proc datasets library=work nolist;
    delete ___ndj_root ___ndj_columns ___ndj_dummy_root
           ___ndj_dummy_columns ___ndj_chunk ___ndj_kept_columns;
  quit;

  %if &_ndj_abort %then %do;
    proc datasets library=&outlib nolist;
      delete &_ndj_tmpds;
    quit;
  %end;

%ndj_exit:

%mend m_ndjson1_1_to_sas_stream;
