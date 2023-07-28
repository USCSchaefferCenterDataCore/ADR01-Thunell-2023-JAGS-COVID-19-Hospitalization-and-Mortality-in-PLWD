/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: COVID annual dataset
	Sample:  
	•	Enrolled in FFS Parts A & B, non-LTC facilities (community-dwelling)
	•	Months/years: March -September 2017-2019, 2020 

	Key Variables:
	•  Two outcomes - COVID and inpatient COVID
	DV
		ADRD verified with dx, symptoms
	•	Race/ethnicity- sex (one-time)
	•	Health: comorbidities (prevalent, annual)
	•	Economic: LIS, dual (annual)
	•	Zip code vars: % HS- med income (annual)

	covidmodelprepany - bases hospitalization and death after ANY covid dx
	covidmodeprep - bases hospitalization ;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

proc transpose data=&tempwork..coviddx_2017_2020 out=&tempwork..coviddx_dates (drop=_name_ _label_) prefix=covid_dxdt;
	where mdy(3,1,2020)<=clm_thru_dt<=mdy(8,31,2020);
	var clm_thru_dt;
	by bene_id;
run;

options obs=max;
data &tempwork..covidip_;
	set &tempwork..coviddx_2017_2020 (where=(find(clm_typ,'1') and mdy(3,1,2020)<=clm_thru_dt<=mdy(8,31,2020)));

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

proc transpose data=&tempwork..covidip_ out=&tempwork..covidip_dates (drop=_name_ _label_) prefix=covid_ipdt;
	var clm_thru_dt;
	by bene_id;
run;

* Identify if anyone who died without a hospitalization is in a SNF;
data &tempwork..coviddx_snf;
	set &tempwork..coviddx_snf_2017-&tempwork..coviddx_snf_2020;
run;

proc freq data=&tempwork..coviddx_snf noprint;
	table bene_id / out=&tempwork..covidsnf_bene(drop=count percent);
run;

* Getting CCI which didn't get pulled ;
proc means data=covid.samp_monthly_wcovid noprint nway missing;
	where year=2020 and 3<=month<=8 and (death_date=. or death_date>=mdy(3,1,2020)); * Limit to Mar-August;
	class bene_id death_date age_group race_bg year;
	output out=&tempwork..cci_yearly mean(wgtcc)=cci max(wgtcc)=wgtcc;
run;

data covid.covidmodelprepany (drop=covid_dxdt: covid_ipdt:);
	merge covid.covidmodelprep (in=a) &tempwork..coviddx_dates (in=b) &tempwork..covidip_dates (in=c) &tempwork..covidsnf_bene (in=d)
	&tempwork..cci_yearly (in=e keep=bene_id cci);
	by bene_id;
	if a;

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

proc freq data= covid.covidmodelprepany;
	table covidip_death30 covidip_death60;
run;

proc means data=covid.covidmodelprepany noprint nway;

* SNF among coviddeath_noip;
proc means data=covid.covidmodelprepany noprint;
	class plwd race_bg;
	var coviddeath_noip;
	output out=&tempwork..death_ipck mean()= sum()= / autoname;
run;

proc means data=covid.covidmodelprepany noprint;
	where coviddeath_noip=1;
	class plwd race_bg;
	var covidanysnf;
	output out=&tempwork..deathnoip_snf mean()= sum()= / autoname;
run;

proc export data=&tempwork..deathnoip_snf
	outfile="&rootpath./Projects/Programs/covid/exports/covid_ipdeath.xlsx"
	dbms=xlsx
	replace;
	sheet="covidanysnf";
run;

* Merging to urban/rural continuum - first merging to FIPS county and then merging to urban rural continuum;
data &tempwork..covidmodel_urbanrural;
	merge covid.covidmodelprepany (in=a) rifq2020.mbsf_abcd_2020 (keep=bene_id STATE_CNTY_FIPS_CD_01-STATE_CNTY_FIPS_CD_12)
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

proc freq data=&tempwork..covidmodel_urbanrural noprint;
	table fips_missing / out=&tempwork..ckmissing;
run;

