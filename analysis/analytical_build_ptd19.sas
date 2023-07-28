/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Build COVID analytical weekly dataset
	Sample:  
	•	Enrolled in FFS Parts A & B, non-LTC facilities (community-dwelling)
	•	Prevalent ADRD dx defined (dx, symptoms, verified)- keep non-PLWD for later comparison, but current analysis is on PLWD
	•	Months/years: March -September 2017-2019, 2020 
	•	COVID data: Johns Hopkins data merged on bene county

	Key Variables:
	•	ADRD (verified, as defined above) verified and unverified
	•	Outcomes: monthly doc visits  (number and likelihood)- monthly telehealth visits (number and likelihood)- [later step] incident ADRD dx 
	•	Predictors: COVID infection and death rates - weekly (7-day) average by county  
	•	Race/ethnicity- sex (one-time)
	•	Health: CCI, comorbidities (prevalent, annual)
	•	Economic: LIS, dual (annual)
	•	Zip code vars: % HS- med income (annual)
;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

* FFS Part D Sample - in sample for one year - allowing for death in that year;
data &tempwork..base_samp (drop=yr--plwd) &tempwork..base_monthly (keep=bene_id race_bg sex age_group age_beg death_date birth_date plwd year month date);
	merge base.samp_3yrffsptd_0621 (in=a keep=bene_id insamp2017-insamp2020 race_bg sex birth_date death_date 
		  age_group2017-age_group2020 age_beg2017-age_beg2020)
		  ad.adrdincv_1999_2021 (in=b keep=bene_id scen_dx_inc scen_dxsymp_inc dropdx dropdxsymp)
		  base.ltc2015_bene (in=c)
		  base.ltc2016_bene (in=d)
		  base.ltc2017_bene (in=e)
		  base.ltc2018_bene (in=f)
 		  base.ltc2019_bene (in=g)
 		  base.ltc2020_bene (in=h);
	by bene_id;

	array insamp [2017:2020] insamp2017-insamp2020;
	array ltc [2017:2020] ltc2017-ltc2020;
	array ptd [2015:2020] ptd2015-ptd2020;
	array pos [2015:2020] pos2015-pos2020;
	array prcdr [2015:2020] prcdr2015-prcdr2020;
	array plwd_ [2017:2020] plwd2017-plwd2020;

	* community-dwelling is based on LTC part d from 1 years ago, pos and procedure codes from current yera;
	do yr=2017 to 2020;
		ltc[yr]=0;
		ltc[yr]=max(0,ptd[yr-1],pos[yr],prcdr[yr]);
	end;

	* first identify those enrolled in FFS and Part D in whole year and community-dwelling;
	* second separating sample into PLWD and non-PLWD;
	do yr=2017 to 2020;
		if insamp[yr] and ltc[yr]=0 then do;
			plwd_[yr]=0;
			if .<year(scen_dxsymp_inc)<yr and dropdxsymp ne 1 then plwd_[yr]=1;
		end;
	end;

	output &tempwork..base_samp;

	format date mmddyy10.;
	
	* create a monthly file for base;
	array age_group_ [2017:2020] age_group2017-age_group2020;
	array age_beg_ [2017:2020] age_beg2017-age_beg2020;
	do yr=2017 to 2020;
		if plwd_[yr] ne . then do mo=3 to 9; * March to September;
			age_group=age_group_[yr];
			age_beg=age_beg_[yr];
			year=yr;
			month=mo;
			date=mdy(month,1,year);
			plwd=plwd_[yr];
			output &tempwork..base_monthly;
		end;
	end;

run;

* Merge to outcomes	- Get % of all and count
	- Telehealth
	- COVID by dementia
	- acute inpatient
	- office
	- emergency room;

proc sort data=&tempwork..base_monthly; by bene_id year month; run;

data &tempwork..base_monthly1;
	merge &tempwork..base_monthly (in=a)
		  covid.covid_benemonth (in=b)
		  covid.telehealth_benemonth (in=c keep=bene_id year month new_tele_max new_tele_sum)
		  covid.acuteip_benemonth (in=d)
		  covid.er_benemonth (in=e)
		  covid.phys_benemonth (in=f)
		  covid.telemod_benemonth (in=g);
	by bene_id year month;

	if a;

	* creating a new measure where telehealth is the new telehealth codes and presence of any modifier;
	telehealth_max=max(new_tele_max, hcpcs_mdfr95_max, hcpcs_mdfrGT_max, pos02_max);
	telehealth_sum=sum(new_tele_sum, hcpcs_mdfr95_sum, hcpcs_mdfrGT_sum, pos02_sum);

	array out_max [*] u071_max u072_max b9729_max any_coviddx_max telehealth_max acute_ip_max phys_visit_max er_max ;
	array out_sum [*] u071_sum u072_sum b9729_sum any_coviddx_sum telehealth_sum acute_ip_sum phys_visit_sum er_sum ;

	do i=1 to dim(out_max);
		out_max[i]=max(0,out_max[i]);
		out_sum[i]=max(0,out_sum[i]);
	end;
