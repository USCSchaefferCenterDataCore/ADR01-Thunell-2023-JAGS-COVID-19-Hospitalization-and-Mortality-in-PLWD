/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Response to R&R - getting table of description of covariates for people with COVID 
	and dementia, by race;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

proc means data=covid.rr_covidmodelprepany_2020 noprint nway;
	where covidany=1 and plwd=1;
	class race_bg;
	var female age_lt75 age_7584 age_ge85 dual lis cc_: cci pcths_q1-pcths_q4 medinc_q1-medinc_q4;
	output out=&tempwork..covariates_2020 sum()= mean()= std(cci)= / autoname;
run;

proc means data=covid.rr_covidmodelprepany_2021 noprint nway;
	where covidany=1 and plwd=1;
	class race_bg;
	var female age_lt75 age_7584 age_ge85 dual lis cc_: cci pcths_q1-pcths_q4 medinc_q1-medinc_q4;
	output out=&tempwork..covariates_2021 sum()= mean()= std(cci)= / autoname;
run;

proc export data=&tempwork..covariates_2020
	outfile="&rootpath./Projects/Programs/covid/exports/rr_covariate_table.xlsx"
	dbms=xlsx
	replace;
	sheet="2020";
run;

proc export data=&tempwork..covariates_2021
	outfile="&rootpath./Projects/Programs/covid/exports/rr_covariate_table.xlsx"
	dbms=xlsx
	replace;
	sheet="2021";
run;

* original sample;
proc means data=covid.covidmodelprepany noprint nway;
	where covidany=1 and plwd=1;
	class race_bg;
	var female age_lt75 age_7584 age_ge85 dual lis cc_: cci pcths_q1-pcths_q4 medinc_q1-medinc_q4;
	output out=&tempwork..covariates_2020og sum()= mean()= std(cci)= / autoname;
run;

proc export data=&tempwork..covariates_2020og
	outfile="&rootpath./Projects/Programs/covid/exports/rr_covariate_table.xlsx"
	dbms=xlsx
	replace;
	sheet="2020og";
run;

