/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Response to R&R - Change the measurement and outome (death or hospitalization, death within 30 days of hospitalization) period for 2021 & add 2021
	- 2020: COVID from March to November, outcome in December
	- 2021: COVID from January to March, outcome in April;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
proc transpose data=&tempwork..coviddx_2021 out=&tempwork..coviddx_dates21 (drop=_name_ _label_) prefix=covid_dxdt21;
	where mdy(1,1,2021)<=clm_thru_dt<=mdy(3,31,2021);
	var clm_thru_dt;
	by bene_id;
run;

data &tempwork..covidip21_;
	set &tempwork..coviddx_2021 (where=(find(clm_typ,'1') and mdy(1,1,2021)<=clm_thru_dt<=mdy(3,31,2021)));

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

proc transpose data=&tempwork..covidip21_ out=&tempwork..covidip_dates21 (drop=_name_ _label_) prefix=covid_ipdt;
	var clm_thru_dt;
	by bene_id;
run;

* Identify if anyone who died without a hospitalization is in a SNF;
proc freq data=&tempwork..coviddx_snf_2021 noprint; * data set is from coviddx pull;
	table bene_id / out=&tempwork..covidsnf_bene21(drop=count percent);
run;

proc means data=covid.samp_monthly_wcovid2021 noprint nway missing;
	where year=2021 and (death_date=. or death_date>=mdy(1,1,2021));
	class bene_id death_date age_group race_bg year;
	var race_d: female cc: plwd any_coviddx_max lis dual;
	output out=&tempwork..samp21_yearly mean(race_d: female cc: plwd lis dual)= max(any_coviddx_max)=covidany;
run;

proc univariate data=&tempwork..samp21_yearly noprint outtable=&tempwork..samp21_yrck; run;

* Creating yearly zip code;
data &tempwork..zip21;
	set rifq2021.mbsf_abcd_2021 (in=d keep=bene_id zip_cd);
	by bene_id;
	year=2021;
	zip=zip_cd*1;
run;

proc sort data=&tempwork..zip21; by bene_id year; run;
proc sort data=&tempwork..samp21_yearly; by bene_id year; run;

data &tempwork..samp21_yearly1;
	merge &tempwork..samp21_yearly (in=a) &tempwork..bene_copddx2021 (in=b) &tempwork..bene_ckddx21 (in=d) &tempwork..zip21 (in=c);
	by bene_id;
	if a;
	cc_copd=0;
	cc_ckd=0;
	if copd21=1 then cc_copd=1;
	if ckd21=1 then cc_ckd=1;
run;

* Merging crosswalk to ZIP code;
proc sort data=&tempwork..samp21_yearly1; by year zip_cd; run;
proc sort data=base.ziptozcta0719 out=&tempwork..ziptozcta0719; by year zip; run;

* Just using the 2019 for 2020 as well;
data &tempwork..ziptozcta21;
	set &tempwork..ziptozcta0719 (where=(year=2019));
	year=2021;
run;

proc sort data=&tempwork..ziptozcta21; by year zip; run;

data &tempwork..samp21_yearly2;
	merge &tempwork..samp21_yearly1 (in=a) &tempwork..ziptozcta21 (in=b);
	by year zip;
	if a;
	foundzip=b;
run;

* Merging in the education and median income data - using 2019 for 2020;
data &tempwork..medinc_21;
	set base.medinc_1119 (where=(year=2019));
	year=2021;
run;

data &tempwork..educ_21;
	set base.educ_1119 (where=(year=2019));
	year=2021;
run;

proc sort data=&tempwork..medinc_21; by zcta5 year; run;
proc sort data=&tempwork..educ_21; by zcta5 year; run;

proc sort data=&tempwork..samp21_yearly2; by zcta5 year; run;

data &tempwork..samp21_yearly3;
	merge &tempwork..samp21_yearly2 (in=a) 
		  &tempwork..educ_21 (in=b keep=zcta5 year pct_hsgrads_65over) 
		  &tempwork..medinc_21 (in=c);
	by zcta5 year;
	if a;
	educ=b;
	medinc=c;
