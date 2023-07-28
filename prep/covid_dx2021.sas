/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Pull COVID-related DX - ICD codes U07.1 and U07.2;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;

**%include "header.sas";

***** Years/Macro Variables;
%let minyear=2021;
%let maxyear=2021;
%let maxdx=26;

%let rifqmo=9; * last month I have as of 3/29/22;

***** Covid codes;
%let covid_icd10="U071" "U072" "B9729";

%macro getdx(ctyp,byear,eyear,dxv=,dropv=,keepv=,byvar=);
	%do year=&byear %to &eyear;
		data &tempwork..coviddx_&ctyp._&year;
		
			set 
				
			%if &year<&demogvq. %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rif&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			%else %if &year>=&demogvq. %then %do;
				%do mo=1 %to &rifqmo.;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rifq&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			;
			by bene_id &byvar;

	
    length clm_typ $1;

	array icd [*] icd_dgns_cd: &dxv.;

	do i=1 to dim(icd);
		if icd[i] in(&covid_icd10.) then coviddx=1;
	end;

	if coviddx=1;

	year=year(clm_thru_dt);
    
    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
      
run;	

proc sort data=&tempwork..coviddx_&ctyp._&year; by bene_id year clm_thru_dt clm_typ; run;

%end;
%mend getdx;

%getdx(bcarrier,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id,byvar=clm_id);

%getdx(hha,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id);
	
%getdx(inpatient,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id);	
		
%getdx(outpatient,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id);	

%getdx(snf,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id);

%macro stack;
%do year=&minyear %to &maxyear;
data &tempwork..coviddx_&year.;
	set 
		&tempwork..coviddx_bcarrier_&year.
		&tempwork..coviddx_hha_&year.
		&tempwork..coviddx_inpatient_&year.
		&tempwork..coviddx_outpatient_&year.
		&tempwork..coviddx_snf_&year. ;
	by bene_id year clm_thru_dt clm_typ;
run;
%end;
%mend;

%stack;

* Getting first coviddx for each beneficiary;
proc means data=&tempwork..coviddx_2021 noprint nway;
	class bene_id;
	var clm_thru_dt;
	output out=&tempwork..bene_first_coviddx2021 min()=first_coviddx;
run;



options obs=max;

		
		
		
		
		
			

