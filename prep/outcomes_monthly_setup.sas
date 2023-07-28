/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Covid, telehealth, acute inpatient, ER, office;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

libname temp1 "&rootpath./Projects/Data/Tempwork1";
%let tempwork1=temp1;

options obs=max;

/* COVID dx */
data &tempwork..coviddx_use;
	set &tempwork..coviddx_2017_2020;

	array icd [*] icd_dgns_cd:;

	u071=0;
	u072=0;
	b9729=0;
	b342=0;

	do i=1 to dim(icd);
		if icd[i]="U071" then u071=1;
		if icd[i]="U072" then u072=1;
		if icd[i]="B9729" then b9729=1;
		if icd[i]="B342" then b342=1;
	end;

	month=month(clm_thru_dt);
	year=year(clm_thru_dt);

	any_coviddx=max(u071,u072,b9729);

run;

proc means data=&tempwork..coviddx_use noprint nway;
	class bene_id year month;
	var u071 u072 b9729 b342 any_coviddx;
	output out=covid.covid_benemonth (drop=_type_ _freq_) max()= sum()= / autoname;
run;

/* Telehealth Dx */
data &tempwork..tele_exp;
	set &tempwork..telehealthprcdr_2017_2020;

	month=month(prcdr_dt);
	year=year(prcdr_dt);

	* combining evisit and virtual_checkin;
	new_tele=max(evisit,virtual_checkin);

run;

proc means data=&tempwork..tele_exp noprint nway;
	class bene_id year month;
	var new_tele evisit virtual_checkin telehealth_temp telehealth_temp_add430 telehealth_temp_add1014 
		telehealth_phe telehealth_inperson telehealth_only;
	output out=covid.telehealth_benemonth (drop=_type_ _freq_) max()= sum()= /autoname;
run;

/* Acute Inpatient */
data &tempwork..acute_ip;
	set &tempwork1..acute_ip_2017_2020;

	month=month(clm_thru_dt);
	year=year(clm_thru_dt);

run;

proc means data=&tempwork..acute_ip noprint nway;
	class bene_id year month;
	var acute_ip;
	output out=covid.acuteip_benemonth (drop=_type_ _freq_) max()= sum()= /autoname;
run;

/* Physician Events */
data &tempwork..phys;
	set covid.phys_events_2017_2020;

	month=month(clm_thru_dt);
	year=year(clm_thru_dt);

run;

proc means data=&tempwork..phys noprint nway;
	class bene_id year month;
	var phys_visit;
	output out=covid.phys_benemonth (drop=_type_ _freq_) max()= sum()= /autoname;
run;

/* ER */
data &tempwork..er;
	set &tempwork1..er_visits_2017_2020;

	month=month(clm_thru_dt);
	year=year(clm_thru_dt);

run;

proc means data=&tempwork..er noprint nway;
	class bene_id year month;
	var er;
	output out=covid.er_benemonth (drop=_type_ _freq_) max()= sum()= /autoname;
run;





