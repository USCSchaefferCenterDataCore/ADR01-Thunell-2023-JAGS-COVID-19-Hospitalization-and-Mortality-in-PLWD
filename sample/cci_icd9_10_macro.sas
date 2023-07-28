/*  This program reads through the diagnosis codes of patient abstract records in a hospital
    file and identifies whether the record belongs to one or more 17 different Charlson
    Comorbidity Index (CCI) groups.  The groups are identified by using the ICD-10 diagnosis
    codes listed in Quan et al., "Coding Algorithms for Defining Comorbidities
    in ICD-9-CM and ICD-10 Administrative Data", Medical Care:43(11), Nov. 2005 p1130-1139.

    The original SAS code for this program was developed by Hude Quan's group at the U of C in
    Calgary, and modified to work with MCHP data. This code has not been validated by MCHP.

    All 25 diagnosis and diagnosis type fields are reviewed.

    Diagnosis codes are checked using the IN: statement at 3 to 6 character levels. Diagnoses are
    excluded if the diagnosis type (DXTYPE##) = '2' (Post-Admit Comorbidity - a condition arising
    post-admission).

    Date:   May 11, 2006
    Author: Ken Turner & Charles Burchill
*/

%macro _CharlsonICD (DATA    =,     /* input data set */
                       OUT     =,     /* output data set */
                       dx      =diag01-diag25,     /* range of diagnosis variables (diag01-diag25) */
                       dxtype  =diagtype01-diagtype25,    /* range of diagnosis type variables 
                                       (diagtype01-diagtype25) */
                       type    =off, /** on/off  turn on use of dxtype ***/
                       debug   =off ) ;
	%put Charlson Comorbidity Index Macro - ICD10 Codes ;
	%put Manitoba Centre for Health Policy, Based on Code from Hude Quan University of Calgary ;
	%put Quan et al., Coding Algorithms for Defining Comorbidities ;
	%put     in ICD-9-CM and ICD-10 Administrative Data, Medical Care:43(11), Nov. 2005 p1130-1139 ;
	%put Version 1.0e February 23, 2007 ;


	%let debug = %lowcase(&debug) ;
	%let type = %lowcase(&type) ;

	%* put default options into &opts variable ;
  %let opts=%sysfunc(getoption(mprint,keyword))
	  %sysfunc(getoption(notes,keyword)) ;

  %if &debug=1 | &debug=debug %then %do ;
		options mprint notes ;
		%end ;
	%else %do ;
		options nomprint nonotes ;
		%end ;
	
	%* Check if previous data step, or procdure had an error and
	 stop running the rates macro
	This assumes that the previous step is used in the macro.;
 %if %eval(&SYSERR>0) %then %goto out1 ; 
  
  %* Check if input data exists ;
  %if &data= %str() %then %goto out2 ;
  
  %* if the output data set is not defined then define it as the input ;
  %if &out=  %then %let out=&data ;
  
  %if %index(&data,.) %then %do;
     %let libname=%scan(&data,1);
	 %let data=%scan(&data,2);
	 %end;
 %else %do ;
	 %let libname=work ;
	 %let data=&data ;
	 %end ;
 
 %if %sysfunc(exist(&libname..&data)) ^= 1 %then %goto out3 ;	

      data &OUT;
      set &libname..&DATA ;

      /*  set up array for individual CCI group counters */
      array CC_GRP (17) CC_GRP_1 - CC_GRP_17;

      /*  set up array for 25 diagnosis codes within a record  */
      array DX (*) &dx;

      /*  set up array for 25 diagnosis type codes within a record */
	  %if &type=on %then array DXTYPE (*) &dxtype; ;
	  

      /*  initialize all CCI group counters to zero */
      do i = 1 to 17;
         CC_GRP(i) = 0;
      end;

      /*  check each patient record for the diagnosis codes in each CCI group */
      do i = 1 to dim(dx) UNTIL (DX(i)=' ');     /* for each set of diagnoses codes */

        /*  skip diagnosis if diagnosis type = "2" */
		  %if &type=on %then if DXTYPE(i) ^="2" then DO; ;
		  

           /* Myocardial Infarction */
           if DX(i) IN: ('410','412','I21', 'I22','I252') then CC_GRP_1 = 1;
           LABEL CC_GRP_1 = 'Myocardial Infarction';

           /* Congestive Heart Failure */
           if DX(i) IN: ('39891','40201','40211','40291','40401','40403','40411','40413','40491','40493',
                         '4254','4255','4257','4258','4259','428','I43','I50','I099','I110','I130','I132','I255','I420','I425','I426',
                         'I427','I428','I429','P290') then CC_GRP_2 = 1;
           LABEL CC_GRP_2 = 'Congestive Heart Failure';

           /* Periphral Vascular Disease */
           if DX(i) IN: ('0930','4373','440','441','4431','4432','4438','4439','4471','5571','5579','V434',
						 'I70','I71','I731','I738','I739','I771','I790','I792','K551','K558',
                         'K559','Z958','Z959') then CC_GRP_3 = 1;
           LABEL CC_GRP_3 = 'Periphral Vascular Disease';

           /* Cerebrovascular Disease */
           if DX(i) IN: ('36234','430','431','432','433','434','435','436','437','438',
						 'G45','G46','I60','I61','I62','I63','I64','I65','I66','I67','I68',
                         'I69','H340') then CC_GRP_4 = 1;
           LABEL CC_GRP_4 = 'Cerebrovascular Disease';

           /* Dementia */
           if DX(i) IN: ('290','2941','3312','F00','F01','F02','F03','G30','F051','G311')
                         then CC_GRP_5 = 1;
           LABEL CC_GRP_5 = 'Dementia';

           /* Chronic Pulmonary Disease */
           if DX(i) IN: ('4168','4169','490','491','492','493','494','495','496','500','501','502','503',
                         '504','505','5064','5081','5088',
						 'J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63',
                         'J64','J65','J66','J67''I278','I279','J684','J701','J703')
                         then CC_GRP_6 = 1;
           LABEL CC_GRP_6 = 'Chronic Pulmonary Disease';

           /* Connective Tissue Disease-Rheumatic Disease */
           if DX(i) IN: ('4465','7100','7101','7102','7103','7104','7140','7141','7142','7148','725',
						 'M05','M32','M33','M34','M06','M315','M351','M353','M360')
                         then CC_GRP_7 = 1;
           LABEL CC_GRP_7 = 'Connective Tissue Disease-Rheumatic Disease';

           /* Peptic Ulcer Disease */
           if DX(i) IN: ('531','532','533','534','K25','K26','K27','K28') then CC_GRP_8 = 1;
           LABEL CC_GRP_8 = 'Peptic Ulcer Disease';

           /* Mild Liver Disease */
           if DX(i) IN: ('07022','07023','07032','07033','07044','07054','0706','0709','570','571','5733',
                         '5734','5738','5739','V427','B18','K73','K74','K700','K701','K702','K703','K709','K717','K713',
                         'K714','K715','K760','K762','K763','K764','K768','K769','Z944')
                         then CC_GRP_9 = 1;
           LABEL CC_GRP_9 = 'Mild Liver Disease';

           /* Diabetes without complications */
           if DX(i) IN: ('2500','2501','2502','2503','2508','2509','E100','E101','E106','E108','E109','E110','E111','E116','E118','E119',
                         'E120','E121','E126','E128','E129','E130','E131','E136','E138','E139',
                         'E140','E141','E146','E148','E149') then CC_GRP_10 = 1;
           LABEL CC_GRP_10 = 'Diabetes without complications';

           /* Diabetes with complications */
           if DX(i) IN: ('2504','2505','2506','2507','E102','E103','E104','E105','E107','E112','E113','E114','E115','E117',
                         'E122','E123','E124','E125','E127','E132','E133','E134','E135','E137',
                         'E142','E143','E144','E145','E147') then CC_GRP_11 = 1;
           LABEL CC_GRP_11 = 'Diabetes with complications';

           /* Paraplegia and Hemiplegia */
           if DX(i) IN: ('3341','342','343','3440','3441','3442','3443','3444','3445','3446','3449',
						 'G81','G82','G041','G114','G801','G802','G830','G831','G832','G833',
                         'G834','G839') then CC_GRP_12 = 1;
           LABEL CC_GRP_12 = 'Paraplegia and Hemiplegia';

           /* Renal Disease */
           if DX(i) IN: ('40301','40311','40391','40402','40403','40412','40413','40492','40493','582',
                         '5830','5831','5832','5834','5836','5837','585','586','5880','V420','V451','V56',
						 'N18','N19','N052','N053','N054','N055','N056','N057','N250','I120',
                         'I131','N032','N033','N034','N035','N036','N037','Z490','Z491','Z492',
                         'Z940','Z992') then CC_GRP_13 = 1;
           LABEL CC_GRP_13 = 'Renal Disease';

           /* Cancer */
           if DX(i) IN: ('140','141','142','143','144','145','146','147','148','149','150','151','152','153',
                         '154','155','156','157','158','159','160','161','162','163','164','165','170','171',
                         '172','174','175','176','179','180','181','182','183','184','185','186','187','188',
                         '189','190','191','192','193','194','195','200','201','202','203','204','205','206',
                         '207','208','2386','C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11',
                         'C12','C13','C14','C15','C16','C17','C18','C19','C20','C21','C22','C23',
                         'C24','C25','C26','C30','C31','C32','C33','C34','C37','C38','C39','C40',
                         'C41','C43','C45','C46','C47','C48','C49','C50','C51','C52','C53','C54',
                         'C55','C56','C57','C58','C60','C61','C62','C63','C64','C65','C66','C67',
                         'C68','C69','C70','C71','C72','C73','C74','C75','C76','C81','C82','C83',
                         'C84','C85','C88','C90','C91','C92','C93','C94','C95','C96','C97')
                         then CC_GRP_14 = 1;
           LABEL CC_GRP_14 = 'Cancer';

           /* Moderate or Severe Liver Disease */
           if DX(i) IN: ('4560','4561','4562','5722','5723','5724','5728',
						 'K704','K711','K721','K729','K765','K766','K767','I850','I859','I864','I982')
                         then CC_GRP_15 = 1;
           LABEL CC_GRP_15 = 'Moderate or Severe Liver Disease';

           /* Metastatic Carcinoma */
           if DX(i) IN: ('196','197','198','199','C77','C78','C79','C80') then CC_GRP_16 = 1;
           LABEL CC_GRP_16 = 'Metastatic Carcinoma';

           /* AIDS/HIV */
           if DX(i) IN: ('042','043','044','B20','B21','B22','B24') then CC_GRP_17 = 1;
           LABEL CC_GRP_17 = 'AIDS/HIV';

        %if &type=on %then end; ;                 /* end if DXTYPE(i) ^= '2' */

      end;                   /* end do i = 1 to 25 */

      /* Count total number of groups for each record */

     TOT_GRP = CC_GRP_1  + CC_GRP_2  + CC_GRP_3  + CC_GRP_4  + CC_GRP_5  + CC_GRP_6  + CC_GRP_7  + CC_GRP_8  +
               CC_GRP_9  + CC_GRP_10 + CC_GRP_11 + CC_GRP_12 + CC_GRP_13 + CC_GRP_14 + CC_GRP_15 + CC_GRP_16 +
               CC_GRP_17;
     LABEL TOT_GRP = 'Total CCI Groups per record';

	run;
    
	options notes ;
	 %put ;
	 %put NOTE: _Charlson Finished &out created ;
     %put ;	

	%goto exit ;
	
    %out1:
		%put ERROR: Prior Step failed with an Error submit a null data step to correct ;
	%goto exit ;

	%out2:
		%put ERROR: Input Data Was Not Defined;
	%goto exit ;

    %out3:
        %put ERROR: Input Data &libname..&data does not exist ;
        %goto exit ;	

    %exit:
	
     %**** Reset the SAS options ;
     options &opts ; 

%mend _CharlsonICD;


/******************* Example Program Code *********************/
/*
data hosp_0405;
   set hsp0405(obs=10000);
run ;

  %_CharlsonICD10 (DATA      =hosp_0405,
                   OUT       =cci_groups,
                   dx        =diag01-diag25,
                   dxtype    =diagtype01-diagtype25,
                   type      =on,
                   debug     =debug);



*******************************
*  Analysis Section of Program *
******************************* ;


PROC FREQ data=CCI_groups;
   TITLE1  "Charlson Comorbidity Groups, Excluding Diagnosis Type of 'Post-Admit Comorbidity'";
   TITLE2  "Using ICD-10 Coding";
   TABLES CC_GRP:  TOT_GRP;
run;
*/
