/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Sample characteristics for COVID outcomes sample;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

/* Adding death and hospitalization */
* Get any beneficiary that had an inpatient claim between March and September of 2020;
options obs=max;
%macro ip;
proc sql;
	%do mo=3 %to 9;
	create table &tempwork..ip&mo. as
	select distinct bene_id
	from rifq2020.inpatient_claims_0&mo. 
	order by bene_id;
	%end;
quit;
%mend;

%ip;

data &tempwork..beneip;
	merge &tempwork..ip3-&tempwork..ip9;
	by bene_id;
run;

proc sort data=&tempwork..covidmodel_urbanrural3; by bene_id; run;

data &tempwork..covidmodel_urbanrural4;
	merge &tempwork..covidmodel_urbanrural3 (in=a) &tempwork..beneip (in=b);
	by bene_id;

	if a;

	* inpatient;
	allip=b;

	* death;
	alldeath=0;
	if .<death_date<=mdy(9,30,2020) then alldeath=1;

	* death conditional on inpatient;
	allipdeath=0;
	if allip and alldeath then allipdeath=1;

run;

* Check that no death occurs before March;
data &tempwork..covidmodel_urbanrural4_ck;
	set &tempwork..covidmodel_urbanrural4;
	if .<death_date<mdy(3,1,2020);
run;

* COVID any;
proc means data=&tempwork..covidmodel_urbanrural4 noprint;
	class covidany plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
	output out=covid_models_sampany sum()= mean()= / autoname;
run;

proc export data=covid_models_sampany
	outfile="&rootpath./Projects/Programs/covid/exports/covid_models_samp_any.xlsx"
	dbms=xlsx
	replace;
	sheet="samp";
run;

* T-test differences;
proc ttest data=&tempwork..covidmodel_urbanrural4;
	where covidany;
	class plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
run;

* COVID any - dual/lis;
proc means data=&tempwork..covidmodel_urbanrural4 noprint;
	where max(dual,lis)=1;
	class covidany plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
	output out=covid_models_sampdlany sum()= mean()= / autoname;
run;

proc export data=covid_models_sampdlany
	outfile="&rootpath./Projects/Programs/covid/exports/covid_models_samp_any.xlsx"
	dbms=xlsx
	replace;
	sheet="sampdl
";
run;

proc means data=&tempwork..covidmodel_urbanrural4 noprint;
	where coviddeath_noip and max(dual,lis)=1;
	class plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
	output out=covid_models_deathnoipdl sum()= mean()= / autoname;
run;

proc export data=covid_models_deathnoipdl
	outfile="&rootpath./Projects/Programs/covid/exports/covid_models_samp_any.xlsx"
	dbms=xlsx
	replace;
	sheet="sampdeathnoipdl";
run;

proc means data=&tempwork..covidmodel_urbanrural4 noprint;
	where covidip_any and max(dual,lis)=1;
	class plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
	output out=covid_models_ipanydl sum()= mean()= / autoname;
run;

proc export data=covid_models_ipanydl
	outfile="&rootpath./Projects/Programs/covid/exports/covid_models_samp_any.xlsx"
	dbms=xlsx
	replace;
	sheet="sampipanydl";
run;

* COVID Death;
proc means data=&tempwork..covidmodel_urbanrural4 noprint;
	where coviddeath_noip;
	class plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
	output out=covid_models_deathnoip sum()= mean()= / autoname;
run;

proc export data=covid_models_deathnoip
	outfile="&rootpath./Projects/Programs/covid/exports/covid_models_samp_any.xlsx"
	dbms=xlsx
	replace;
	sheet="sampdeathnoip";
run;

* COVID IP;
proc means data=&tempwork..covidmodel_urbanrural4 noprint;
	where covidip_any;
	class plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
	output out=covid_models_ipany sum()= mean()= / autoname;
run;

proc export data=covid_models_ipany
	outfile="&rootpath./Projects/Programs/covid/exports/covid_models_samp_any.xlsx"
	dbms=xlsx
	replace;
	sheet="sampipany";
run;
