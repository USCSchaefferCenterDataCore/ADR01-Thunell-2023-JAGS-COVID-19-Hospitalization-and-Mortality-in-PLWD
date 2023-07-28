/*********************************************************************************************/
title1 'LTC';

* Author: PF;
* Purpose: Pull all ltc_prcdr related procedure codes;
* Input: IP, OP, SNF, HHA, HOS;
* Output: ltc_prcdr_&ctyp._year;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2006;
%let maxyear=2020;

%let max_prcdr=15;

%let ltc_prcdr_codes="99301" "99302" "99303" "99304" "99305" "99306" "99307" "99308" "99309" "99310" "99311" "99312" "99313" "99318" "99379" "99380" "G0066" "99321"
"99322" "99323" "99331" "99332" "99333" "99315" "99316" "99199";

options obs=max;
%macro get(ctyp,byear,eyear,dropv=,keepv=,byvar=);
	%do year=&byear %to &eyear;
		data &tempwork..ltc_prcdr_&ctyp._&year;
		
			set 
				
			%if &year<=2019 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rif&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
				%end;
			%end;
			%else %if &year>2019 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rifq&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
				%end;
			%end;
			;
			by bene_id &byvar;

		length ltc_prcdr1-ltc_prcdr&max_prcdr $ 7;
		format ltc_prcdr_dt1-ltc_prcdr_dt&max_prcdr mmddyy10.;
		
		array prcdr [*] icd_prcdr_cd:;
		array prcdrdt [*] prcdr_dt:;
		array ltc_prcdr [*] ltc_prcdr1-ltc_prcdr&max_prcdr;
		array ltc_prcdr_dt [*] ltc_prcdr_dt1-ltc_prcdr_dt&max_prcdr;
		
		year=year(clm_thru_dt);
	
		prcdrsub=0;
		
		do i=1 to dim(prcdr);
			if prcdr[i] in (&ltc_prcdr_codes) then do; 
				found=0;
				do j=1 to prcdrsub;
					if prcdr[i]=ltc_prcdr[j] then found=j;
				end;
				if found=0 then do;
					prcdrsub=prcdrsub+1;
					if prcdrsub<=&max_prcdr then ltc_prcdr[prcdrsub]=prcdr[i];
				end;
			end;
		end;
		
		if ltc_prcdr1="" then delete;
		else prcdr_dt=clm_thru_dt;
       
    length clm_typ $1;
    
    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
    
	drop icd_prcdr_cd: prcdr_dt1-prcdr_dt25 clm_thru_dt i j;
	rename prcdrsub=prcdr_max;
      
run;	
%if %upcase(&ctyp) ne BCARRIER %then %do;
proc sort data=&tempwork..ltc_prcdr_&ctyp._&year; by bene_id year prcdr_dt clm_typ; run;
%end;
%end;
%mend get;

%get(inpatient,&minyear,&maxyear,dropv=,
			 keepv=clm_id);	
		
%get(outpatient,&minyear,&maxyear,dropv=,
			 keepv=clm_id);	

* Revenue files;
%macro revenue(ctyp,proctyp,byear,eyear,procdt=);
%do year=&byear %to &eyear;
data &tempwork..ltc_prcdr_&ctyp._&year._;
		set 
			%if &year<=2019 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._&proctyp._0&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id)
					%end;
					%if &mo>=10 %then %do;
						rif&year..&ctyp._&proctyp._&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id) 
					%end;
				%end;
			%end;
			%else %if &year>2019 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._&proctyp._0&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id)
					%end;
					%if &mo>=10 %then %do;
						rifq&year..&ctyp._&proctyp._&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id) 
					%end;
				%end;
			%end;
				;
		by bene_id clm_id;

		length ltc_prcdr $ 7;
		format prcdr_dt mmddyy10.;
		
		year=year(clm_thru_dt);
		
		if hcpcs_cd in (&ltc_prcdr_codes) then ltc_prcdr=hcpcs_cd;

		if ltc_prcdr="" then delete;
		else do;
			prcdr_dt=clm_thru_dt;
			%if "&procdt" ne "" %then %do;
				ltc_prcdr_dt=&procdt;
				format ltc_prcdr_dt mmddyy10.;
			%end;
		end;

		 length clm_typ $1;
    
	    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
	    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
	    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
	    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
	    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
	    else clm_typ="X";  

run;

proc sort data=&tempwork..ltc_prcdr_&ctyp._&year._; by bene_id year prcdr_dt clm_typ clm_id; run;

proc transpose data=&tempwork..ltc_prcdr_&ctyp._&year._ out=&tempwork..&ctyp._wide_prcdr&year (drop=_name_) prefix=ltc_prcdr; 
	var ltc_prcdr; 
	by bene_id year prcdr_dt clm_typ clm_id; 
run;

%if "&procdt" ne "" %then %do;
proc transpose data=&tempwork..ltc_prcdr_&ctyp._&year._ out=&tempwork..&ctyp._wide_prcdrdt&year (drop=_name_) prefix=ltc_prcdr_dt;
	var &procdt;
	by bene_id year prcdr_dt clm_typ clm_id;
run;

data &tempwork..ltc_prcdr_r&ctyp._&year;
	merge &tempwork..&ctyp._wide_prcdr&year. (in=a) &tempwork..&ctyp._wide_prcdrdt&year. (in=b);
	by bene_id year prcdr_dt clm_typ clm_id;
run;
%end;
%else %do;
data &tempwork..ltc_prcdr_r&ctyp._&year;
	set &tempwork..&ctyp._wide_prcdr&year.;
	by bene_id year prcdr_dt clm_typ clm_id;
run;
%end;	

%end;
%mend;

%macro append(ctyp,revenueonly=Y);
%do year=&minyear. %to &maxyear.;
data &tempwork..ltc_prcdr_&ctyp._&year.;
		set 
	%if "&revenueonly"="Y" %then %do;
		&tempwork..ltc_prcdr_r&ctyp._&year
	%end;
	%else %do;
		&tempwork..ltc_prcdr_&ctyp._&year
		&tempwork..ltc_prcdr_r&ctyp._&year
	%end; ;
	by bene_id year prcdr_dt clm_typ;
	if bene_id=. then delete;
run;
%end;
%mend;

%revenue(inpatient,revenue,&minyear,&maxyear);
%append(inpatient,revenueonly=N)

%revenue(outpatient,revenue,&minyear,&maxyear);
%append(outpatient,revenueonly=N)

%revenue(bcarrier,line,&minyear,&maxyear,procdt=line_1st_expns_dt);
%append(bcarrier,revenueonly=Y);

%revenue(hha,revenue,&minyear,&maxyear);
%append(hha,revenueonly=Y);

%revenue(snf,revenue,&minyear,&maxyear);
%append(snf,revenueonly=Y);

%macro stack;
%do year=&minyear. %to &maxyear.;
data &tempwork..ltc_prcdr_&year.;
	set &tempwork..ltc_prcdr_bcarrier_&year. &tempwork..ltc_prcdr_hha_&year. &tempwork..ltc_prcdr_inpatient_&year.
	&tempwork..ltc_prcdr_outpatient_&year. &tempwork..ltc_prcdr_snf_&year.;
	by bene_id year prcdr_dt clm_typ;
run;
%end;
%mend;

%stack;
options obs=max;