* Merge again;
data &tempwork..covidmodel14;
	merge &tempwork..covidmodel_urbanrural (in=a where=(fips_missing=1)) 
		mbsf.mbsf_abcd_2014 (in=b keep=bene_id state_cnty_fips_cd_12 rename=(state_cnty_fips_cd_12=fips14))
		mbsf.mbsf_abcd_2015 (in=b keep=bene_id state_cnty_fips_cd_12 rename=(state_cnty_fips_cd_12=fips15))
		mbsf.mbsf_abcd_2016 (in=b keep=bene_id state_cnty_fips_cd_12 rename=(state_cnty_fips_cd_12=fips16))
		mbsf.mbsf_abcd_2017 (in=b keep=bene_id state_cnty_fips_cd_12 rename=(state_cnty_fips_cd_12=fips17));
	by bene_id;
	if a;
run;

data &tempwork..covidmodel14_1;
	set &tempwork..covidmodel14;
	array fips [*] fips14-fips17;
	do i=1 to dim(fips);
		if fips[i] ne "" then fips_county=fips[i];
	end;
run;

data &tempwork..covidmodel_urbanrural2;
	set &tempwork..covidmodel_urbanrural (where=(fips_missing=0))
		&tempwork..covidmodel14_1;
run;

proc sort data=&tempwork..covidmodel_urbanrural2; by fips_county; run;
proc sort data=base.urbanruralcont; by fips_county; run;

data &tempwork..covidmodel_urbanrural1;
	merge &tempwork..covidmodel_urbanrural2 (in=a) base.urbanruralcont (in=b keep=fips_county urbanrural13);
	by fips_county;
	if a;
	urban=b;
run;

proc freq data=&tempwork..covidmodel_urbanrural1 noprint;
	table urban / out=&tempwork..urbanmrg;
run;

options obs=max;
data &tempwork..covidmodel_urbanrural3;
	set &tempwork..covidmodel_urbanrural1 (keep=bene_id death_date fips_county race: covidany covidanysnf covidip_any
		coviddeath_any coviddeath_noip covidip_death30 female cc: dual lis pcths: medinc: age_: plwd urbanrural13);
	if urbanrural13 ne "" then do;
		urban=0;
		if urbanrural13 in("01","02","03") then urban=1;
	end;
run;

* Dropping the <1% who didn't have the urban rural continuum;
proc means data=&tempwork..covidmodel_urbanrural3 noprint nway;
	class urban;
	var race_d: female cc: dual lis pcths: medinc: age_lt75 age_7584 age_ge85 plwd covidany coviddeath_any covidip_any covidanysnf;
	output out=&tempwork..urban_stats mean()= sum()= / autoname;
run;

* Rate of urban rural;
proc freq data=&tempwork..covidmodel_urbanrural3 noprint;
	table urbanrural13 / out=&tempwork..ck_urbanruralcont;
run;

/* Urban Rural Statistics */

proc means data=&tempwork..covidmodel_urbanrural3 noprint nway;
	class plwd urban;
	var covidany coviddeath_any covidip_any coviddeath_noip;
	output out=&tempwork..covid_urbanrural_stats mean()= sum()= / autoname;
run;

proc means data=&tempwork..covidmodel_urbanrural3 noprint nway;
	where coviddeath_noip=1;
	class plwd urban;
	var covidanysnf;
	output out=&tempwork..covid_urban_snf mean()= sum()= / autoname;
run;

proc export data=&tempwork..urban_stats
	outfile="&rootpath./Projects/Programs/covid/exports/covid_urbanrural.xlsx"
	dbms=xlsx
	replace;
	sheet="urban_desc";
run;

proc export data=&tempwork..covid_urbanrural_stats
	outfile="&rootpath./Projects/Programs/covid/exports/covid_urbanrural.xlsx"
	dbms=xlsx
	replace;
	sheet="urban_ana";
run;

proc export data=&tempwork..covid_urban_snf
	outfile="&rootpath./Projects/Programs/covid/exports/covid_urbanrural.xlsx"
	dbms=xlsx
	replace;
	sheet="urban_ana_snf";
run;

/**************** Model Predictions ***************/
%macro exportany(out);
proc export data=&tempwork..&out.
	file="&rootpath./Projects/Programs/covid/exports/covid_models2020_anydx.xlsx"
	dbms=xlsx
	replace;
	sheet="&out.";
run;
%mend;

