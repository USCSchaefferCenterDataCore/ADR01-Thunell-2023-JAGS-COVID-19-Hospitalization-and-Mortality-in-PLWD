/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: COVID annual dataset
	Sample:  
	•	Enrolled in FFS Parts A & B, non-LTC facilities (community-dwelling)
	•	Months/year s: March -September 2017-2019, 2020 

	Key Variables:
	•  Two outcomes - COVID and inpatient COVID
	DV
		ADRD verified with dx, symptoms
	•	Race/ethnicity- sex (one-time)
	•	Health: comorbidities (prevalent, annual)
	•	Economic: LIS, dual (annual)
	•	Zip code vars: % HS- med income (annual)
;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max; 

* Getting our monthly sample on the annual level;
proc means data=covid.samp_monthly_wcovid noprint nway missing;
	where year=2020 and 3<=month<=8 and (death_date=. or death_date>=mdy(3,1,2020)); * Limit to Mar-August;
	class bene_id death_date age_group race_bg year;
	var race_d: female cc: plwd any_coviddx_max lis dual;
	output out=&tempwork..samp_yearly mean(race_d: female cc: plwd lis dual)= max(any_coviddx_max)=covidany;
run;

proc univariate data=&tempwork..samp_yearly noprint outtable=&tempwork..samp_yrck; run;

* Adding in COPD and CKD;
data &tempwork..copd_ckd;
	set mbsf.mbsf_cc_2017 (in=a keep=bene_id chronickidney copd)
		mbsf.mbsf_cc_2018 (in=b keep=bene_id chronickidney copd)
		mbsf.mbsf_cc_2019 (in=c keep=bene_id chronickidney copd)
		mbsf.mbsf_cc_2020 (in=d keep=bene_id chronickidney copd);
	by bene_id;
	if a then year=2017;
	if b then year=2018;
	if c then year=2019;
	if d then year=2020;
	cc_copd=0;
	cc_ckd=0;
	if chronickidney in(1,3) then cc_ckd=1;
	if copd in(1,3) then cc_copd=1;
run;

proc sort data=&tempwork..copd_ckd; by bene_id year; run;

* Creating yearly zip code;
data &tempwork..zip;
	set mbsf.mbsf_abcd_2017 (in=a keep=bene_id zip_cd)
		mbsf.mbsf_abcd_2018 (in=b keep=bene_id zip_cd)
		mbsf.mbsf_abcd_2019 (in=c keep=bene_id zip_cd)
		mbsf.mbsf_abcd_2020 (in=d keep=bene_id zip_cd);
	by bene_id;
	if a then year=2017;
	if b then year=2018;
	if c then year=2019;
	if d then year=2020;
	zip=zip_cd*1;
run;

proc sort data=&tempwork..zip; by bene_id year; run;
proc sort data=&tempwork..samp_yearly; by bene_id year; run;

data &tempwork..samp_yearly1;
	merge &tempwork..samp_yearly (in=a) &tempwork..copd_ckd (in=b) &tempwork..zip (in=c);
	by bene_id year;
	if a;
	if cc_copd=. then cc_copd=0;
	if cc_ckd=. then cc_ckd=0;
run;

* Merging crosswalk to ZIP code;
proc sort data=&tempwork..samp_yearly1; by year zip_cd; run;
proc sort data=base.ziptozcta0719 out=&tempwork..ziptozcta0719; by year zip; run;

* Just using the 2019 for 2020 as well;
data &tempwork..ziptozcta20;
	set &tempwork..ziptozcta0719 (where=(year=2019));
	year=2020;
run;

proc sort data=&tempwork..ziptozcta20; by year zip; run;

data &tempwork..ziptozcta0720;
	set &tempwork..ziptozcta0719 &tempwork..ziptozcta20;
	by year zip;
run;

data &tempwork..samp_yearly2;
	merge &tempwork..samp_yearly1 (in=a) &tempwork..ziptozcta0720 (in=b);
	by year zip;
	if a;
	foundzip=b;
run;

* Merging in the education and median income data - using 2019 for 2020;
data &tempwork..medinc_20;
	set base.medinc_1119 (where=(year=2019));
	year=2020;
run;

