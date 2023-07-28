/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Identify ER visits in inpatient and outpatient revenue files in 2017-2020
	Revenue center codes indicating Emergency Room use were (0450, 0451, 0452, 0456, or 0459).;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2017;
%let maxyear=2020;

options obs=max;
%macro phys(byear,eyear);
	%do yr=&byear. %to &eyear.;

		data &tempwork..er_ip&yr.;
			set 
				%if &yr.<=&demogv. %then %do;
					%do mo=1 %to 9;
						rif&yr..inpatient_revenue_0&mo. (keep=bene_id  clm_thru_dt rev_cntr clm_id)
					%end;
					%do mo=10 %to 12;
						rif&yr..inpatient_revenue_&mo. (keep=bene_id  clm_thru_dt rev_cntr clm_id)
					%end;
				%end;
				%if &yr.>&demogv. %then %do;
						%do mo=1 %to 9;
						rifq&yr..inpatient_revenue_0&mo. (keep=bene_id  clm_thru_dt rev_cntr clm_id)
					%end;
					%do mo=10 %to 12;
						rifq&yr..inpatient_revenue_&mo. (keep=bene_id clm_thru_dt rev_cntr clm_id)
					%end; 
				%end;
			;
			by bene_id clm_id;
			if rev_cntr in('0450','0451','0452','0456','0459') then er=1;
			if er=1;
			format source $15.;
			source='inpatient';
		run;

		data &tempwork..er_op&yr.;
			set 
				%if &yr.<=&demogv. %then %do;
					%do mo=1 %to 9;
						rif&yr..outpatient_revenue_0&mo. (keep=bene_id  clm_thru_dt rev_cntr clm_id)
					%end;
					%do mo=10 %to 12;
						rif&yr..outpatient_revenue_&mo. (keep=bene_id  clm_thru_dt rev_cntr clm_id)
					%end;
				%end;
				%if &yr.>&demogv. %then %do;
						%do mo=1 %to 9;
						rifq&yr..outpatient_revenue_0&mo. (keep=bene_id  clm_thru_dt rev_cntr clm_id)
					%end;
					%do mo=10 %to 12;
						rifq&yr..outpatient_revenue_&mo. (keep=bene_id clm_thru_dt rev_cntr clm_id)
					%end; 
				%end;
			;
			by bene_id clm_id;
			if rev_cntr in('0450','0451','0452','0456','0459') then er=1;
			if er=1;
			format source $15.;
			source='outpatient';
		run;

	%end;

	* Setting all together;
	data &tempwork..er_visits_2017_2020;
		set &tempwork..er_ip&byear.-&tempwork..er_ip&eyear.
			&tempwork..er_op&byear.-&tempwork..er_op&eyear.;
		by bene_id clm_id;
	run;

%mend;

%phys(&minyear.,&maxyear.);

* Checking how many claims occur on the same day;
proc sort data=&tempwork..er_visits_2017_2020 out=er_s_dt nodupkey; by bene_id clm_thru_dt clm_id; run;

data phys_dtdupcheck;
	set er_s_dt;
	by bene_id clm_thru_dt clm_id;
	if not(first.clm_thru_dt and last.clm_thru_dt);
run;

* Checking how many claims span multiple days;
proc sort data=&tempwork..er_visits_2017_2020 out=er_s_clm nodupkey; by bene_id clm_id clm_thru_dt; run;

data phys_clmdupcheck;
	set er_s_clm;
	by bene_id clm_id clm_thru_dt;
	if not(first.clm_id and last.clm_id);
run;




