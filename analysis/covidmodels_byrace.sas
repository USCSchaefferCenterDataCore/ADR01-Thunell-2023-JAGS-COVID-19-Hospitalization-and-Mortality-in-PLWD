/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: COVID any models by race;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

/**** Models by race only and not by PLWD ****/
%macro exportany(out);
proc export data=&tempwork..&out.
	file="&rootpath./Projects/Programs/covid/exports/covid_models2020_anydx_byraceonly.xlsx"
	dbms=xlsx
	replace;
	sheet="&out.";
run;
%mend;

proc means data=covid.covidmodelprepany noprint nway;
	class race_bg;
	var plwd female age_7584 age_ge85 dual lis cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4;
	output out=&tempwork..prediction_means_byrace (drop=_type_ _freq_) mean()=;
run;

data &tempwork..covidmodels_all_pred;
	set covid.covidmodelprepany (in=a) &tempwork..prediction_means_byrace (in=b);
	predict=b;
run;

%macro predbyraceany_all;
%do r=1 %to 6;
ods output parameterestimates=&tempwork..covidany_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..covidany_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r.")) descending;
	model covidany=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidany_onlyr_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidany_onlyr_pred_est&r.);
%exportany(covidany_onlyr_pred_or&r.);
%exportany(covidany_onlyr_pred&r.); 

ods output parameterestimates=&tempwork..covidip_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..covidip_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r." and (covidip_any ne . or predict=1))) descending;
	model covidip_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidip_onlyr_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidip_onlyr_pred_est&r.);
%exportany(covidip_onlyr_pred_or&r.);
%exportany(covidip_onlyr_pred&r.); 

ods output parameterestimates=&tempwork..coviddeath_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..coviddeath_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r." and (coviddeath_any ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_any=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeath_onlyr_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeath_onlyr_pred_est&r.);
%exportany(coviddeath_onlyr_pred_or&r.);
%exportany(coviddeath_onlyr_pred&r.);

ods output parameterestimates=&tempwork..coviddeathnoip_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..coviddeathnoip_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=(race_bg="&r." and (coviddeath_noip ne . or predict=1))) descending; * 7/1/2021 - limiting to COVID any;
	model coviddeath_noip=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..coviddeathnoip_onlyr_pred&r. (where=(predict=1) keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(coviddeathnoip_onlyr_pred_est&r.);
%exportany(coviddeathnoip_onlyr_pred_or&r.);
%exportany(coviddeathnoip_onlyr_pred&r.);

ods output parameterestimates=&tempwork..covidanysnf_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..covidanysnf_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=((race_bg="&r." and coviddeath_noip and covidanysnf ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidanysnf=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidanysnf_onlyr_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidanysnf_onlyr_pred_est&r.);
%exportany(covidanysnf_onlyr_pred_or&r.);
%exportany(covidanysnf_onlyr_pred&r.);

ods output parameterestimates=&tempwork..covidipdeath_onlyr_pred_est&r.;
ods output oddsratios=&tempwork..covidipdeath_onlyr_pred_or&r.;
proc logistic data=&tempwork..covidmodels_all_pred (where=((race_bg="&r." and covidip_any and covidip_death30 ne .) or predict=1)) descending; * 7/1/2021 - limiting to COVID any;
	model covidip_death30=plwd female age_7584 age_ge85 dual lis 
		cc_: cci pcths_q2-pcths_q4 medinc_q2-medinc_q4 ;
	output out=&tempwork..covidipdeath_onlyr_pred&r. (where=(predict=1 and race_bg="&r.") keep=predict plwd race_bg p lcl ucl) predicted=p predprobs=(i x) l=lcl u=ucl;
run;
%exportany(covidipdeath_onlyr_pred_est&r.);
%exportany(covidipdeath_onlyr_pred_or&r.);
%exportany(covidipdeath_onlyr_pred&r.);
%end;

%mend;

%predbyraceany_all;