data &tempwork..educ_20;
	set base.educ_1119 (where=(year=2019));
	year=2020;
run;

proc sort data=&tempwork..medinc_20; by zcta5 year; run;
proc sort data=&tempwork..educ_20; by zcta5 year; run;

data &tempwork..medinc_1120;
	set base.medinc_1119 &tempwork..medinc_20;
	by zcta5 year;
run;

data &tempwork..educ_1120;
	set base.educ_1119 &tempwork..educ_20;
	by zcta5 year;
run;

proc sort data=&tempwork..samp_yearly2; by zcta5 year; run;

data &tempwork..samp_yearly3;
	merge &tempwork..samp_yearly2 (in=a) 
		  &tempwork..educ_1120 (in=b keep=zcta5 year pct_hsgrads_65over) 
		  &tempwork..medinc_1120 (in=c);
	by zcta5 year;
	if a;
	educ=b;
	medinc=c;
run;

proc freq data=&tempwork..samp_yearly3;
	table foundzip educ medinc;
run;

* Fixing the missings;
data &tempwork..samp_yearly3_;
	set &tempwork..samp_yearly3;
	if median_hh_inc>=200000 then median_hh_inc=.;
	if pct_hsgrads_65over>100 then pct_hsgrads_65over=.;
run;

* Getting quartiles on the educ and medinc;
proc univariate data=&tempwork..samp_yearly3_ noprint outtable=&tempwork..educ_quartiles;
	var pct_hsgrads_65over;
run;

proc univariate data=&tempwork..samp_yearly3_ noprint outtable=&tempwork..medinc_quartiles;
	var median_hh_inc;
run;

* Merging with averages by zip-year and averages by state-year;
proc means data=&tempwork..samp_yearly3_ noprint nway;
	class zcta5;
	output out=&tempwork..zcta_avg mean(pct_hsgrads_65over median_hh_inc)=hsg_zcta_avg medinc_zcta_avg;
run;

proc means data=&tempwork..samp_yearly3_ noprint nway;
	class statecode city;
	output out=&tempwork..city_avg mean(pct_hsgrads_65over median_hh_inc)=hsg_city_avg medinc_city_avg;
run;

proc means data=&tempwork..samp_yearly3_ noprint nway;
	class statecode;
	output out=&tempwork..state_avg mean(pct_hsgrads_65over median_hh_inc)=hsg_state_avg medinc_state_avg;
run;

proc sort data=&tempwork..samp_yearly3_ out=&tempwork..samp_yearly3_zcta; by zcta5; run;

data &tempwork..samp_yearly3_1;
	merge &tempwork..samp_yearly3_zcta (in=a) &tempwork..zcta_avg (in=b drop=_type_ _freq_);
	by zcta5;
	if a;
run;

proc sort data=&tempwork..samp_yearly3_1; by statecode city; run;

data &tempwork..samp_yearly3_2;
	merge &tempwork..samp_yearly3_1 (in=a) &tempwork..city_avg (in=b drop=_type_ _freq_);
	by statecode city;
	if a;
run;

proc sort data=&tempwork..samp_yearly3_2; by statecode; run;

data &tempwork..samp_yearly3_3;
	merge &tempwork..samp_yearly3_2 (in=a) &tempwork..state_avg (in=b drop=_type_ _freq_);
	by statecode;
	if a;
	if median_hh_inc=. then median_hh_inc=medinc_zcta_avg;
	if median_hh_inc=. then median_hh_inc=medinc_city_avg;
	if median_hh_inc=. then median_hh_inc=medinc_state_avg;

	if pct_hsgrads_65over=. then pct_hsgrads_65over=hsg_zcta_avg;
	if pct_hsgrads_65over=. then pct_hsgrads_65over=hsg_city_avg;
	if pct_hsgrads_65over=. then pct_hsgrads_65over=hsg_state_avg;
run;

proc univariate data=&tempwork..samp_yearly3_3;
	var pct_hsgrads_65over median_hh_inc;
run;

