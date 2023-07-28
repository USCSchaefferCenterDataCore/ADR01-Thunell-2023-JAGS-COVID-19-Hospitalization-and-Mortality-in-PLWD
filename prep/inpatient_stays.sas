/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Identify inpatient stays in 2017-2020
	Acute inpatient hospital claims are a subset of the claims in the IP data file
	consisting of data from both acute hospitals and critical access hospitals (CAH).
	These facilities are those where either the 3rd digit of the provider number 
	(SAS variable PRVDR_NUM) = 0 or the 3rd and 4th digits of PRVDR_NUM = 13.;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2017;
%let maxyear=2020;

options obs=max;
%macro phys(byear,eyear);
	%do yr=&byear. %to &eyear.;

		data &tempwork..inpatient_&yr.;
			set 
				%if &yr.<=&demogv. %then %do;
					%do mo=1 %to 9;
						rif&yr..inpatient_claims_0&mo. (keep=bene_id clm_from_dt clm_thru_dt prvdr_num clm_id)
					%end;
					%do mo=10 %to 12;
						rif&yr..inpatient_claims_&mo. (keep=bene_id clm_from_dt clm_thru_dt prvdr_num clm_id)
					%end;
				%end;
				%if &yr.>&demogv. %then %do;
						%do mo=1 %to 9;
						rifq&yr..inpatient_claims_0&mo. (keep=bene_id clm_from_dt clm_thru_dt prvdr_num clm_id)
					%end;
					%do mo=10 %to 12;
						rifq&yr..inpatient_claims_&mo. (keep=bene_id clm_thru_dt prvdr_num clm_id)
					%end; 
				%end;
			;
			by bene_id clm_id;
			if substr(prvdr_num,3,1)='0' or substr(prvdr_num,3,2)='13' then acute_ip=1;
			if acute_ip=1;
			prvdr_34dig=substr(prvdr_num,3,2);
			source='inpatient';
		run;

	%end;

	* Setting all together;
	data &tempwork..acute_ip_2017_2020;
		set &tempwork..inpatient_&byear.-&tempwork..inpatient_&eyear.;
		by bene_id clm_id;
	run;

%mend;

%phys(&minyear.,&maxyear.);

proc freq data=&tempwork..acute_ip_2017_2020 noprint;
	table prvdr_34dig / out=&tempwork..prvdr_ck;
run;

* Checking how many claims occur on the same day;
proc sort data=&tempwork..acute_ip_2017_2020 out=ip_s_dt nodupkey; by bene_id clm_thru_dt clm_id; run;

data phys_dtdupcheck;
	set ip_s_dt;
	by bene_id clm_thru_dt clm_id;
	if not(first.clm_thru_dt and last.clm_thru_dt);
run;

* Checking how many claims span multiple days;
proc sort data=&tempwork..acute_ip_2017_2020 out=ip_s_clm nodupkey; by bene_id clm_id clm_thru_dt; run;

data phys_clmdupcheck;
	set ip_s_clm;
	by bene_id clm_id clm_thru_dt;
	if not(first.clm_id and last.clm_id);
run;