proc means data=covid.covidmodelprepany noprint nway;
	var female race_d: age_7584 age_ge85 dual lis cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_full_means (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictions_full;
	set &tempwork..prediction_full_means (in=a) &tempwork..prediction_full_means (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_full_pred;
	set covid.covidmodelprepany &tempwork..covid_predictions_full;
run;

ods output parameterestimates=&tempwork..covidany_all_pred_est;
ods output oddsratios=&tempwork..covidany_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred descending;
	model covidany=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidany_all_pred_est);
%exportany(covidany_all_pred_or);
%exportany(covidany_all_pred);

ods output parameterestimates=&tempwork..covidip_all_pred_est;
ods output oddsratios=&tempwork..covidip_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred (where=(covidip_any ne . or predict=1)) descending;
	model covidip_any=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidip_all_pred_est);
%exportany(covidip_all_pred_or);
%exportany(covidip_all_pred);

ods output parameterestimates=&tempwork..coviddeath_all_pred_est;
ods output oddsratios=&tempwork..coviddeath_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred (where=(coviddeath_any ne . or predict=1)) descending;
	model coviddeath_any=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeath_all_pred_est);
%exportany(coviddeath_all_pred_or);
%exportany(coviddeath_all_pred);

ods output parameterestimates=&tempwork..coviddeathnoip_all_pred_est;
ods output oddsratios=&tempwork..coviddeathnoip_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred (where=(coviddeath_noip ne . or predict=1)) descending;
	model coviddeath_noip=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeathnoip_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeathnoip_all_pred_est);
%exportany(coviddeathnoip_all_pred_or);
%exportany(coviddeathnoip_all_pred);

ods output parameterestimates=&tempwork..covidanysnf_all_pred_est;
ods output oddsratios=&tempwork..covidanysnf_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred (where=((covidanysnf ne . and coviddeath_noip=1) or predict=1)) descending;
	model covidanysnf=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 cci;
	output out=&tempwork..covidanysnf_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidanysnf_all_pred_est);
%exportany(covidanysnf_all_pred_or);
%exportany(covidanysnf_all_pred);

ods output parameterestimates=&tempwork..covidipdeath_all_pred_est;
ods output oddsratios=&tempwork..covidipdeath_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred (where=((covidip_death30 ne . and covidip_any=1) or predict=1)) descending;
	model covidip_death30=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath_all_pred_est);
%exportany(covidipdeath_all_pred_or);
%exportany(covidipdeath_all_pred);

ods output parameterestimates=&tempwork..covidipdeath60_all_pred_est;
ods output oddsratios=&tempwork..covidipdeath60_all_pred_or;
proc logistic data=&tempwork..covidmodels_full_pred (where=((covidip_death60 ne . and covidip_any=1) or predict=1)) descending;
	model covidip_death60=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath60_all_pred (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath60_all_pred_est);
%exportany(covidipdeath60_all_pred_or);
%exportany(covidipdeath60_all_pred);


* Models with interactions;
data covidmodelprepany_int;
	set covid.covidmodelprepany;
	race_dw_plwd=race_dw*plwd;
	race_db_plwd=race_db*plwd;
	race_dh_plwd=race_dh*plwd;
	race_dn_plwd=race_dn*plwd;
	race_do_plwd=race_do*plwd;
	race_da_plwd=race_da*plwd;
run;

ods output parameterestimates=&tempwork..covidip_all_int_est;
ods output oddsratios=&tempwork..covidip_all_int_or;
proc logistic data=covidmodelprepany_int (where=(covidip_any ne .)) descending;
	model covidip_any=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 race_db_plwd race_dh_plwd race_da_plwd race_dn_plwd race_do_plwd;
run;
%exportany(covidip_all_int_est);
%exportany(covidip_all_int_or);

ods output parameterestimates=&tempwork..coviddeath_all_int_est;
ods output oddsratios=&tempwork..coviddeath_all_int_or;
proc logistic data=covidmodelprepany_int (where=(coviddeath_any ne .)) descending;
	model coviddeath_any=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 race_db_plwd race_dh_plwd race_da_plwd race_dn_plwd race_do_plwd;
run;
%exportany(coviddeath_all_int_est);
%exportany(coviddeath_all_int_or);

