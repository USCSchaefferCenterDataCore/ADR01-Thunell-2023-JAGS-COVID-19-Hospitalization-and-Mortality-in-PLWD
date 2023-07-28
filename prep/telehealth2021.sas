/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Read in telehealth and pull procedure codes;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

data &tempwork..telehealth_codes;
	infile "&rootpath./Projects/Programs/covid/telehealth_codes.csv" dsd dlm="2c"x missover lrecl=32767 
		firstobs=3;
	informat
		code $6.
		short_desc $30.
		status $100.
		audio_only $3.
		medicare_pay_limit $30.
		evisit best.
		virtual_checkin best.
		telehealth_temp best.
		telehealth_temp_add430 best.
		telehealth_temp_add1014 best.
		telehealth_phe best.
		telehealth_inperson best.
		telehealth_only best.;
	format
		code $6.
		short_desc $30.
		status $100.
		audio_only $3.
		medicare_pay_limit $30.
		evisit best.
		virtual_checkin best.
		telehealth_temp best.
		telehealth_temp_add430 best.
		telehealth_temp_add1014 best.
		telehealth_phe best.
		telehealth_inperson best.
		telehealth_only best.;
	input
		code $
		short_desc $
		status $
		audio_only $
		medicare_pay_limit $
		evisit 
		virtual_checkin 
		telehealth_temp 
		telehealth_temp_add430 
		telehealth_temp_add1014 
		telehealth_phe 
		telehealth_inperson 
		telehealth_only ;
run;

data &tempwork..telehealth_codes;
	set &tempwork..telehealth_codes nobs=obs;
	format telehealth_codes evisit_codes vcheckin_codes telehealth_temp_codes
	telehealth_temp_add430_codes telehealth_temp_add1014_codes telehealth_phe_codes
	telehealth_phe_codes telehealth_inperson_codes telehealth_only_codes $2000.;
	retain telehealth_codes evisit_codes vcheckin_codes telehealth_temp_codes
	telehealth_temp_add430_codes telehealth_temp_add1014_codes telehealth_phe_codes
	telehealth_phe_codes telehealth_inperson_codes telehealth_only_codes;

	telehealth_codes=catx('","',telehealth_codes,code);
	if evisit=1 then evisit_codes=catx('","',evisit_codes,code);
	if virtual_checkin=1 then vcheckin_codes=catx('","',vcheckin_codes,code);
	if telehealth_temp=1 then telehealth_temp_codes=catx('","',telehealth_temp_codes,code);
	if telehealth_temp_add430 then telehealth_temp_add430_codes=catx('","',telehealth_temp_add430_codes,code);
	if telehealth_temp_add1014 then telehealth_temp_add1014_codes=catx('","',telehealth_temp_add1014_codes,code);
	if telehealth_phe then telehealth_phe_codes=catx('","',telehealth_phe_codes,code);
	if telehealth_inperson=1 then telehealth_inperson_codes=catx('","',telehealth_inperson_codes,code);
	if telehealth_only=1 then telehealth_only_codes=catx('","',telehealth_only_codes,code);

	if _n_=obs then do;
		call symput('telehealth_codes',telehealth_codes);
		call symput('evisit',evisit_codes);
		call symput('virtual_checkin',vcheckin_codes);
		call symput('telehealth_temp',telehealth_temp_codes);
		call symput('telehealth_temp_add430',telehealth_temp_add430_codes);
		call symput('telehealth_temp_add1014',telehealth_temp_add1014_codes);
		call symput('telehealth_phe',telehealth_phe_codes);
		call symput('telehealth_inperson',telehealth_inperson_codes);
		call symput('telehealth_only',telehealth_only_codes);
	end;

run;

%put &telehealth_codes;

* Pull procedure codes;
%let minyear=2021;
%let maxyear=2021;

%let rifqmo=9; * last month I have as of 3/29/22;

%let max_prcdr=15;