run;

proc freq data=&tempwork..samp21_yearly3;
	table foundzip educ medinc;
run;

* Fixing the missings;
data &tempwork..samp21_yearly3_;
	set &tempwork..samp21_yearly3;
	if median_hh_inc>=200000 then median_hh_inc=.;
	if pct_hsgrads_65over>100 then pct_hsgrads_65over=.;
run;

* Getting quartiles on the educ and medinc;
proc univariate data=&tempwork..samp21_yearly3_ noprint outtable=&tempwork..educ_quartiles21;
	var pct_hsgrads_65over;
run;

proc univariate data=&tempwork..samp21_yearly3_ noprint outtable=&tempwork..medinc_quartiles21;
	var median_hh_inc;
run;

* Merging with averages by zip-year and averages by state-year;
proc means data=&tempwork..samp21_yearly3_ noprint nway;
	class zcta5;
	output out=&tempwork..zcta_avg21 mean(pct_hsgrads_65over median_hh_inc)=hsg_zcta_avg medinc_zcta_avg;
run;

proc means data=&tempwork..samp21_yearly3_ noprint nway;
	class statecode city;
	output out=&tempwork..city_avg21 mean(pct_hsgrads_65over median_hh_inc)=hsg_city_avg medinc_city_avg;
run;

proc means data=&tempwork..samp21_yearly3_ noprint nway;
	class statecode;
	output out=&tempwork..state_avg21 mean(pct_hsgrads_65over median_hh_inc)=hsg_state_avg medinc_state_avg;
run;

proc sort data=&tempwork..samp21_yearly3_ out=&tempwork..samp21_yearly3_zcta; by zcta5; run;

data &tempwork..samp21_yearly3_1;
	merge &tempwork..samp21_yearly3_zcta (in=a) &tempwork..zcta_avg21 (in=b drop=_type_ _freq_);
	by zcta5;
	if a;
run;

proc sort data=&tempwork..samp21_yearly3_1; by statecode city; run;

data &tempwork..samp21_yearly3_2;
	merge &tempwork..samp21_yearly3_1 (in=a) &tempwork..city_avg21 (in=b drop=_type_ _freq_);
	by statecode city;
	if a;
run;

proc sort data=&tempwork..samp21_yearly3_2; by statecode; run;

data &tempwork..samp21_yearly3_3;
	merge &tempwork..samp21_yearly3_2 (in=a) &tempwork..state_avg21 (in=b drop=_type_ _freq_);
	by statecode;
	if a;
	if median_hh_inc=. then median_hh_inc=medinc_zcta_avg;
	if median_hh_inc=. then median_hh_inc=medinc_city_avg;
	if median_hh_inc=. then median_hh_inc=medinc_state_avg;

	if pct_hsgrads_65over=. then pct_hsgrads_65over=hsg_zcta_avg;
	if pct_hsgrads_65over=. then pct_hsgrads_65over=hsg_city_avg;
	if pct_hsgrads_65over=. then pct_hsgrads_65over=hsg_state_avg;
run;

proc univariate data=&tempwork..samp21_yearly3_3;
	var pct_hsgrads_65over median_hh_inc;
run;

data &tempwork..samp21_yearly4;
	if _n_=1 then set &tempwork..educ_quartiles21 (rename=(_mean_=pcths_mean _q1_=pcths_p25 _median_=pcths_med _q3_=pcths_p75) keep=_mean_ _q1_ _median_ _q3_) ;
	if _n_=1 then set &tempwork..medinc_quartiles21 (rename=(_mean_=medinc_mean _q1_=medinc_p25 _median_=medinc_med _q3_=medinc_p75) keep=_mean_ _q1_ _median_ _q3_);
	set &tempwork..samp21_yearly3_3;

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

proc means data=&tempwork..samp21_yearly4 noprint;
	class covidany;
	var medinc_q: pcths_q:;
	output out=&tempwork..qck21 mean()= sum()= /autoname;
run;

proc sort data=&tempwork..samp21_yearly4; by bene_id; run;