data &tempwork..samp_yearly4;
	if _n_=1 then set &tempwork..educ_quartiles (rename=(_mean_=pcths_mean _q1_=pcths_p25 _median_=pcths_med _q3_=pcths_p75) keep=_mean_ _q1_ _median_ _q3_) ;
	if _n_=1 then set &tempwork..medinc_quartiles (rename=(_mean_=medinc_mean _q1_=medinc_p25 _median_=medinc_med _q3_=medinc_p75) keep=_mean_ _q1_ _median_ _q3_);
	set &tempwork..samp_yearly3_3;

	* filling in those still missing with median;
	if pct_hsgrads_65over=. then pct_hsgrads_65over=pcths_mean;
	if median_hh_inc=. then median_hh_inc=medinc_mean;

	pcths_q1=0;
	pcths_q2=0;
	pcths_q3=0;
	pcths_q4=0;
	if .<pct_hsgrads_65over<=pcths_p25 then pcths_q1=1;
	if pcths_p25<pct_hsgrads_65over<=pcths_med then pcths_q2=1;
	if pcths_med<pct_hsgrads_65over<=pcths_p75 then pcths_q3=1;
	if pcths_p75<pct_hsgrads_65over then pcths_q4=1;

	medinc_q1=0;
	medinc_q2=0;
	medinc_q3=0;
	medinc_q4=0;
	if .<median_hh_inc<=medinc_p25 then medinc_q1=1;
	if medinc_p25<median_hh_inc<=medinc_med then medinc_q2=1;
	if medinc_med<median_hh_inc<=medinc_p75 then medinc_q3=1;
	if medinc_p75<median_hh_inc then medinc_q4=1;

run;

proc means data=&tempwork..samp_yearly4 noprint;
	class covidany;
	var medinc_q: pcths_q:;
	output out=&tempwork..qck mean()= sum()= /autoname;
run;

* inpatient covid - first inpatient covid after 30 days;
data &tempwork..covidip_;
	set &tempwork..coviddx_2017_2020 (where=(find(clm_typ,'1') and mdy(3,1,2020)<=clm_thru_dt<=mdy(9,30,2020)));

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

proc means data=&tempwork..covidip_ noprint nway;
	where any_coviddx=1;
	class bene_id year;
	output out=&tempwork..covidip min(clm_thru_dt)=first_covidip;
run;

proc sort data=&tempwork..samp_yearly4; by bene_id year; run;

data covid.covidmodelprep;
	merge &tempwork..samp_yearly4 (in=a) &tempwork..bene_first_coviddx (in=b) &tempwork..covidip (in=c keep=bene_id year first_covidip);
	by bene_id;
	if a;

	* age;
	age_lt75=(find(age_group,'1.'));
	age_7584=(find(age_group,'2.'));
	age_ge85=(find(age_group,'3.'));

	* Covid with mortality outcome is death within 30 days of first covid dx;
	if mdy(3,1,2020)<=first_coviddx<=mdy(8,31,2020) then do;
		coviddeath=0;
		diff=intck('day',first_coviddx,death_date);
		if .<intck('day',first_coviddx,death_date)<=30 then coviddeath=1;

		covidip=0;
		ipdiff=intck('day',first_coviddx,first_covidip);
		if .<intck('day',first_coviddx,first_covidip)<=30 then covidip=1;
	end;
run;

* Check diffs;
proc univariate data=covid.covidmodelprep noprint outtable=&tempwork..diffck;
	var diff ipdiff coviddeath covidip;
run;

proc freq data=covid.covidmodelprep;
	table coviddeath*covidip / out=&tempwork..covidipdeath_crosstab;
run;

proc sort data=covid.covidmodelprep; by race_bg; run;

/****** Models ******/
%macro export(out);
proc export data=&tempwork..&out.
	file="&rootpath./Projects/Programs/covid/exports/covid_models2020_ptd19.xlsx"
	dbms=xlsx
	replace;
	sheet="&out.";
run;
%mend;

