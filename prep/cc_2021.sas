/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Recreate the chronic conditions file for EOY 2021
	- diabetes - 2yr
	- AMI - 1yr
	- ATF - 1yr
	- stroke - 1yr
	- hypertension - 1yr
	- hyperlipidemia - 1yr


options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

**%include "header.sas";

***** Years/Macro Variables;
%let minyear=2020;
%let maxyear=2021;
%let maxdx=26;
%let rifqmo=9;

options obs=max;

%macro getdx(ctyp,byear,eyear,dxv=,dropv=,keepv=,byvar=);
	%do year=&byear %to &eyear;
		data &tempwork..ccdx_&ctyp._&year;
		
			set 
				
			%if &year<&demogvq %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rif&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			%else %if &year>=&demogvq %then %do;
				%do mo=1 %to &rifqmo;
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

		length ccdx1-ccdx&maxdx $ 5;
		format ccdx_dt mmddyy10.;
		
		* Count how many dementia-related dx are found, separately by ccw list and other list;
		*	Keep thru_dt as dx_date;
		* Keep first 5 dx codes found;
		
		array diag [*] icd_dgns_cd: &dxv;
		array ccdx [*] ccdx1-ccdx&maxdx;
		
		year=year(clm_thru_dt);
		
		ndx=0;
		dxsub=0;
		strkeexcl=0;

		do i=1 to dim(diag);
			if diag[i] in(&strketiaexcl) then strkeexcl=1;
			if (i<=2 and diag[i] in(&ami,&atf)) 
			    or (diag[i] in(&diabetes,&hyperl,&hypert)) 
				or (diag[i] in(&strketia) and strkeexcl ne 1) then do;
				ndx=ndx+1; * Counting total number of cc diagnoses;
				found=0;
				do j=1 to dxsub;
					if diag[i]=ccdx[j] then found=j;
				end;
				if found=0 then do;
					dxsub=dxsub+1;
					if dxsub<=&maxdx then ccdx[dxsub]=diag[i];
				end;
			end;
		end;
		
		if ndx=0 then delete;
		else ccdx_dt=clm_thru_dt;
       
    length clm_typ $1;
    
    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
    
		drop icd_dgns_cd: &dxv clm_thru_dt i j;
		rename dxsub=dx_max;
      
run;	

proc sort data=&tempwork..ccdx_&ctyp._&year; by bene_id year ccdx_dt clm_typ; run;

%end;
%mend getdx;

%macro appenddx(ctyp);
	
data &tempwork..ccdx_&ctyp._&minyear._&maxyear;
		set 
	%do year=&minyear %to &maxyear;
		&tempwork..ccdx_&ctyp._&year
	%end; ;
	by bene_id year ccdx_dt clm_typ;
run;

%mend;

%getdx(bcarrier,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id,byvar=clm_id);
%appenddx(bcarrier);

%getdx(hha,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);		
%appenddx(hha);
		
%getdx(inpatient,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);	
%appenddx(inpatient);
		
%getdx(outpatient,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);	
%appenddx(outpatient);

%getdx(snf,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);
%appenddx(snf);

data &tempwork..cc_dx_&minyear._&maxyear.;
		
		merge &tempwork..ccdx_inpatient_&minyear._&maxyear. 
			  &tempwork..ccdx_outpatient_&minyear._&maxyear. 
			  &tempwork..ccdx_snf_&minyear._&maxyear.  
			  &tempwork..ccdx_hha_&minyear._&maxyear. 
			  &tempwork..ccdx_bcarrier_&minyear._&maxyear. ;
		by bene_id year ccdx_dt clm_typ;

		array cc [*] ccdx1-ccdx26;

		diabetes=0;
		hyperl=0;
		hypert=0;
		ami=0;
		atf=0;
		strketia=0;

		do i=1 to dim(cc);
			if cc[i] in(&diabetes) then diabetes=1;
			if cc[i] in(&hyperl) then hyperl=1;
			if cc[i] in(&hypert) then hypert=1;
			if cc[i] in(&ami) then ami=1;
			if cc[i] in(&atf) then atf=1;
			if cc[i] in(&strketia) then strketia=1;
		end;

		ip=0;
		snf=0;
		op=0;
		hha=0;
		car=0;

		if find(clm_typ,"1") then ip=1;
		if find(clm_typ,"2") then snf=1;
		if find(clm_typ,"3") then op=1;
		if find(clm_typ,"4") then hha=1;
		if find(clm_typ,"5") then car=1;
				
run;

%macro cc(cond,yearcond);
proc means data=&tempwork..cc_dx_&minyear._&maxyear. noprint nway;
	where &cond.=1 and year>=&yearcond.;
	class bene_id ccdx_dt;
	var ip snf op hha car;
	output out=&tempwork..ccdt_&cond. (drop=_type_ _freq_) max(ip snf op hha car)=;
run;

proc means data=&tempwork..ccdt_&cond. noprint nway;
	class bene_id;
	var ccdx_dt ip snf op hha car;
	output out=&tempwork..bene_&cond._ffs (drop=_type_ _freq_) min(ccdx_dt)=first_&cond. sum(ip snf op hha car)=;
run;

data &tempwork..bene_&cond._ffsinc;
	set &tempwork..bene_&cond._ffs;
	%if "&cond."="diabetes" %then if sum(ip,snf,hha)>=1 or sum(op,car)>=2 then ccw_diab=1;;
	%if "&cond."="hyperl" %then if sum(ip,snf,hha)>=1 or sum(op,car)>=2 then ccw_hyperl=1;;
	%if "&cond."="hypert" %then if sum(ip,snf,hha)>=1 or sum(op,car)>=2 then ccw_hypert=1;;
	%if "&cond."="atf" %then if ip>=1 or sum(op,car)>=2 then ccw_atf=1;;
	%if "&cond."="ami" %then if ip>=1 then ccw_ami=1;
	%if "&cond."="strketia" %then if ip>=1 or sum(op,car)>=2 then ccw_strketia=1;;
run;
%mend;

%cc(diabetes,2020);
%cc(hyperl,2021);
%cc(hypert,2021);
%cc(ami,2021);
%cc(atf,2021);
%cc(strketia,2021);


		
		
		
		
		
			
