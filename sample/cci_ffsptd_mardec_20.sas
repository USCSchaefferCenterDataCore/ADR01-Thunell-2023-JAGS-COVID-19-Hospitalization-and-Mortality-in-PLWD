/*********************************************************************************************/
TITLE1 'CCI';

* AUTHOR: Patricia Ferido;
* PURPOSE: Running on CCI on FFS part D claims and only looking from March to September;

options compress=yes nocenter ls=160 ps=200 errors=5  errorcheck=strict mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2020;
%let maxyear=2020;

options obs=max;

data &tempwork..ffsptd_samp;
	set base.samp_1yrffsptd_0621 (in=a keep=bene_id anysamp where=(anysamp=1));
	by bene_id;
run;

%macro pulldx(ctyp,maxdx);

* Limiting to people in either the 3 yr FFS Part D Sample or the 1 yr FFS Part D Sample;
%do year=&minyear. %to &maxyear.;
	%do mo=3 %to 12;
	data &tempwork..&ctyp._&year._mo&mo.;
		merge
		%if &year.<2021 %then %do;
			%if &mo<10 %then rif&year..&ctyp._claims_0&mo. (in=a keep=bene_id icd_dgns_cd: clm_thru_dt);
			%if &mo>=10 %then rif&year..&ctyp._claims_&mo. (in=a keep=bene_id icd_dgns_cd: clm_thru_dt);
		%end;
		%if &year=2021 %then %do;
			%if &mo<10 %then rifq&year..&ctyp._claims_0&mo. (in=a keep=bene_id icd_dgns_cd: clm_thru_dt);
			%if &mo>=10 %then rifq&year..&ctyp._claims_&mo. (in=a keep=bene_id icd_dgns_cd: clm_thru_dt);
		%end;
		&tempwork..ffsptd_samp (in=b);*merge;
		by bene_id;
		if a and b;
	run;
	%end;

	data &tempwork..&ctyp._cci_ffsptd&year.;
		set &tempwork..&ctyp._&year._mo3-&tempwork..&ctyp._&year._mo12;
		by bene_id;
	run;
%end; 

%mend;

%pulldx(inpatient);
%pulldx(outpatient);
%pulldx(hha);
%pulldx(snf);
%pulldx(bcarrier);

%include "&rootpath./Projects/Programs/base/cci_icd9_10_macro.sas";

%macro cci_yr;
%do year=&minyear. %to &maxyear.;
data &tempwork..cci_clms_ffsptd&year.;
	set &tempwork..inpatient_cci_ffsptd&year.
		&tempwork..outpatient_cci_ffsptd&year.
		&tempwork..hha_cci_ffsptd&year.
		&tempwork..snf_cci_ffsptd&year.
		&tempwork..bcarrier_cci_ffsptd&year.;
	by bene_id;
run;

%_CharlsonICD (DATA    = &tempwork..cci_clms_ffsptd&year.,     /* input data set */
               OUT     = &tempwork..cci_ffsptd&year.,     /* output data set */
               dx      =icd_dgns_cd:,     /* range of diagnosis variables (diag01-diag25) */
               dxtype  =,    /* range of diagnosis type variables 
                                       (diagtype01-diagtype25) */
               type    =off, /** on/off  turn on use of dxtype ***/
               debug   =on ) ;

* Get weighted CCI for the year;
data &tempwork..cci_ffsptd_bene&year.;
   set &tempwork..cci_ffsptd&year. (keep=bene_id cc_grp_1-cc_grp_17);
   by bene_id;
   
   retain ccgrp1 ccgrp2 ccgrp3 ccgrp4 ccgrp5 ccgrp6 ccgrp7 ccgrp8 ccgrp9 
          ccgrp10 ccgrp11 ccgrp12 ccgrp13 ccgrp14 ccgrp15 ccgrp16 ccgrp17;
   
   if first.bene_id then do;
      ccgrp1=0; ccgrp2=0; ccgrp3=0; ccgrp4=0; ccgrp5=0; ccgrp6=0; ccgrp7=0; ccgrp8=0; ccgrp9=0; 
      ccgrp10=0; ccgrp11=0; ccgrp12=0; ccgrp13=0; ccgrp14=0; ccgrp15=0; ccgrp16=0; ccgrp17=0;
   end;

