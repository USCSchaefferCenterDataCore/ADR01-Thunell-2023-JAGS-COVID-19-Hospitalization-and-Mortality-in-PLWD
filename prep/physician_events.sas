/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Identify Outpatient stays in 2017-2020 using cost and utliziation file definition
	- PHYS claims are defined as those with a line BETOS code (BETOS_CD) where the first 
	  three digits =M1A or M1B;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

* Identifying Carrier line and DME files with betos_cd 'M1A' or 'M1B';

%let minyear=2017;
%let maxyear=2020;

options obs=max;
%macro phys(byear,eyear);
	%do yr=&byear. %to &eyear.;

		data &tempwork..carrier_phys&yr.;
			set 
				%if &yr.<=&demogv. %then %do;
					%do mo=1 %to 9;
						rif&yr..bcarrier_line_0&mo. (keep=bene_id clm_thru_dt betos_cd clm_id)
					%end;
					%do mo=10 %to 12;
						rif&yr..bcarrier_line_&mo. (keep=bene_id clm_thru_dt betos_cd clm_id)
					%end;
				%end;
				%if &yr.>&demogv. %then %do;
						%do mo=1 %to 9;
						rifq&yr..bcarrier_line_0&mo. (keep=bene_id clm_thru_dt betos_cd clm_id)
					%end;
					%do mo=10 %to 12;
						rifq&yr..bcarrier_line_&mo. (keep=bene_id clm_thru_dt betos_cd clm_id)
					%end; 
				%end;
			;
			by bene_id clm_id;
			if betos_cd in('M1A','M1B') then phys_visit=1;
			if phys_visit=1;
			source='carrier';
		run;

		data &tempwork..dme_phys&yr.;
			set 
				%if &yr.<=&demogv. %then %do;
					%do mo=1 %to 9;
						rif&yr..dme_line_0&mo. (keep=bene_id clm_thru_dt betos_cd clm_id)
					%end;
					%do mo=10 %to 12;
						rif&yr..dme_line_&mo. (keep=bene_id clm_thru_dt betos_cd clm_id)
					%end;
				%end;
				%if &yr.>&demogv. %then %do;
					%do mo=1 %to 9;
						rifq&yr..dme_line_0&mo. (keep=bene_id clm_thru_dt betos_cd clm_id)
					%end;
					%do mo=10 %to 12;
						rifq&yr..dme_line_&mo. (keep=bene_id clm_thru_dt betos_cd clm_id)
					%end; 
				%end;
			;
			by bene_id clm_id;
			if betos_cd in('M1A','M1B') then phys_visit=1;
			if phys_visit=1;
			source='dme   ';
		run;

	%end;

	* Setting all together;
	data covid.phys_events_2017_2020;
		set &tempwork..carrier_phys&byear.-&tempwork..carrier_phys&eyear.
			&tempwork..dme_phys&byear.-&tempwork..dme_phys&eyear.;
		by bene_id clm_id;
	run;

%mend;

%phys(&minyear.,&maxyear.);

* Checking how many claims occur on the same day;
proc sort data=covid.phys_events_2017_2020 out=phys_s_dt nodupkey; by bene_id clm_thru_dt clm_id; run;

data phys_dtdupcheck;
	set phys_s_dt;
	by bene_id clm_thru_dt clm_id;
	if not(first.clm_thru_dt and last.clm_thru_dt);
run;

* Checking how many claims span multiple days;
proc sort data=covid.phys_events_2017_2020 out=phys_s_clm nodupkey; by bene_id clm_id clm_thru_dt; run;

data phys_clmdupcheck;
	set phys_s_clm;
	by bene_id clm_id clm_thru_dt;
	if not(first.clm_id and last.clm_id);
run;