data covid.rr_covidmodelprepany_2021;
	merge &tempwork..samp21_yearly4 (in=a drop=covidany) &tempwork..coviddx_dates21 (in=b) &tempwork..covidip_dates21 (in=c) &tempwork..covidsnf_bene21 (in=d)
	base.cci_ffsptd_bene21_janapr (in=e keep=bene_id wgtcc2021 rename=(wgtcc2021=cci));
	by bene_id;
	if a;

	covidany=b;

	* age;
	age_lt75=(find(age_group,'1.'));
	age_7584=(find(age_group,'2.'));
	age_ge85=(find(age_group,'3.'));

	if covidany=1 then do;
		covidanyip=c;
		covidanysnf=d;
	end;

	array coviddxdt [*] covid_dxdt:;
	array covidipdt [*] covid_ipdt:;

	* Covid with mortality outcome is death within 30 days of any covid dx;
	if covidany=1 then do;
		coviddeath_any=0;
		do i=1 to dim(coviddxdt);
			if .<intck('day',coviddxdt[i],death_date)<=30 then coviddeath_any=1;
		end;
	
		covidip_any=0;
		do i=1 to dim(coviddxdt);
			do j=1 to dim(covidipdt);
				ipdiff2=intck('day',coviddxdt[i],covidipdt[j]);
				if 0<=intck('day',coviddxdt[i],covidipdt[j])<=30 then covidip_any=1;
			end;
		end;

		* Get death within 30 days of a covid ip and death within 60 days;
		if covidip_any=1 then do;
			covidip_death30=0;
			covidip_death60=0;
			do k=1 to dim(covidipdt);
				if 0<=intck('day',covidipdt[k],death_date)<=30 then covidip_death30=1;
				if 0<=intck('day',covidipdt[k],death_date)<=60 then covidip_death60=1;
			end;
		end;

		coviddeath_noip=(coviddeath_any=1 and covidanyip=0);
	end;

	drop covid_dxdt: covid_ipdt:;

run;

proc freq data= covid.rr_covidmodelprepany_2021;
	table covidip_death30 covidip_death60;
run;

proc univariate data=covid.rr_covidmodelprepany_2021 noprint outtable=covidmodelprep21; run;