run;

* Outcomes limited to PLWD;
proc means data=&tempwork..base_monthly1 noprint;
	class plwd year month;
	var u071_max u072_max b9729_max any_coviddx_max telehealth_max acute_ip_max phys_visit_max er_max 
		u071_sum u072_sum b9729_sum any_coviddx_sum telehealth_sum acute_ip_sum phys_visit_sum er_sum ;
	output out=&tempwork..monthly_outcomes mean(u071_max u072_max b9729_max any_coviddx_max telehealth_max acute_ip_max phys_visit_max er_max )=
	sum(u071_sum u072_sum b9729_sum any_coviddx_sum telehealth_sum acute_ip_sum phys_visit_sum er_sum )=;
run;

* Covid by race and sex and age;
proc means data=&tempwork..base_monthly1 noprint;
	class plwd race_bg year month;
	var any_coviddx_max any_coviddx_sum;
	output out=&tempwork..covid_outcomes_byrace mean(any_coviddx_max)= sum(any_coviddx_sum)=;
run;

* Annual covid;
proc means data=&tempwork..base_monthly1 noprint nway;
	class plwd race_bg bene_id year;
	var any_coviddx_max;
	output out=&tempwork..covid_beneyr max()=;
run;

proc means data=&tempwork..covid_beneyr noprint;
	 class plwd race_bg year;
	 var any_coviddx_max;
	 output out=&tempwork..covid_outcomes_byrace_annual mean()=;
run;

proc export data=&tempwork..covid_outcomes_byrace_annual
	outfile="&rootpath./Projects/Programs/covid/exports/covid_outcomes_byrace_ptd19.xlsx"
	dbms=xlsx
	replace;
	sheet='covid_byrace_annual';
run;

proc export data=&tempwork..covid_outcomes_byrace
	outfile="&rootpath./Projects/Programs/covid/exports/covid_outcomes_byrace_ptd19.xlsx"
	dbms=xlsx
	replace;
	sheet='covid_byrace';
run;

* Outcomes limited to PLWD and removing months with covid;
proc means data=&tempwork..base_monthly1 noprint;
	where any_coviddx_max=0;
	class plwd year month;
	var u071_max u072_max b9729_max any_coviddx_max telehealth_max acute_ip_max phys_visit_max er_max 
		u071_sum u072_sum b9729_sum any_coviddx_sum telehealth_sum acute_ip_sum phys_visit_sum er_sum ;
	output out=&tempwork..monthly_outcomes_nocovid mean(u071_max u072_max b9729_max any_coviddx_max telehealth_max acute_ip_max phys_visit_max er_max )=
	sum(u071_sum u072_sum b9729_sum any_coviddx_sum telehealth_sum acute_ip_sum phys_visit_sum er_sum )=;
run;

proc export data=&tempwork..monthly_outcomes
	outfile="&rootpath./Projects/Programs/covid/exports/outcomes_monthly_ptd19.xlsx"
	dbms=xlsx
	replace;
	sheet="covid";
run;

proc export data=&tempwork..monthly_outcomes_nocovid
	outfile="&rootpath./Projects/Programs/covid/exports/outcomes_monthly_ptd19.xlsx"
	dbms=xlsx
	replace;
	sheet="nocovid";
run;

/* Merge other cample information - dual, CCI and comorbidities */

* creating yearly dual and LIS indicator;
data &tempwork..covid_duallis;
	set sh054066.bene_status_year2017 (in=a keep=bene_id anydual anylis dual_allyr dual_cstshr_allyr lis_allyr)
		sh054066.bene_status_year2018 (in=b keep=bene_id anydual anylis dual_allyr dual_cstshr_allyr lis_allyr)
		sh054066.bene_status_year2019 (in=c keep=bene_id anydual anylis dual_allyr dual_cstshr_allyr lis_allyr)
		sh054066.bene_status_year2020 (in=d keep=bene_id anydual anylis dual_allyr dual_cstshr_allyr lis_allyr);
	by bene_id;
	if a then year=2017;
	if b then year=2018;
	if c then year=2019;
	if d then year=2020;
	dual=(anydual="Y");
	lis=(anylis="Y");
run;

proc sort data=&tempwork..covid_duallis; by bene_id year; run;

