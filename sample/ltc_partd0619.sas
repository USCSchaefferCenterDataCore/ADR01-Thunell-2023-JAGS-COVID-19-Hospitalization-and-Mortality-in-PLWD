/*********************************************************************************************/
title1 'LTD';

* Author: PF;
* Purpose: Identify LTC pharmacy dispensers;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
%let minyear=2006;
%let maxyear=2019;

%macro pharm(byear,eyear);
%do year=&byear %to &eyear;
	proc sql;
		%do mo=1 %to 9;
			create table &tempwork..pharm&year._&mo. as
			select x.bene_id, x.pde_id, x.srvc_dt, x.ncpdp_id, y.primary_dispenser_type,
			y.secondary_dispenser_type, y.tertiary_dispenser_type
			from pde&year..pde_encrypt_link_&year._0&mo. as x inner join pdch&year..pharm_char_&year._extract as y
			on x.ncpdp_id=y.ncpdp_id;
		%end;
		%do mo=10 %to 12;
			create table &tempwork..pharm&year._&mo. as
			select x.bene_id, x.pde_id, x.srvc_dt, x.ncpdp_id, y.primary_dispenser_type,
			y.secondary_dispenser_type, y.tertiary_dispenser_type
			from pde&year..pde_encrypt_link_&year._&mo. as x inner join pdch&year..pharm_char_&year._extract as y
			on x.ncpdp_id=y.ncpdp_id;
		%end;
	quit;

	data &tempwork..pdeltc&year.;
		set &tempwork..pharm&year._1-&tempwork..pharm&year._12;
		pde_ltc=0;
		if primary_dispenser_type="04" or secondary_dispenser_type="04" or tertiary_dispenser_type="04" then pde_ltc=1;
	run;
%end;

		
%mend;

%pharm(&minyear,&maxyear);


		