ods output parameterestimates=&tempwork..covidipdeath_all_int_est;
ods output oddsratios=&tempwork..covidipdeath_all_int_or;
proc logistic data=covidmodelprepany_int (where=(covidip_death30 ne . and covidip_any=1)) descending;
	model covidip_death30=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 race_dh_plwd race_da_plwd race_dn_plwd race_do_plwd;
run;
%exportany(covidipdeath_all_int_est);
%exportany(covidipdeath_all_int_or);

ods output parameterestimates=&tempwork..covidipdeath60_all_int_est;
ods output oddsratios=&tempwork..covidipdeath60_all_int_or;
proc logistic data=covidmodelprepany_int (where=(covidip_death60 ne . and covidip_any=1)) descending;
	model covidip_death60=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 race_dh_plwd race_da_plwd race_dn_plwd race_do_plwd;
run;
%exportany(covidipdeath60_all_int_est);
%exportany(covidipdeath60_all_int_or);

/* Predictions by Race */
proc means data=covid.covidmodelprepany noprint nway;
	class race_bg;
	var female age_7584 age_ge85 dual lis cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_means_byrace (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictions_byrace;
	set &tempwork..prediction_means_byrace (in=a) &tempwork..prediction_means_byrace (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_all_pred;
	set covid.covidmodelprepany &tempwork..covid_predictions_byrace;
run;

* Predictions for dual/lis;

* Full;
proc means data=covid.covidmodelprepany noprint nway;
	var female race_d: age_7584 age_ge85 dual lis cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_full_meansdl (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictions_fulldl;
	set &tempwork..prediction_full_meansdl (in=a) &tempwork..prediction_full_meansdl (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_preddl;
	set covid.covidmodelprepany &tempwork..covid_predictions_fulldl;
run;

ods output parameterestimates=&tempwork..coviddeathnoip_all_preddl_est;
ods output oddsratios=&tempwork..coviddeathnoip_all_preddl_or;
proc logistic data=&tempwork..covidmodels_preddl (where=((max(dual,lis)=1 and coviddeath_noip ne .) or predict=1)) descending;
	model coviddeath_noip=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeathnoip_all_preddl (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeathnoip_all_preddl_est);
%exportany(coviddeathnoip_all_preddl_or);
%exportany(coviddeathnoip_all_preddl);

ods output parameterestimates=&tempwork..covidanysnf_all_preddl_est;
ods output oddsratios=&tempwork..covidanysnf_all_preddl_or;
proc logistic data=&tempwork..covidmodels_preddl (where=((max(dual,lis)=1 and covidanysnf ne . and coviddeath_noip=1) or predict=1)) descending;
	model covidanysnf=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 cci;
	output out=&tempwork..covidanysnf_all_preddl (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidanysnf_all_preddl_est);
%exportany(covidanysnf_all_preddl_or);
%exportany(covidanysnf_all_preddl);

ods output parameterestimates=&tempwork..covidipdeath_all_preddl_est;
ods output oddsratios=&tempwork..covidipdeath_all_preddl_or;
proc logistic data=&tempwork..covidmodels_preddl (where=((max(dual,lis)=1 and covidip_death30 ne . and covidip_any=1) or predict=1)) descending;
	model covidip_death30=plwd female age_7584 age_ge85 race_db race_dh race_da race_dn race_do
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath_all_preddl (where=(predict=1) keep=predict plwd p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath_all_preddl_est);
%exportany(covidipdeath_all_preddl_or);
%exportany(covidipdeath_all_preddl);

* By race;
proc means data=covid.covidmodelprepany noprint nway;
	where max(dual,lis)=1;
	class race_bg;
	var female age_7584 age_ge85 cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_meansdl_byrace (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictionsdl_byrace;
	set &tempwork..prediction_meansdl_byrace (in=a) &tempwork..prediction_meansdl_byrace (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

options obs=max;
data &tempwork..covidmodels_dl_pred;
	set covid.covidmodelprepany &tempwork..covid_predictionsdl_byrace;
run;

%macro predbyraceany;
%do r=1 %to 6;

ods output parameterestimates=&tempwork..covidany_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidany_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r.")) descending;
	model covidany=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidany_strat_pred_est&r.);
%exportany(covidany_strat_pred_or&r.);
%exportany(covidany_strat_pred&r.); 

ods output parameterestimates=&tempwork..covidip_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidip_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r." and (covidip_any ne . or predict=1))) descending;
	model covidip_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidip_strat_pred_est&r.);
%exportany(covidip_strat_pred_or&r.);
%exportany(covidip_strat_pred&r.); 

ods output parameterestimates=&tempwork..coviddeath_strat_pred_est&r.;
ods output oddsratios=&tempwork..coviddeath_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r." and (coviddeath_any ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeath_strat_pred_est&r.);
%exportany(coviddeath_strat_pred_or&r.);
%exportany(coviddeath_strat_pred&r.);

ods output parameterestimates=&tempwork..coviddeathnoip_strat_pred_est&r.;
ods output oddsratios=&tempwork..coviddeathnoip_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r." and (coviddeath_noip ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_noip=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeathnoip_strat_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeathnoip_strat_pred_est&r.);
%exportany(coviddeathnoip_strat_pred_or&r.);
%exportany(coviddeathnoip_strat_pred&r.);

ods output parameterestimates=&tempwork..covidanysnf_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidanysnf_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=((race_bg="&r." and coviddeath_noip and covidanysnf ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidanysnf=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidanysnf_strat_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidanysnf_strat_pred_est&r.);
%exportany(covidanysnf_strat_pred_or&r.);
%exportany(covidanysnf_strat_pred&r.);

ods output parameterestimates=&tempwork..covidipdeath_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidipdeath_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=((race_bg="&r." and covidip_any and covidip_death30 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death30=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath_strat_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath_strat_pred_est&r.);
%exportany(covidipdeath_strat_pred_or&r.);
%exportany(covidipdeath_strat_pred&r.);


ods output parameterestimates=&tempwork..covidipdeath60_strat_pred_est&r.;
ods output oddsratios=&tempwork..covidipdeath60_strat_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=((race_bg="&r." and covidip_any and covidip_death60 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death60=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath60_strat_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath60_strat_pred_est&r.);
%exportany(covidipdeath60_strat_pred_or&r.);
%exportany(covidipdeath60_strat_pred&r.);

/* Restricting to the dual/lis */

ods output parameterestimates=&tempwork..covidany_strat_preddl_est&r.;
ods output oddsratios=&tempwork..covidany_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((race_bg="&r." and max(dual,lis)=1) or predict=1)) descending;
	model covidany=plwd female age_7584 age_ge85 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_strat_preddl&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidany_strat_preddl_est&r.);
%exportany(covidany_strat_preddl_or&r.);
%exportany(covidany_strat_preddl&r.);

ods output parameterestimates=&tempwork..covidip_strat_preddl_est&r.;
ods output oddsratios=&tempwork..covidip_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((race_bg="&r." and max(dual,lis)=1 and covidip_any ne .) or predict=1)) descending;
	model covidip_any=plwd female age_7584 age_ge85
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_strat_preddl&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidip_strat_preddl_est&r.);
%exportany(covidip_strat_preddl_or&r.);
%exportany(covidip_strat_preddl&r.);

ods output parameterestimates=&tempwork..coviddeath_strat_preddl_est&r.;
ods output oddsratios=&tempwork..coviddeath_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((race_bg="&r." and coviddeath_any ne . and max(dual,lis)=1) or predict=1)) descending;
	model coviddeath_any=plwd female age_7584 age_ge85
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_strat_preddl&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeath_strat_preddl_est&r.);
%exportany(coviddeath_strat_preddl_or&r.);
%exportany(coviddeath_strat_preddl&r.);

ods output parameterestimates=&tempwork..coviddthnoip_strat_preddl_est&r.;
ods output oddsratios=&tempwork..coviddthnoip_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((max(dual,lis)=1 and race_bg="&r." and coviddeath_noip ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_noip=plwd female age_7584 age_ge85
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddthnoip_strat_preddl&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddthnoip_strat_preddl_est&r.);
%exportany(coviddthnoip_strat_preddl_or&r.);
%exportany(coviddthnoip_strat_preddl&r.);

ods output parameterestimates=&tempwork..covidanysnf_strat_preddl_est&r.;
ods output oddsratios=&tempwork..covidanysnf_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((max(dual,lis)=1 and race_bg="&r." and coviddeath_noip and covidanysnf ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidanysnf=plwd female age_7584 age_ge85
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidanysnf_strat_preddl&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidanysnf_strat_preddl_est&r.);
%exportany(covidanysnf_strat_preddl_or&r.);
%exportany(covidanysnf_strat_preddl&r.);


ods output parameterestimates=&tempwork..covidipdth_strat_preddl_est&r.;
ods output oddsratios=&tempwork..covidipdth_strat_preddl_or&r.;
proc logistic data=&tempwork..covidmodels_dl_pred (where=((race_bg="&r." and covidip_any and max(dual,lis)=1 and covidip_death30 ne .) or predict=1)) descending; 
	model covidip_death30=plwd female age_7584 age_ge85 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdth_strat_preddl&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdth_strat_preddl_est&r.);
%exportany(covidipdth_strat_preddl_or&r.);
%exportany(covidipdth_strat_preddl&r.);

%end;

%mend;

%predbyraceany;


/* Predictions by Race - means for all */
data &tempwork..covid_predictions_byrace;
	set &tempwork..prediction_full_means (in=w1) 
		&tempwork..prediction_full_means (in=w2)
		&tempwork..prediction_full_means (in=b1)
		&tempwork..prediction_full_means (in=b2)
		&tempwork..prediction_full_means (in=h1)
		&tempwork..prediction_full_means (in=h2)
		&tempwork..prediction_full_means (in=a1)
		&tempwork..prediction_full_means (in=a2)
		&tempwork..prediction_full_means (in=n1)
		&tempwork..prediction_full_means (in=n2)
		&tempwork..prediction_full_means (in=o1)
		&tempwork..prediction_full_means (in=o2)
		;
	if w1 or b1 or h1 or a1 or n1 or o1 then plwd=0;
	if w2 or b2 or h2 or a2 or n2 or o2 then plwd=1;
	predict=1;
	if w1 or w2 then race_bg='1';
	if b1 or b2 then race_bg='2';
	if h1 or h2 then race_bg='5';
	if a1 or a2 then race_bg='4';
	if n1 or n2 then race_bg='6';
	if o1 or o2 then race_bg='3';
run;

data &tempwork..covidmodels_race_pred;
	set covid.covidmodelprepany &tempwork..covid_predictions_byrace;
run;

%macro predbyrace_same;
%do r=1 %to 6;
ods output parameterestimates=&tempwork..covidany_race_pred_est&r.;
ods output oddsratios=&tempwork..covidany_race_pred_or&r.;
proc logistic data=&tempwork..covidmodels_race_pred (where=(race_bg="&r.")) descending;
	model covidany=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_race_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidany_race_pred_est&r.);
%exportany(covidany_race_pred_or&r.);
%exportany(covidany_race_pred&r.); 

ods output parameterestimates=&tempwork..covidip_race_pred_est&r.;
ods output oddsratios=&tempwork..covidip_race_pred_or&r.;
proc logistic data=&tempwork..covidmodels_race_pred (where=(race_bg="&r." and (covidip_any ne . or predict=1))) descending;
	model covidip_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_race_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidip_race_pred_est&r.);