*** these are the original comorbidity variables generated from each hospital separation or physician claim;
array hsp{17} cc_grp_1  cc_grp_2  cc_grp_3  cc_grp_4  cc_grp_5  cc_grp_6  cc_grp_7  cc_grp_8  cc_grp_9 
                 cc_grp_10 cc_grp_11 cc_grp_12 cc_grp_13 cc_grp_14 cc_grp_15 cc_grp_16 cc_grp_17;
                                                   
*** these are the summary comorbidity values over all claims;   
array tot{17} ccgrp1 ccgrp2 ccgrp3 ccgrp4 ccgrp5 ccgrp6 ccgrp7 ccgrp8 ccgrp9 
                 ccgrp10 ccgrp11 ccgrp12 ccgrp13 ccgrp14 ccgrp15 ccgrp16 ccgrp17;
   
   do i = 1 to 17;
      if hsp{i} = 1 then tot{i} = 1;
   end;
   
   if last.bene_id then do;
      totalcc = sum(of ccgrp1-ccgrp17);
              
              *** use Charlson weights to calculate a weighted score;
              wgtcc = sum(of ccgrp1-ccgrp10) + ccgrp11*2 + ccgrp12*2 + ccgrp13*2 + ccgrp14*2 +
                      ccgrp15*3 + ccgrp16*6 + ccgrp17*6;        

              output;
   end;
   
   label ccgrp1 = 'Charlson Comorbidity Group 1: Myocardial Infarction'
         ccgrp2 = 'Charlson Comorbidity Group 2: Congestive Heart Failure'
                        ccgrp3 = 'Charlson Comorbidity Group 3: Peripheral Vascular Disease'
                        ccgrp4 = 'Charlson Comorbidity Group 4: Cerebrovascular Disease'
                        ccgrp5 = 'Charlson Comorbidity Group 5: Dementia'
                        ccgrp6 = 'Charlson Comorbidity Group 6: Chronic Pulmonary Disease'
                        ccgrp7 = 'Charlson Comorbidity Group 7: Connective Tissue Disease-Rheumatic Disease'
                        ccgrp8 = 'Charlson Comorbidity Group 8: Peptic Ulcer Disease'
                        ccgrp9 = 'Charlson Comorbidity Group 9: Mild Liver Disease' 
                        ccgrp10 = 'Charlson Comorbidity Group 10: Diabetes without complications' 
                        ccgrp11 = 'Charlson Comorbidity Group 11: Diabetes with complications'
                        ccgrp12 = 'Charlson Comorbidity Group 12: Paraplegia and Hemiplegia' 
                        ccgrp13 = 'Charlson Comorbidity Group 13: Renal Disease' 
                        ccgrp14 = 'Charlson Comorbidity Group 14: Cancer' 
                        ccgrp15 = 'Charlson Comorbidity Group 15: Moderate or Severe Liver Disease' 
                        ccgrp16 = 'Charlson Comorbidity Group 16: Metastatic Carcinoma' 
                        ccgrp17 = 'Charlson Comorbidity Group 17: HIV/AIDS'
                        totalcc = 'Sum of 17 Charlson Comorbidity Groups'
                        wgtcc = 'Weighted Sum of 17 Charlson Comorbidity Groups'
                        ccwgtgrp = 'Category of Weighted Sum of 17 Charlson Comorbidity Groups';
   
   keep bene_id totalcc wgtcc ccgrp1 ccgrp2 ccgrp3 ccgrp4 ccgrp5 ccgrp6 ccgrp7 
        ccgrp8 ccgrp9 ccgrp10 ccgrp11 ccgrp12 ccgrp13 ccgrp14 ccgrp15 ccgrp16 ccgrp17;        
run;   
%end;

* Create a wide file of cci with cci for each year;
data base.cci_ffsptd_bene20_mardec;
	merge %do year=&minyear %to &maxyear;
	&tempwork..cci_ffsptd_bene&year. (keep=bene_id totalcc wgtcc rename=(totalcc=totalcc&year. wgtcc=wgtcc&year.))
	%end;;
	by bene_id;
run;

%mend;

%cci_yr;