%macro get(ctyp,byear,eyear,dropv=,keepv=,byvar=);
	%do year=&byear %to &eyear;
		data &tempwork..telehealth_&ctyp._&year;
		
			set 
				
			%if &year<=2020 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rif&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_prcdr_cd: prcdr_dt: &keepv drop=&dropv)
					%end;
				%end;
			%end;
			%else %if &year=2021 %then %do;
				%do mo=1 %to &rifqmo;
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

		length telehealthprcdr1-telehealthprcdr&max_prcdr $ 7;
		format telehealthprcdr_dt1-telehealthprcdr_dt&max_prcdr mmddyy10.;
		
		array prcdr [*] icd_prcdr_cd:;
		array prcdrdt [*] prcdr_dt:;
		array telehealthprcdr [*] telehealthprcdr1-telehealthprcdr&max_prcdr;
		array telehealthprcdr_dt [*] telehealthprcdr_dt1-telehealthprcdr_dt&max_prcdr;
		
		year=year(clm_thru_dt);
	
		prcdrsub=0;
		
		do i=1 to dim(prcdr);
			if prcdr[i] in ("&telehealth_codes") then do; 
				found=0;
				do j=1 to prcdrsub;
					if prcdr[i]=telehealthprcdr[j] then found=j;
				end;
				if found=0 then do;
					prcdrsub=prcdrsub+1;
					if prcdrsub<=&max_prcdr then telehealthprcdr[prcdrsub]=prcdr[i];
				end;
			end;
		end;
		
		if telehealthprcdr1="" then delete;
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
proc sort data=&tempwork..telehealth_&ctyp._&year; by bene_id year prcdr_dt clm_typ; run;
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
data &tempwork..telehealth_&ctyp._&year._;
		set 
			%if &year<=2020 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._&proctyp._0&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id)
					%end;
					%if &mo>=10 %then %do;
						rif&year..&ctyp._&proctyp._&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd clm_id) 
					%end;
				%end;
			%end;
			%else %if &year=2021 %then %do;
				%do mo=1 %to &rifqmo.;
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

		length telehealthprcdr $ 7;
		format prcdr_dt mmddyy10.;
		
		year=year(clm_thru_dt);
		
		if hcpcs_cd in ("&telehealth_codes") then telehealthprcdr=hcpcs_cd;

		if telehealthprcdr="" then delete;
		else do;
			prcdr_dt=clm_thru_dt;
			%if "&procdt" ne "" %then %do;
				telehealthprcdr_dt=&procdt;
				format telehealthprcdr_dt mmddyy10.;
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

proc sort data=&tempwork..telehealth_&ctyp._&year._ out=&tempwork..telehealth_&ctyp._&year._s nodupkey; 
	by bene_id year prcdr_dt clm_typ clm_id telehealthprcdr; 
run;

proc transpose data=&tempwork..telehealth_&ctyp._&year._s out=&tempwork..telehealth_r&ctyp._&year (drop=_name_) prefix=telehealthprcdr; 
	var telehealthprcdr; 
	by bene_id year prcdr_dt clm_typ clm_id; 
run;

%end;
%mend;

%macro append(ctyp,revenueonly=Y);
	
data &tempwork..telehealth_&ctyp._&minyear._&maxyear;
		set 
	%if "&revenueonly"="Y" %then %do year=&minyear %to &maxyear;
		&tempwork..telehealth_r&ctyp._&year
	%end;
	%else %do year=&minyear %to &maxyear;
		&tempwork..telehealth_&ctyp._&year
		&tempwork..telehealth_r&ctyp._&year
	%end; ;
	by bene_id year prcdr_dt clm_typ;
	if bene_id=. then delete;
run;

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

data &tempwork..telehealthprcdr_2021;
	set &tempwork..telehealth_rbcarrier_2021 &tempwork..telehealth_rhha_2021 &tempwork..telehealth_inpatient_2021
	&tempwork..telehealth_outpatient_2021 &tempwork..telehealth_rsnf_2021;
	by bene_id year prcdr_dt clm_typ;
run;

proc contents data=&tempwork..telehealthprcdr_2021 (obs=1) noprint out=&tempwork..telehealth_contents; run;

data &tempwork..telehealth_contents1;
	set &tempwork..telehealth_contents;
	if find(name,'telehealthprcdr') and find(name,'dt')=0;
	count+1;
	call symput('prcdrmax',count);
run;

%put %cmpres(&prcdrmax.);
%let prcdr_max=telehealthprcdr%cmpres(&prcdrmax);
%put &prcdr_max;

data &tempwork..telehealthprcdr_2021;
	set &tempwork..telehealthprcdr_2021 ;

	array prcdr [*] telehealthprcdr1-&prcdr_max.;

	evisit=0;
	virtual_checkin=0;
	telehealth_temp=0;
	telehealth_temp_add430=0;
	telehealth_temp_add1014=0;
	telehealth_phe=0;
	telehealth_inperson=0;
	telehealth_only=0;

	do i=1 to dim(prcdr);
		if prcdr[i] in("&evisit") then evisit=1;
		if prcdr[i] in("&virtual_checkin") then virtual_checkin=1;
		if prcdr[i] in("&telehealth_temp") then telehealth_temp=1;
		if prcdr[i] in("&telehealth_temp_add430") then telehealth_temp_add430=1;
		if prcdr[i] in("&telehealth_temp_add1014") then telehealth_temp_add1014=1;
		if prcdr[i] in("&telehealth_phe") then telehealth_phe=1;
		if prcdr[i] in("&telehealth_inperson") then telehealth_inperson=1;
		if prcdr[i] in("&telehealth_only") then telehealth_only=1;
	end;

	drop i;
run;

/*proc datasets library=&tempwork kill; run; quit;*/

options obs=max;