/**************** Model Predictions ***************/
proc means data=covid.covidmodelprep noprint nway;
	var female race_d: age_7584 age_ge85 dual lis cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_full_means (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictions_full;
	set &tempwork..prediction_full_means (in=a) &tempwork..prediction_full_means (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_full_pred;
	set covid.covidmodelprep &tempwork..covid_predictions_full;
run;

ods output parameterestimates=&tempwork..covidany_all_pred_est;
ods output oddsratios=&tempwork..covidany_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred descending;
	model covidany=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(covidany_all_pred_est);
%export(covidany_all_pred_or);
%export(covidany_all_pred);

ods output parameterestimates=&tempwork..covidip_all_pred_est;
ods output oddsratios=&tempwork..covidip_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred (where=(covidip ne . or predict=1)) descending;
	model covidip=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(covidip_all_pred_est);
%export(covidip_all_pred_or);
%export(covidip_all_pred);

ods output parameterestimates=&tempwork..coviddeath_all_pred_est;
ods output oddsratios=&tempwork..coviddeath_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred (where=(coviddeath ne . or predict=1)) descending;
	model coviddeath=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(coviddeath_all_pred_est);
%export(coviddeath_all_pred_or);
%export(coviddeath_all_pred);

/* Predictions by Race */

proc means data=covid.covidmodelprep noprint nway;
	class race_bg;
	var female age_7584 age_ge85 dual lis cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_means_byrace (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictions_byrace;
	set &tempwork..prediction_means_byrace (in=a) &tempwork..prediction_means_byrace (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_all_pred;
	set covid.covidmodelprep &tempwork..covid_predictions_byrace;
run;

* Predictions for dual/lis;
proc means data=covid.covidmodelprep noprint nway;
	where max(dual,lis)=1;
	class race_bg;
	var female age_7584 age_ge85 cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_meansdl_byrace (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictionsdl_byrace;
	set &tempwork..prediction_meansdl_byrace (in=a) &tempwork..prediction_meansdl_byrace (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_dl_pred;
	set covid.covidmodelprep &tempwork..covid_predictionsdl_byrace;
run;

%macro predbyrace;
%do r=1 %to 6;

ods output parameterestimates=&tempwork..covidany_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidany_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r.")) descending;
	model covidany=plwd female age_7584 age_ge85 dual lis 
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(covidany_strat_pred_est&r.);
%export(covidany_strat_pred_or&r.);
%export(covidany_strat_pred&r.); 

ods output parameterestimates=&tempwork..covidip_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidip_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r." and (covidip ne . or predict=1))) descending;
	model covidip=plwd female age_7584 age_ge85 dual lis 
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(covidip_strat_pred_est&r.);
%export(covidip_strat_pred_or&r.);
%export(covidip_strat_pred&r.); 

ods output parameterestimates=&tempwork..coviddeath_strat_pred_est&r.;
ods output oddsratios=&tempwork..coviddeath_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r." and (coviddeath ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath=plwd female age_7584 age_ge85 dual lis 
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(coviddeath_strat_pred_est&r.);
%export(coviddeath_strat_pred_or&r.);
%export(coviddeath_strat_pred&r.);


/* Restricting to the dual/lis */
ods output parameterestimates=&tempwork..covidany_strat_preddl_est&r.;
ods output oddsratios=&tempwork..covidany_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((race_bg="&r." and max(dual,lis)=1) or predict=1)) descending;
	model covidany=plwd female age_7584 age_ge85 
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_strat_preddl&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(covidany_strat_preddl_est&r.);
%export(covidany_strat_preddl_or&r.);
%export(covidany_strat_preddl&r.);

ods output parameterestimates=&tempwork..covidip_strat_preddl_est&r.;
ods output oddsratios=&tempwork..covidip_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((race_bg="&r." and max(dual,lis)=1 and covidip ne .) or predict=1)) descending;
	model covidip=plwd female age_7584 age_ge85
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_strat_preddl&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(covidip_strat_preddl_est&r.);
%export(covidip_strat_preddl_or&r.);
%export(covidip_strat_preddl&r.);

ods output parameterestimates=&tempwork..coviddeath_strat_preddl_est&r.;
ods output oddsratios=&tempwork..coviddeath_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((race_bg="&r." and coviddeath ne . and max(dual,lis)=1) or predict=1)) descending;
	model coviddeath=plwd female age_7584 age_ge85
		cc_: pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_strat_preddl&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%export(coviddeath_strat_preddl_est&r.);
%export(coviddeath_strat_preddl_or&r.);
%export(coviddeath_strat_preddl&r.);

%end;

%mend;

%predbyrace;
