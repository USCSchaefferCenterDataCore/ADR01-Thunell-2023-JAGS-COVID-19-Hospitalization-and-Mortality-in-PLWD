/*****************************************************************************/
title1 'LTC';

* Author: PF;
* Purpose: Stack all LTC codes together and merge with SNF file separate between SNF and LTC stays;
* Uses: ltc_prcdr_&year., pdeltc&year., ltc_pos_carline&year.;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*****************************************************************************/

%let minyear=2006;
%let maxyear=2020;

%macro snf(byear,eyear);
%do year=&byear. %to &eyear.;

%if &year<=2019 %then %do;
data &tempwork..ltc_all&year.;
	set &tempwork..ltc_prcdr_&year. (rename=prcdr_dt=date keep=bene_id prcdr_dt ltc_prcdr1-ltc_prcdr20)
		&tempwork..pdeltc&year. (rename=srvc_dt=date where=(pde_ltc=1))
		&tempwork..ltc_pos_carline_&year. (rename=clm_thru_dt=date);
run;
%end;
%if &year>2019 %then %do;
data &tempwork..ltc_all&year.;
	set &tempwork..ltc_prcdr_&year. (rename=prcdr_dt=date keep=bene_id prcdr_dt ltc_prcdr1-ltc_prcdr20)
		&tempwork..ltc_pos_carline_&year. (rename=clm_thru_dt=date);
run;
%end;

data &tempwork..snf&year.;
	set
		%if &year<&demogvq. %then %do;
			%do mo=1 %to 9;
			rif&year..snf_claims_0&mo. (keep=bene_id clm_admsn_dt clm_thru_dt clm_from_dt)
			%end;
			%do mo=10 %to 12;
			rif&year..snf_claims_&mo. (keep=bene_id clm_admsn_dt clm_thru_dt clm_from_dt)
			%end;
		%end;
		%if &year>=&demogvq. %then %do;
			%do mo=1 %to 9;
			rifq&year..snf_claims_0&mo. (keep=bene_id clm_admsn_dt clm_thru_dt clm_from_dt)
			%do mo=10 %to 12;
			rifq&year..snf_claims_&mo. (keep=bene_id clm_admsn_dt clm_thru_dt clm_from_dt)
			%end;
		%end;
	;
	by bene_id;
run;

proc sql;
	create table &tempwork..ltc_all&year. as
	select x.*, y.*, (y.clm_admsn_dt ne .) as insnf
	from &tempwork..ltc_all&year. as x left join &tempwork..snf&year. as y
	on x.bene_id=y.bene_id and y.clm_admsn_dt<=x.date<=y.clm_thru_dt
	order by x.bene_id, x.date;
quit;
%end;
%mend;

%snf(&minyear.,&maxyear.);

/* LTC Bene */
%macro ltcbene;
%do yr=&minyear. %to &maxyear.;
data &tempwork..ltc&yr.;
	set &tempwork..ltc_all&yr.;
	if insnf=0;
	ptd=0;
	pos=0;
	prcdr=0;
	if pde_id ne . then ptd=1;
	if line_place_of_srvc_cd ne . then pos=1;
	if ltc_prcdr1 ne . then prcdr=1;
run;

proc means data=&tempwork..ltc&yr. noprint nway;
	class bene_id;
	output out=base.ltc&yr._bene (drop=_type_ _freq_) max(ptd pos prcdr)=ptd&yr. pos&yr. prcdr&yr.;
run;
%end;
%mend;

%ltcbene;