* creating yearly chronic conditions - AMI, diabetes, stroke, hypertension ,hyperlipidemia, ATF;
data &tempwork..covid_ccw;
	set mbsf.mbsf_cc_2017 (in=a keep=bene_id ami atrial_fib diabetes hyperl hypert stroke_tia)
		mbsf.mbsf_cc_2018 (in=b keep=bene_id ami atrial_fib diabetes hyperl hypert stroke_tia)
		mbsf.mbsf_cc_2019 (in=c keep=bene_id ami atrial_fib diabetes hyperl hypert stroke_tia)
		mbsf.mbsf_cc_2020 (in=d keep=bene_id ami atrial_fib diabetes hyperl hypert stroke_tia);
	by bene_id;
	if a then year=2017;
	if b then year=2018;
	if c then year=2019;
	if d then year=2020;
	cc_ami=0;
	cc_atf=0;
	cc_diab=0;
	cc_hyperl=0;
	cc_hypert=0;
	cc_stroke=0;
	if ami in(1,3) then cc_ami=1;
	if atrial_fib in(1,3) then cc_atf=1;
	if diabetes in (1,3) then cc_diab=1;
	if hyperl in(1,3) then cc_hyperl=1;
	if hypert in(1,3) then cc_hypert=1;
	if stroke_tia in(1,3) then cc_stroke=1;
run;

proc sort data=&tempwork..covid_ccw; by bene_id year; run;

data &tempwork..covid_cci;
	set base.cci_ffsptd_bene0720_marsep (in=a keep=bene_id wgtcc2017 rename=(wgtcc2017=wgtcc))
		base.cci_ffsptd_bene0720_marsep (in=b keep=bene_id wgtcc2018 rename=(wgtcc2018=wgtcc))
		base.cci_ffsptd_bene0720_marsep (in=c keep=bene_id wgtcc2019 rename=(wgtcc2019=wgtcc))
		base.cci_ffsptd_bene0720_marsep (in=d keep=bene_id wgtcc2020 rename=(wgtcc2020=wgtcc));
	by bene_id;
	if a then year=2017;
	if b then year=2018;
	if c then year=2019;
	if d then year=2020;
run;

proc sort data=&tempwork..covid_cci; by bene_id year; run;

data covid.samp_monthly_wcovid;
	merge &tempwork..base_monthly1 (in=a)
		  &tempwork..covid_duallis (in=b keep=bene_id dual lis year)
		  &tempwork..covid_ccw (in=c keep=bene_id year cc_:)
		  &tempwork..covid_cci (in=d keep=bene_id year wgtcc);
	by bene_id year;

	if a;
	ses=b;
	ccw=c;
	cci=d;

	if dual=. then dual=0;
	if lis=. then lis=0;

	array cc [*] cc_:;
	do i=1 to dim(cc);
		if cc[i]=. then cc[i]=0;
	end;

	* female;
	female=(sex='2');

	* race;
	race_dw=(race_bg='1');
	race_db=(race_bg='2');
	race_dh=(race_bg='5');
	race_da=(race_bg='4');
	race_dn=(race_bg='6');
	race_do=(race_bg in('','3'));

	* age;
	age_lt75=(find(age_group,'1.'));
	age_7584=(find(age_group,'2.'));
	age_ge85=(find(age_group,'3.'));

	* cci;
	if wgtcc=. then wgtcc=0;

	*last month;
	lastmonth=(last.year);

run;

proc freq data=covid.samp_monthly_wcovid noprint;
	where any_coviddx_Max=0;
	table ses*ccw*cci / out=&tempwork..mergeck;
run;

proc means data=covid.samp_monthly_wcovid noprint nway;
	where any_coviddx_Max=0;
	class year;
	var female race_d: age_beg age_lt75 age_7584 age_ge85 dual lis cc: wgtcc;
	output out=&tempwork..monthly_samp_char mean()= sum()= std(age_beg wgtcc)= / autoname;
run;

proc means data=covid.samp_monthly_wcovid noprint nway;
	where lastmonth=1 and any_coviddx_max=0;
	class year;
	var female race_d: age_beg age_lt75 age_7584 age_ge85 dual lis cc: wgtcc;
	output out=&tempwork..bene_samp_char mean()= sum()= std(age_beg wgtcc)= / autoname;
run;

proc means data=covid.samp_monthly_wcovid noprint nway;
	where plwd=1 and any_coviddx_max=0;
	class year;
	var female race_d: age_beg age_lt75 age_7584 age_ge85 dual lis cc: wgtcc;
	output out=&tempwork..monthly_samp_char_plwd mean()= sum()= std(age_beg wgtcc)= / autoname;
run;

proc means data=covid.samp_monthly_wcovid noprint nway;
	where lastmonth=1 and plwd=1 and any_coviddx_max=0;
	class year;
	var female race_d: age_beg age_lt75 age_7584 age_ge85 dual lis cc: wgtcc;
	output out=&tempwork..bene_samp_char_plwd mean()= sum()= std(age_beg wgtcc)= / autoname;
run;

proc export data=&tempwork..monthly_samp_char_plwd
	outfile="&rootpath./Projects/Programs/covid/exports/sample_char_ptd19.xlsx"
	dbms=xlsx
	replace;
	sheet="stats_benemonth_plwd";
run;

proc export data=&tempwork..bene_samp_char_plwd
	outfile="&rootpath./Projects/Programs/covid/exports/sample_char_ptd19.xlsx"
	dbms=xlsx
	replace;
	sheet="stats_bene_plwd";
run;
