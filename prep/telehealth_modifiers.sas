/*********************************************************************************************/
title1 'COVID';

* Author: PF;
* Purpose: Read in telehealth and pull procedure codes;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
* Pull procedure codes;
%let minyear=2017;
%let maxyear=2020;

%let max_prcdr=15;

* Revenue files;
%macro revenue(ctyp,proctyp,byear,eyear,procdt=,keepv=);
%do year=&byear %to &eyear;
data &tempwork..telemod_&ctyp._&year._;
		set 
			%if &year<=2019 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._&proctyp._0&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd hcpcs_1st_mdfr_cd hcpcs_2nd_mdfr_cd
						clm_id &keepv)
					%end;
					%if &mo>=10 %then %do;
						rif&year..&ctyp._&proctyp._&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd hcpcs_1st_mdfr_cd hcpcs_2nd_mdfr_cd
						clm_id &keepv) 
					%end;
				%end;
			%end;
			%else %if &year=2020 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._&proctyp._0&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd hcpcs_1st_mdfr_cd hcpcs_2nd_mdfr_cd
						clm_id &keepv)
					%end;
					%if &mo>=10 %then %do;
						rifq&year..&ctyp._&proctyp._&mo (keep=bene_id clm_thru_dt &procdt hcpcs_cd hcpcs_1st_mdfr_cd hcpcs_2nd_mdfr_cd
						clm_id &keepv) 
					%end;
				%end;
			%end;
				;
		by bene_id clm_id;

		format prcdr_dt mmddyy10.;
		
		year=year(clm_thru_dt);
		
		array hcpcs_mdfr [*] hcpcs_1st_mdfr_cd hcpcs_2nd_mdfr_cd hcpcs_3rd_mdfr_cd;

		hcpcs_mdfr95=0;
		hcpcs_mdfrGT=0;
		pos02=0;

		do i=1 to 3;
			if hcpcs_mdfr[i]="95" then hcpcs_mdfr95=1;
			if hcpcs_mdfr[i]="GT" then hcpcs_mdfrGT=1;
		end;

		%if "&ctyp"="bcarrier" %then if line_place_of_srvc_cd="02" then pos02=1;;
			
		if max(hcpcs_mdfr95,hcpcs_mdfrGT,pos02)=0 then delete;

		prcdr_dt=clm_thru_dt;

		length clm_typ $1;
    
	    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
	    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
	    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
	    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
	    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
	    else clm_typ="X";  

run;

proc sort data=&tempwork..telemod_&ctyp._&year._ out=&tempwork..telemod_r&ctyp._&year.; 
	by bene_id year prcdr_dt clm_typ clm_id &procdt.; 
run;

%end;
%mend;

%macro append(ctyp,revenueonly=Y);
	
data &tempwork..telemod_&ctyp._&minyear._&maxyear;
		set 
	%do year=&minyear %to &maxyear;
		&tempwork..telemod_r&ctyp._&year
	%end;;
	by bene_id year prcdr_dt clm_typ clm_id;
	if bene_id=. then delete;
run;

%mend;

%revenue(inpatient,revenue,&minyear,&maxyear,keepv=hcpcs_3rd_mdfr_cd);
%append(inpatient,revenueonly=N)

%revenue(outpatient,revenue,&minyear,&maxyear,keepv=hcpcs_3rd_mdfr_cd);
%append(outpatient,revenueonly=N)

%revenue(bcarrier,line,&minyear,&maxyear,procdt=line_1st_expns_dt,keepv=line_place_of_srvc_cd);
%append(bcarrier,revenueonly=Y);

%revenue(hha,revenue,&minyear,&maxyear,keepv=hcpcs_3rd_mdfr_cd);
%append(hha,revenueonly=Y);

%revenue(snf,revenue,&minyear,&maxyear,keepv=hcpcs_3rd_mdfr_cd);
%append(snf,revenueonly=Y);

data &tempwork..telemod_2017_2020;
	set &tempwork..telemod_bcarrier_2017_2020 &tempwork..telemod_hha_2017_2020 &tempwork..telemod_inpatient_2017_2020
	&tempwork..telemod_outpatient_2017_2020 &tempwork..telemod_snf_2017_2020;
	by bene_id year prcdr_dt clm_typ;
	month=month(prcdr_dt);
run;

proc means data=&tempwork..telemod_2017_2020 noprint nway;
	class bene_id year month;
	var	hcpcs_mdfr95 hcpcs_mdfrGT pos02;
	output out=&tempwork..telemod_benemonth sum()= max()= / autoname;
run;

proc means data=&tempwork..telemod_2017_2020 noprint nway;
	class year month;
	var	hcpcs_mdfr95 hcpcs_mdfrGT pos02;
	output out=&tempwork..telemod_benemonth sum()= mean()= / autoname;
run;

* Limit telemod to carrier claims only;
proc means data=&tempwork..telemod_2017_2020 noprint nway;
	where find(clm_typ,'5');
	class bene_id year month;
	var	hcpcs_mdfr95 hcpcs_mdfrGT pos02;
	output out=&tempwork..telemod_benemonth_carrier sum()= max()= / autoname;
run;