* Merging to urban/rural continuum - first merging to FIPS county and then merging to urban rural continuum;
data &tempwork..rr_covidmodel_urbanrural21;
	merge covid.rr_covidmodelprepany_2021 (in=a) rifq2021.mbsf_abcd_2021 (keep=bene_id STATE_CNTY_FIPS_CD_01-STATE_CNTY_FIPS_CD_12)
	mbsf.mbsf_abcd_2019 (keep=bene_id STATE_CNTY_FIPS_CD_01-STATE_CNTY_FIPS_CD_12 rename=(
		state_cnty_fips_cd_01=fips2019_01
		state_cnty_fips_cd_02=fips2019_02
		state_cnty_fips_cd_03=fips2019_03
		state_cnty_fips_cd_04=fips2019_04
		state_cnty_fips_cd_05=fips2019_05
		state_cnty_fips_cd_06=fips2019_06
		state_cnty_fips_cd_07=fips2019_07
		state_cnty_fips_cd_08=fips2019_08
		state_cnty_fips_cd_09=fips2019_09
		state_cnty_fips_cd_10=fips2019_10
		state_cnty_fips_cd_11=fips2019_11
		state_cnty_fips_cd_12=fips2019_12))
	mbsf.mbsf_abcd_2018 (keep=bene_id STATE_CNTY_FIPS_CD_01-STATE_CNTY_FIPS_CD_12 rename=(
		state_cnty_fips_cd_01=fips2018_01
		state_cnty_fips_cd_02=fips2018_02
		state_cnty_fips_cd_03=fips2018_03
		state_cnty_fips_cd_04=fips2018_04
		state_cnty_fips_cd_05=fips2018_05
		state_cnty_fips_cd_06=fips2018_06
		state_cnty_fips_cd_07=fips2018_07
		state_cnty_fips_cd_08=fips2018_08
		state_cnty_fips_cd_09=fips2018_09
		state_cnty_fips_cd_10=fips2018_10
		state_cnty_fips_cd_11=fips2018_11
		state_cnty_fips_cd_12=fips2018_12))
	mbsf.mbsf_abcd_2014 (keep=bene_id STATE_CNTY_FIPS_CD_01-STATE_CNTY_FIPS_CD_12 rename=(
		state_cnty_fips_cd_01=fips2014_01
		state_cnty_fips_cd_02=fips2014_02
		state_cnty_fips_cd_03=fips2014_03
		state_cnty_fips_cd_04=fips2014_04
		state_cnty_fips_cd_05=fips2014_05
		state_cnty_fips_cd_06=fips2014_06
		state_cnty_fips_cd_07=fips2014_07
		state_cnty_fips_cd_08=fips2014_08
		state_cnty_fips_cd_09=fips2014_09
		state_cnty_fips_cd_10=fips2014_10
		state_cnty_fips_cd_11=fips2014_11
		state_cnty_fips_cd_12=fips2014_12));
	by bene_id;
	if a;

	array fips [*] state_cnty_fips_cd_01-state_cnty_fips_cd_12;
	array fips19 [*] fips2019_01-fips2019_12;
	array fips18 [*] fips2018_01-fips2018_12;
	array fips14 [*] fips2014_01-fips2014_12;

	do i=1 to dim(fips);
		if fips[i] ne "" then fips_county=fips[i];
	end;
	if fips_county="" then do i=1 to dim(fips19);
		if fips19[i] ne "" then fips_county=fips19[i];
	end;
	if fips_county="" then do i=1 to dim(fips18);
		if fips18[i] ne "" then fips_county=fips18[i];
	end;
	if fips_county="" then do i=1 to dim(fips14);
		if fips14[i] ne "" then fips_county=fips14[i];
	end;

	drop state_cnty_fips:;

	fips_missing=(fips_county="");

run;

proc freq data=&tempwork..rr_covidmodel_urbanrural21 noprint;
	table fips_missing / out=&tempwork..ckmissing;
run;

* Merge again;
data &tempwork..rr_covidmodel21;
	merge &tempwork..rr_covidmodel_urbanrural21 (in=a where=(fips_missing=1)) 
		mbsf.mbsf_abcd_2014 (in=b keep=bene_id state_cnty_fips_cd_12 rename=(state_cnty_fips_cd_12=fips14))
		mbsf.mbsf_abcd_2015 (in=b keep=bene_id state_cnty_fips_cd_12 rename=(state_cnty_fips_cd_12=fips15))
		mbsf.mbsf_abcd_2016 (in=b keep=bene_id state_cnty_fips_cd_12 rename=(state_cnty_fips_cd_12=fips16))
		mbsf.mbsf_abcd_2017 (in=b keep=bene_id state_cnty_fips_cd_12 rename=(state_cnty_fips_cd_12=fips17));
	by bene_id;
	if a;
run;

data &tempwork..rr_covidmodel21_1;
	set &tempwork..rr_covidmodel21;
	array fips [*] fips14-fips17;
	do i=1 to dim(fips);
		if fips[i] ne "" then fips_county=fips[i];
	end;
run;

data &tempwork..rr_covidmodel_urbanrural21_2;
	set &tempwork..rr_covidmodel_urbanrural21 (where=(fips_missing=0))
		&tempwork..rr_covidmodel21_1;
run;

proc sort data=&tempwork..rr_covidmodel_urbanrural21_2; by fips_county; run;
proc sort data=base.urbanruralcont; by fips_county; run;

data &tempwork..rr_covidmodel_urbanrural21_3;
	merge &tempwork..rr_covidmodel_urbanrural21_2 (in=a) base.urbanruralcont (in=b keep=fips_county urbanrural13);
	by fips_county;
	if a;
	urban=b;
run;

proc freq data=&tempwork..rr_covidmodel_urbanrural21_3 noprint;
	table urban / out=&tempwork..urbanmrg;
run;

