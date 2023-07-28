/*********************************************************************************************/
title1 'MA FFS Pilot';

* Author: PF;
* Purpose: Get all dx codes for diabetes, hypertension, hyperlipidemia, ATF, AMI, stroke;
* Input: CC_codes.csv; 
* Output: macro for arthritis codes and gluacoma codes;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

data cc_codes_all;
	infile "&rootpath./Projects/Programs/chronic_conditions_package/csv_input/CC_Codes.csv" dlm="2c"x dsd lrecl=32767 missover firstobs=2;
	informat
		Condition  $10.
		CodeType	$10.
		DxCodeLocation $8.
		DxCode $10.;
	format
		Condition $10.
		CodeType	$10.
		DxCodeLocation	$8.
		DxCode $10.;
	input
		Condition $
		CodeType $
		DxCodeLocation $
		DxCode $;
run;

data cc_excl;
	infile "&rootpath./Projects/Programs/chronic_conditions_package/csv_input/CC_Exclude.csv" dlm="2c"x dsd lrecl=32767 missover firstobs=2;
	informat
		Condition  $10.
		CodeType	$10.
		DxCodeLocation $8.
		DxCode $10.;
	format
		Condition $10.
		CodeType	$10.
		DxCodeLocation	$8.
		DxCode $10.;
	input
		Condition $
		CodeType $
		DxCodeLocation $
		DxCode $;
run;

data cc_edits;
	infile "&rootpath./Projects/Programs/MAFFSpilot/cc_edits.csv" dlm="2c"x dsd lrecl=32767 missover firstobs=2;
	informat
		Condition  $15.
		DxCode $10.;
	format
		Condition $15.
		DxCode $10.;
	input
		Condition $
		DxCode $;
run;

data cc_codes_cmd;
	set cc_codes_all;
	if condition in('DIABETES','STRKETIA','AMI','ATRIALF','HYPERL','HYPERT');
run;

proc sort data=cc_edits; by condition dxcode; run;

data cc_codes_add cc_excl_add cc_excl_drop;
	set cc_edits;
	by condition dxcode;
	if condition='DROPFROMSTRK' then do;
		condition='STRKETIA';
		output cc_excl_drop;
	end;
	if condition='STRKETIAEXCL' then do;
		condition='STRKETIA';
		output cc_excl_add;
	end;
	if condition in('AMI','ATRIALF','HYPERL','DIABETES') then output cc_codes_add;
run;

proc sort data=cc_excl (where=(condition='STRKETIA')) out=cc_excl1; by condition dxcode; run;

data cc_excl1;
	merge cc_excl1 (in=a) cc_excl_add (in=b) cc_excl_drop (in=c);
	by condition dxcode;
	drop=c;
	new=b;
run;

proc sort data=cc_codes_cmd; by condition dxcode; run;

data cc_codes_cmd1;
	set cc_codes_cmd cc_codes_add (in=b);
	by condition dxcode;
	new=b;
run;

		data cc_codes_cmd2;
			set cc_codes_cmd1;
			by condition;
			format dxcode2 $8. allcodes $12000.;
			if first.condition then allcodes="";
			retain allcodes;
			period=index(trim(left(dxcode)),".");
			dxcode2=upcase(trim(left(compress(dxcode,"."))));
			* Adjusting to compensate for any incorrectly formatted numeric codes due to CSV format;
			if length(trim(left(dxcode2)))=4 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=2 then dxcode2="0"||trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=0 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=2 & CodeType="ICD9DX" & period=0 then dxcode2="0"||trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=2 then  dxcode2="0"||trim(left(dxcode2));
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=3 then dxcode2=trim(left(dxcode2))||"0";
			if codetype="HCPCS" and dxcode ne "" then do;
				if length(dxcode2)=1 then dxcode2="0000"||dxcode2;
				if length(dxcode2)=2 then dxcode2="000"||dxcode2;
				if length(dxcode2)=3 then dxcode2="00"||dxcode2;
				if length(dxcode2)=4 then dxcode2="0"||dxcode2;
			end;
			* Creating a concatenated list of all codes by condition and code type;
			allcodes=catx('","',allcodes,dxcode2);
			if last.condition;

			if condition="DIABETES" then call symput('diabetes',compress(allcodes));
			if condition='HYPERL' then call symput('hyperl',compress(allcodes));
			if condition="HYPERT" then call symput('hypert',compress(allcodes));
			if condition='STRKETIA' then call symput('strketia',compress(allcodes));
			if condition="AMI" then call symput('ami',compress(allcodes));
			if condition='ATRIALF' then call symput('atf',compress(allcodes));
		run;

	data cc_excl2;
			set cc_excl1 (where=(drop ne 1));
			by condition;
			format dxcode2 $8. allcodes $12000.;
			if first.condition then allcodes="";
			retain allcodes;
			period=index(trim(left(dxcode)),".");
			dxcode2=upcase(trim(left(compress(dxcode,"."))));
			* Adjusting to compensate for any incorrectly formatted numeric codes due to CSV format;
			if length(trim(left(dxcode2)))=4 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=4 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=2 then dxcode2="0"||trim(left(dxcode2))||"0";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9DX" & period=0 then dxcode2=trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=2 & CodeType="ICD9DX" & period=0 then dxcode2="0"||trim(left(dxcode2))||"00";
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=2 then  dxcode2="0"||trim(left(dxcode2));
			if length(trim(left(dxcode2)))=3 & CodeType="ICD9PRCDR" & period=3 then dxcode2=trim(left(dxcode2))||"0";
			if codetype="HCPCS" and dxcode ne "" then do;
				if length(dxcode2)=1 then dxcode2="0000"||dxcode2;
				if length(dxcode2)=2 then dxcode2="000"||dxcode2;
				if length(dxcode2)=3 then dxcode2="00"||dxcode2;
				if length(dxcode2)=4 then dxcode2="0"||dxcode2;
			end;
			* Creating a concatenated list of all codes by condition and code type;
			allcodes=catx('","',allcodes,dxcode2);
			if last.condition;

			if condition='STRKETIA' then call symput('strketiaexcl',compress(allcodes));

		run;

%let diabetes="&diabetes";
%let hyperl="&hyperl";
%let hypert="&hypert";
%let ami="&ami";
%let atf="&atf";
%let strketia="&strketia";
%let strketiaexcl="&strketiaexcl.";