%exportany(covidip_race_pred_or&r.);
%exportany(covidip_race_pred&r.); 

ods output parameterestimates=&tempwork..coviddeath_race_pred_est&r.;
ods output oddsratios=&tempwork..coviddeath_race_pred_or&r.;
proc logistic data=&tempwork..covidmodels_race_pred (where=(race_bg="&r." and (coviddeath_any ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_race_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeath_race_pred_est&r.);
%exportany(coviddeath_race_pred_or&r.);
%exportany(coviddeath_race_pred&r.);


ods output parameterestimates=&tempwork..covidipdeath_race_pred_est&r.;
ods output oddsratios=&tempwork..covidipdeath_race_pred_or&r.;
proc logistic data=&tempwork..covidmodels_race_pred (where=((race_bg="&r." and covidip_any and covidip_death30 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death30=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath_race_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath_race_pred_est&r.);
%exportany(covidipdeath_race_pred_or&r.);
%exportany(covidipdeath_race_pred&r.);

ods output parameterestimates=&tempwork..covidipdeath60_race_pred_est&r.;
ods output oddsratios=&tempwork..covidipdeath60_race_pred_or&r.;
proc logistic data=&tempwork..covidmodels_race_pred (where=((race_bg="&r." and covidip_any and covidip_death60 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death60=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath60_race_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath60_race_pred_est&r.);
%exportany(covidipdeath60_race_pred_or&r.);
%exportany(covidipdeath60_race_pred&r.);
%end;

%mend;

%predbyrace_same;


/* Predictinos for Urban Rural */
proc means data=&tempwork..covidmodel_urbanrural3 noprint nway;
	class urban;
	var female age_7584 age_ge85 dual lis cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_means_byurban (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covid_predictions_byurban;
	set &tempwork..prediction_means_byurban (in=a) &tempwork..prediction_means_byurban (in=b);
	if a then plwd=0;
	if b then plwd=1;
	predict=1;
run;

data &tempwork..covidmodels_urban_pred;
	set &tempwork..covidmodel_urbanrural3 &tempwork..covid_predictions_byurban;
run;

%macro urbanruralpred(u,val);
ods output parameterestimates=&tempwork..covidany_strat_pred_est&u.;
ods output oddsratios=&tempwork..covidany_strat_pred_or&u.;
proc logistic data=&tempwork..covidmodels_urban_pred (where=(urban=&val.)) descending;
	model covidany=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_strat_pred&u. (where=(predict=1) keep=predict plwd urban p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidany_strat_pred_est&u.);
%exportany(covidany_strat_pred_or&u.);
%exportany(covidany_strat_pred&u.); 

ods output parameterestimates=&tempwork..covidip_strat_pred_est&u.;
ods output oddsratios=&tempwork..covidip_strat_pred_or&u.;
proc logistic data=&tempwork..covidmodels_urban_pred (where=(urban=&val. and (covidip_any ne . or predict=1))) descending;
	model covidip_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_strat_pred&u. (where=(predict=1) keep=predict plwd urban p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidip_strat_pred_est&u.);
%exportany(covidip_strat_pred_or&u.);
%exportany(covidip_strat_pred&u.); 

ods output parameterestimates=&tempwork..coviddeath_strat_pred_est&u.;
ods output oddsratios=&tempwork..coviddeath_strat_pred_or&u.;
proc logistic data=&tempwork..covidmodels_urban_pred (where=(urban=&val. and (coviddeath_any ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_strat_pred&u. (where=(predict=1) keep=predict plwd urban p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeath_strat_pred_est&u.);
%exportany(coviddeath_strat_pred_or&u.);
%exportany(coviddeath_strat_pred&u.);

ods output parameterestimates=&tempwork..coviddeathnoip_strat_pred_est&u.;
ods output oddsratios=&tempwork..coviddeathnoip_strat_pred_or&u.;
proc logistic data=&tempwork..covidmodels_urban_pred (where=(urban=&val. and (coviddeath_noip ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_noip=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeathnoip_strat_pred&u. (where=(predict=1) keep=predict plwd urban p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeathnoip_strat_pred_est&u.);
%exportany(coviddeathnoip_strat_pred_or&u.);
%exportany(coviddeathnoip_strat_pred&u.);

ods output parameterestimates=&tempwork..covidanysnf_strat_pred_est&u.;
ods output oddsratios=&tempwork..covidanysnf_strat_pred_or&u.;
proc logistic data=&tempwork..covidmodels_urban_pred (where=((urban=&val. and coviddeath_noip and covidanysnf ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidanysnf=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidanysnf_strat_pred&u. (where=(predict=1 and urban=&val.) keep=predict plwd urban p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidanysnf_strat_pred_est&u.);
%exportany(covidanysnf_strat_pred_or&u.);
%exportany(covidanysnf_strat_pred&u.);

ods output parameterestimates=&tempwork..covidipdeath_strat_pred_est&u.;
ods output oddsratios=&tempwork..covidipdeath_strat_pred_or&u.;
proc logistic data=&tempwork..covidmodels_urban_pred (where=((urban=&val. and covidip_any and covidip_death30 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death30=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath_strat_pred&u. (where=(predict=1 and urban=&val.) keep=predict plwd urban p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath_strat_pred_est&u.);
%exportany(covidipdeath_strat_pred_or&u.);
%exportany(covidipdeath_strat_pred&u.);

%mend;

%urbanruralpred(u,1);
%urbanruralpred(r,0);