options obs=max;
data &tempwork..rr_covidmodel_urbanrural21_4;
	set &tempwork..rr_covidmodel_urbanrural21_3 (keep=bene_id death_date fips_county race: covidany covidanysnf covidip_any
		coviddeath_any coviddeath_noip covidip_death30 female cc: dual lis pcths: medinc: age_: plwd urbanrural13);
	if urbanrural13 ne "" then do;
		urban=0;
		if urbanrural13 in("01","02","03") then urban=1;
	end;
run;

/**************** Model Predictions ***************/
%macro exportany21(out);
proc export data=&tempwork..&out.
	file="&rootpath./Projects/Programs/covid/exports/rr_covid_models21.xlsx"
	dbms=xlsx
	replace;
	sheet="&out.";
run;
%mend;

proc means data=covid.rr_covidmodelprepany_2021 noprint nway;
	var female race_d: age_7584 age_ge85 dual lis cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_full_means21 (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictions_full21;
	set &tempwork..prediction_full_means21 (in=a) &tempwork..prediction_full_means21 (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_full_pred21;
	set covid.rr_covidmodelprepany_2021 &tempwork..covid_predictions_full21;
run;

ods output parameterestimates=&tempwork..covidany_all_pred_est21;
ods output oddsratios=&tempwork..covidany_all_pred_or21;
proc logistic data=&tempwork..covidmodels_full_pred21 descending;
	model covidany=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_all_pred21 (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidany_all_pred_est21);
%exportany21(covidany_all_pred_or21);
%exportany21(covidany_all_pred21);

ods output parameterestimates=&tempwork..covidip_all_pred_est21;
ods output oddsratios=&tempwork..covidip_all_pred_or21;
proc logistic data=&tempwork..covidmodels_full_pred21 (where=(covidip_any ne . or predict=1)) descending;
	model covidip_any=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_all_pred21 (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidip_all_pred_est21);
%exportany21(covidip_all_pred_or21);
%exportany21(covidip_all_pred21);

ods output parameterestimates=&tempwork..coviddeath_all_pred_est21;
ods output oddsratios=&tempwork..coviddeath_all_pred_or21;
proc logistic data=&tempwork..covidmodels_full_pred21 (where=(coviddeath_any ne . or predict=1)) descending;
	model coviddeath_any=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_all_pred21 (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(coviddeath_all_pred_est21);
%exportany21(coviddeath_all_pred_or21);
%exportany21(coviddeath_all_pred21);

ods output parameterestimates=&tempwork..covidipdeath_all_pred_est21;
ods output oddsratios=&tempwork..covidipdeath_all_pred_or21;
proc logistic data=&tempwork..covidmodels_full_pred21 (where=((covidip_death30 ne . and covidip_any=1) or predict=1)) descending;
	model covidip_death30=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath_all_pred21 (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidipdeath_all_pred_est21);
%exportany21(covidipdeath_all_pred_or21);
%exportany21(covidipdeath_all_pred21);

ods output parameterestimates=&tempwork..covidipdeath60_all_pred_est21;
ods output oddsratios=&tempwork..covidipdeath60_all_pred_or21;
proc logistic data=&tempwork..covidmodels_full_pred21 (where=((covidip_death60 ne . and covidip_any=1) or predict=1)) descending;
	model covidip_death60=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath60_all_pred21 (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidipdeath60_all_pred_est21);
%exportany21(covidipdeath60_all_pred_or21);
%exportany21(covidipdeath60_all_pred21);

* Model with Interactions;
data rr_covidmodelprepany_2021int;
	set covid.rr_covidmodelprepany_2021;
	race_dw_plwd=race_dw*plwd;
	race_db_plwd=race_db*plwd;
	race_dh_plwd=race_dh*plwd;
	race_dn_plwd=race_dn*plwd;
	race_do_plwd=race_do*plwd;
	race_da_plwd=race_da*plwd;
run;

ods output parameterestimates=&tempwork..covidip_all_int_est21;
ods output oddsratios=&tempwork..covidip_all_int_or21;
proc logistic data=rr_covidmodelprepany_2021int (where=(covidip_any ne .)) descending;
	model covidip_any=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 race_db_plwd race_dh_plwd race_da_plwd race_dn_plwd race_do_plwd;
run;
%exportany21(covidip_all_int_est21);
%exportany21(covidip_all_int_or21);

ods output parameterestimates=&tempwork..coviddeath_all_int_est21;
ods output oddsratios=&tempwork..coviddeath_all_int_or21;
proc logistic data=rr_covidmodelprepany_2021int (where=(coviddeath_any ne .)) descending;
	model coviddeath_any=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 race_db_plwd race_dh_plwd race_da_plwd race_dn_plwd race_do_plwd;
run;
%exportany21(coviddeath_all_int_est21);
%exportany21(coviddeath_all_int_or21);

ods output parameterestimates=&tempwork..covidipdeath_all_int_est21;
ods output oddsratios=&tempwork..covidipdeath_all_int_or21;
proc logistic data=rr_covidmodelprepany_2021int (where=((covidip_death30 ne . and covidip_any=1))) descending;
	model covidip_death30=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 race_db_plwd race_dh_plwd race_da_plwd race_dn_plwd race_do_plwd;
run;
%exportany21(covidipdeath_all_int_est21);
%exportany21(covidipdeath_all_int_or21);

/* Predictions by Race */
proc means data=covid.rr_covidmodelprepany_2021 noprint nway;
	class race_bg;
	var female age_7584 age_ge85 dual lis cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_means_byrace21 (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictions_byrace21;
	set &tempwork..prediction_means_byrace21 (in=a) &tempwork..prediction_means_byrace21 (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_all_pred21;
	set covid.rr_covidmodelprepany_2021 &tempwork..covid_predictions_byrace21;
run;

%macro predbyraceany;
%do r=1 %to 6;
/*
ods output parameterestimates=&tempwork..covidany21_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidany21_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred21 (where=(race_bg="&r.")) descending;
	model covidany=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany21_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidany21_strat_pred_est&r.);
%exportany21(covidany21_strat_pred_or&r.);
%exportany21(covidany21_strat_pred&r.); 

ods output parameterestimates=&tempwork..covidip21_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidip21_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred21 (where=(race_bg="&r." and (covidip_any ne . or predict=1))) descending;
	model covidip_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip21_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidip21_strat_pred_est&r.);
%exportany21(covidip21_strat_pred_or&r.);
%exportany21(covidip21_strat_pred&r.); 

ods output parameterestimates=&tempwork..coviddth21_strat_pred_est&r.;
ods output oddsratios=&tempwork..coviddth21_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred21 (where=(race_bg="&r." and (coviddeath_any ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddth21_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(coviddth21_strat_pred_est&r.);
%exportany21(coviddth21_strat_pred_or&r.);
%exportany21(coviddth21_strat_pred&r.);

ods output parameterestimates=&tempwork..covidipdth21_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidipdth21_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred21 (where=((race_bg="&r." and covidip_any and covidip_death30 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death30=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdth21_strat_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidipdth21_strat_pred_est&r.);
%exportany21(covidipdth21_strat_pred_or&r.);
%exportany21(covidipdth21_strat_pred&r.);
*/
ods output parameterestimates=&tempwork..covidipdth6021_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidipdth6021_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred21 (where=((race_bg="&r." and covidip_any and covidip_death60 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death60=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdth6021_strat_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidipdth6021_strat_pred_est&r.);
%exportany21(covidipdth6021_strat_pred_or&r.);
%exportany21(covidipdth6021_strat_pred&r.);
%end;

%mend;

%predbyraceany;

/* Predictiosn by race only */
proc means data=covid.rr_covidmodelprepany_2021 noprint nway;
	class race_bg;
	var plwd female age_7584 age_ge85 dual lis cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_means_byrace21 (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covidmodels_byrace_pred21;
	set covid.rr_covidmodelprepany_2021 (in=a) &tempwork..prediction_means_byrace21 (in=b);
	predict=b;
run;


%macro predbyraceany_all;
%do r=1 %to 6;
ods output parameterestimates=&tempwork..covidany21_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..covidany21_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_byrace_pred21 (where=(race_bg="&r.")) descending;
	model covidany=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany21_onlyr_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidany21_onlyr_pred_est&r.);
%exportany21(covidany21_onlyr_pred_or&r.);
%exportany21(covidany21_onlyr_pred&r.); 

ods output parameterestimates=&tempwork..covidip21_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..covidip21_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_byrace_pred21 (where=(race_bg="&r." and (covidip_any ne . or predict=1))) descending;
	model covidip_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip21_onlyr_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidip21_onlyr_pred_est&r.);
%exportany21(covidip21_onlyr_pred_or&r.);
%exportany21(covidip21_onlyr_pred&r.); 

ods output parameterestimates=&tempwork..coviddth21_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..coviddth21_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_byrace_pred21 (where=(race_bg="&r." and (coviddeath_any ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddth21_onlyr_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(coviddth21_onlyr_pred_est&r.);
%exportany21(coviddth21_onlyr_pred_or&r.);
%exportany21(coviddth21_onlyr_pred&r.);


ods output parameterestimates=&tempwork..covidipdth21_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..covidipdth21_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_byrace_pred21 (where=((race_bg="&r." and covidip_any and covidip_death30 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death30=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdth21_onlyr_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany21(covidipdth21_onlyr_pred_est&r.);
%exportany21(covidipdth21_onlyr_pred_or&r.);
%exportany21(covidipdth21_onlyr_pred&r.);
%end;

%mend;

%predbyraceany_all;

/* Sample */

/* Adding death and hospitalization */
* Get any beneficiary that had an inpatient claim between March and September of 2021;
%macro ip;
proc sql;
	%do mo=3 %to 9;
	create table &tempwork..ip21_&mo. as
	select distinct bene_id
	from rifq2021.inpatient_claims_0&mo. 
	order by bene_id;
	%end;
	%do mo=10 %to 12;
	create table &tempwork..ip21_&mo. as
	select distinct bene_id
	from rifq2021.inpatient_claims_&mo. 
	order by bene_id;
	%end;
quit;
%mend;

%ip;

data &tempwork..beneip21;
	merge &tempwork..ip21_3-&tempwork..ip21_12;
	by bene_id;
run;

proc sort data=&tempwork..rr_covidmodel_urbanrural21_4; by bene_id; run;

data &tempwork..rr_covidmodel_urbanrural21_5;
	merge &tempwork..rr_covidmodel_urbanrural21_4 (in=a) &tempwork..beneip21 (in=b);
	by bene_id;

	if a;

	* inpatient;
	allip=b;

	* death;
	alldeath=0;
	if .<death_date<=mdy(4,30,2021) then alldeath=1;

	* death conditional on inpatient;
	allipdeath=0;
	if allip and alldeath then allipdeath=1;

run;

* Check that no death occurs before March;
data &tempwork..rr_covidmodel_urbanrural21_ck;
	set &tempwork..rr_covidmodel_urbanrural21_5;
	if .<death_date<mdy(3,1,2021);
run;

* COVID any;
proc means data=&tempwork..rr_covidmodel_urbanrural21_5 noprint;
	class covidany plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
	output out=covid_models_sampany21 sum()= mean()= / autoname;
run;

proc export data=covid_models_sampany21
	outfile="&rootpath./Projects/Programs/covid/exports/rr_covid_models21.xlsx"
	dbms=xlsx
	replace;
	sheet="samp";
run;


proc means data=&tempwork..rr_covidmodel_urbanrural21_5 noprint;
	where covidip_any;
	class plwd;
	var female race_d: age_lt75 age_7584 age_ge85 cc_: dual lis pcths_q: medinc_q: covidip_any coviddeath_any covidanysnf covidip_death30 urban allip alldeath allipdeath;
	output out=covid_models_ipany21 sum()= mean()= / autoname;
run;

proc export data=covid_models_ipany21
	outfile="&rootpath./Projects/Programs/covid/exports/rr_covid_models21.xlsx"
	dbms=xlsx
	replace;
	sheet="sampipany";
run;
