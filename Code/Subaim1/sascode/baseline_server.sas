/* M D'Arcy Nov 4, 2014								*/
/* this code takes in cohort and adds baseline covariates to the cohort: 	*/
/* will output another file  	      	       		     	 		  */	    
/* get baseline covariates for antidepressant users:   	       	  	   	 */
/* 	   1) age, race, sex, geographic location, SES?				 */	
/* 	   2) depression dx code	          				*/
/* 	   3) anxiety codes 							*/
/*  	   4) diabetes code							*/
/*	   5) smoking (copd)							*/
/*	   6) alcoholism							*/
/*	   7) Need: HRT rx use, previous cancer dx, high risk status (previous adenoma/family history)		*/
/*	   8) screening bahavior	 	    	      	     		*/
/*	   9) inflammatory GI (chrohn's IBD)					*/
/* SSRI COHORT W/2 fills is out.ssri_2rx (create in SSRICohort.sas)		*/
/* AD COHORT W/2 fills is out.ad_2rx (create in Aim1Cohort.sas )	  	*/
/* AD COHORT with THZ comparator W/2 fills is out.adthz_2rx (create in Aim1ThzCohort.sas)		*/
/* 
/*
%let server=localhost 1234;
options comamid=tcp remote=server;
signon username=_prompt_;
rsubmit;
*/
options sasautos=(SASAUTOS "/mnt/files/projects/medicare/AntiDepCRC/programs/macros");
*options symbolgen;
%setup(1pct, baseline_server, Y)
libname rxcovar "&RefPath./rxcovar";
libname hcuse "&Refpath./hcUse";

/* icd-9 = code  */

/*demographic information */

/* Demographics:  age, sex, race/ethnicity, available measures of socioeconomic status
   sex and race are already in the cohort file
 */
%macro demog(startyr, endyr,cohort);
     proc sql;
          create table demog&cohort as
          %DO yr=&startyr %TO &endyr;
               select a.id, a.bene_id, a.indexdate,b.bene_dob, 
                    month(a.indexdate-30) as month label='Month of Drug Initiation',
                    /*floor(yrdif(b.bene_dob, a.indexdate-30)) as age label='Age on Index Date',*/ 
                    b.state_cd, b.cnty_cd, b.ms_cd  
               from out.&cohort(where=(year(indexdate-30)=&yr)) as a left join raw.bsf&yr as b on a.bene_id = b.bene_id
              %IF &yr < &endyr %THEN union all corresponding;
          %END;
     ;quit;
%mend;


/* MD 1/2015 ssri_2rx and ad_2rx are fine (for now and do not need to be regenerated )*/
%demog(2007, 2012, ssri_2rx)
%demog(2007, 2012,ad_2rx)

/* MD 1/2015; need to get baseline characteristics for AD/Thiazide cohort */
/*%demog(2007,2012,adthz_2rx)*/

/* MD 2/2015; baseline characteristics for AD & THZ ONLY cohort */
/* %demog(2007,2012,thzonly_2rx)*/
/*CRC risk factors: smoking, alcoholism, depression, anxiety, diabetes
 inflammatory gi conditions,*/ 

/* Comorbidities */

%macro comorb_setup();
    %GLOBAL Ncomorb; 
     /*%DO j=1 %TO 100; %GLOBAL covar&j; %END;*/ 
     proc sql;
      select distinct memname from sashelp.vmember where upcase(libname)='COVREF' and memtype='DATA'; /*needed to initialize sqlobs */

      %let Ncomorb = &sqlobs;
      %DO j=1 %TO &Ncomorb; %GLOBAL covar&j; %END; 

      select unique memname into :covar1 - :covar&sqlobs from sashelp.vmember where upcase(libname)='COVREF' and memtype='DATA';
       
  quit;       
%mend;
%comorb_setup();

%macro comorb(cohort);
       %put numfiles: &Ncomorb;
       %put firstFile: &covar1;
       %do i=1 %to &Ncomorb;
       	   %put Data&i: &&covar&i;
       %end;

* ulcerative colitis codes ; 
%let uc_icd9dx = ('556.5','556.6','556.8','556.9'); 
%let uc_prochcpcs = ('G8758','G8899'); 
%let uc_icd10dx = ('K51.8','K51.80','K51.81','K51.811','K51.812','K51.813','K51.814','K51.818','K51.819','K51.9','K51.90','K51.91','K51.911','K51.912','K51.913','K51.914','K51.918','K51.919'); 

* obesity codes; 
%let obesity_icd9dx = ('278','278.0','278.00','278.01'); 
%let obesity_icd9ecode = ('V77','V77.8'); 
%let obesity_icd10dx = ('E66','E66.0','E66.01','E66.09','E66.8','E66.9'); 
/* 5/2015.  added code to figure out what is driving the previous cancer-crc association.  it is probably a crc or liver met code  */
     proc sql;
      create table baseline&cohort as 
	      select distinct a.id,a.bene_id,a.indexdate,
		       max(b.dx in (select distinct compress(codestr,'.') from covref.alcoholism)) as alcoholism,
		       max(b.dx in (select distinct compress(codestr,'.') from covref.anxiety)) as anxiety,
		       max(b.dx in (select distinct compress(code,'.') from covref.copd)) as copd,
		       max(b.dx in (select distinct compress(codestr,'.') from covref.depression)) as depression,
		       max(b.dx in (select distinct compress(code,'.') from covref.gi)) as gi,
		       max(b.dx in ('5565','5566','5568','5569')) as ucicd9,
		       max(b.dx in ('K518','K5180','K5181','K51811','K51812','K51813','K51814','K51818','K51819','K519','K5190','K5191','K51911','K51912','K51913','K51914','K51918','K51919')) as ucicd10, 
		       max(b.dx in ('278','2780','27800','27801')) as obesityicd9,
		       max(b.dx in ('E66','E660','E6601','E6609','E668','E669')) as obesityicd10,
          	       max( substr(b.dx,1,3)='250' ) as bl_dm label="BL Diabetes Diagnosis",
               	       max( substr(b.dx,1,3)='250' and substr(b.dx,5,1)='1') as bl_d1m label='Type 1 Diabetes',
		       max( dx in select distinct compress(icd9,'.') from cncrexcl.icd9_dx) as prevCancer_dx label='Cancer Diagnosis',
		       max( substr(b.dx,1,3)='155') as livercancer,
		       max (substr(b.dx,1,3)='197') as icd197met,
		       max (substr(b.dx,1,3)='196') as icd196met,
		       max (substr(b.dx,1,3)='198') as icd198met,
		       max (dx in('1975')) as colonmet,
		       max (dx in('1977')) as livermet,
		       max(b.dx in (select distinct compress(codestr,'.') from covref.diabetes)) as diabetes 
          from out.&cohort as a inner join der.alldx as b
              on a.bene_id = b.bene_id and a.indexdate-360<=b.from_dt<=a.indexdate-30 /* need baseline info 360d-30d prior to index date */ 
		group by a.bene_id, a.indexdate
		order by a.id;
     quit;

%mend;

%comorb(ssri_2rx)
%comorb(ad_2rx)
*%comorb(thzonly_2rx);
*%comorb(adthz_2rx);


/* now get hc use (colonscopies and FOBT) */

/* now get RX use (estrogens, HRT, OC use) **/
%macro getmeds();
     %GLOBAL Nrx; %DO j=1 %TO 100; %GLOBAL rx&j; %END; 
     proc sql noprint; 
          select distinct memname
               into :rx1 -:rx100
               from sashelp.vmember
               where upcase(libname) = "RXCOVAR";

          %LET Nrx = &SqlObs.;
     quit;
%mend;
%getmeds()
%macro meds(startyr, endyr,cohort); 
       	   
/* get all AHT drugs that aren't thiazides */
	proc sql;
       	  select unique(GENNME) from coderef.antihpt_ndc as a where a.thiazide ne 1;	   
	
       	  select unique(upcase(GENNME)) 
   	      	 into :DNameAHT1-:DNameAHT&sqlobs
	 from coderef.antihpt_ndc as a where a.thiazide ne 1;
	     	      
      %put numAHTNames=&sqlobs;
     %LET numAHTNames = &sqlobs;

       %do i = 1 %to &sqlobs;
       %put Drug &i: &&DNameAHT&i;
       %end;

/* get all nsaid drug names*/
      proc sql;
       	 select unique(ATC_LABEL) from rxcovar.nsaids;	   
	
       	 select unique(upcase(ATC_LABEL)) 
   	      	into :DName1-:DName&sqlobs
	 from rxcovar.nsaids;

      %put numNames=&sqlobs;
     %LET numNames = &sqlobs;

     proc sql;
          create table rx&cohort as
          select distinct id,
		 	 max(estrogen) as bl_estrogen, 
			 max(nsaid_name) as bl_nsaidname,
			 max(nsaid) as bl_nsaid,  
			 max(bb) as bl_bb,
			 max(aht_name) as bl_aht,    
		 	 max(ocp) as bl_ocp 
          from  (%DO yr=&startYR %TO &endYR;
                     select distinct a.id as id,b.gnn as gnn,
		           case when substr(b.prdsrvid,1,9) in (select ndc from rxcovar.estrogen) 
                              then 1 else 0 end as estrogen,
			  case when substr(b.prdsrvid,1,9) in (select substr(ndc,1,9) from rxcovar.nsaids) 
                              then 1 else 0 end as nsaid,
			  case when substr(b.prdsrvid,1,9) in (select ndc9 from rxcovar.bb_ndc)
                             then 1 else 0 end as bb, 
                  	  case %DO n=1 %TO &numNames;
                              when upcase(gnn) contains "&&DName&n" then 1 
                           %IF &n=&numNames %THEN else 0 end as nsaid_name, ;
                           %END;
                 	  case %DO n=1 %TO &numAHTNames;
                              when upcase(gnn) contains "&&DNameAHT&n" then 1 
                           %IF &n=&numAHTNames %THEN else 0 end as aht_name, ;
                           %END;
                          case when substr(b.prdsrvid,1,9) in (select ndc from rxcovar.ocp) then 1 else 0 end as ocp
                     from demog&cohort as a inner join raw.pde_saf_file&yr as b
                           on a.bene_id = b.bene_id and a.indexdate-360<=b.srvc_dt<=a.indexdate-30
                     group by a.id
                  %IF &yr<&endYR %THEN union all corresponding ;
                %END;
               ) 
	group by id order by id;
     quit;
%mend meds;

%meds(2007, 2012,ssri_2rx)
%meds(2007, 2012,ad_2rx)


/* get the meds associated with CRC for AD and THZ users, allowing for other baseline use
%meds(2007,2012,adthz_2rx) */


/* 2/2015 */
/* get the meds associated with CRC for AD and THZ users,NOT allowing for ANY other AHT use */
*%meds(2007,2012,thzonly_2rx);

/* we only care about hcuse related to CRC (FOBT & colonscopies) */
%macro hcUse(cohort);
     proc sql;
          create table hcuse1&cohort as
          select distinct bene_id, indexdate, strip(bene_id) || strip(put(indexdate,date9.)) as id, test, 
			    count(distinct proc_dt) as bl_numRec
          from (
               select a.bene_id, a.indexdate, 
                    case when b.test ne '' then b.test else 'Office Visit' end as test, a.proc_dt 
               from 
                    (select a.bene_id, a.indexdate, b.proc, b.proc_dt 
                      from demog&cohort as a inner join der.allcpt as b
                         on a.bene_id = b.bene_id and a.indexdate-360<=b.proc_dt<=a.indexdate
                      where b.proc in (select code from hcuse.hcusecodes where type in ('CPT' 'HCPCS'))
                         or '99201'<=proc<='99205' or '99211'<=proc<='99215'
                    ) as a
                    left join hcuse.hcusecodes(where=(type in ('CPT' 'HCPCS'))) as b
                         on a.proc = b.code

               union all corresponding

               select a.bene_id, a.indexdate, b.test, a.proc_dt from 
                    (select a.bene_id, a.indexdate, b.proc, b.proc_dt 
                      from demog&cohort as a inner join der.allicd9_proc as b
                         on a.bene_id = b.bene_id and a.indexdate-360<=b.proc_dt<=a.indexdate-30
                      where b.proc in (select code from hcuse.hcusecodes where type = 'ICD9')
                    ) as a
                    left join hcuse.hcusecodes(where=(type = 'ICD9')) as b
                on a.proc = b.code
               )
           group by bene_id, indexdate, test
           order by id, test;
     quit;

     proc transpose data=hcuse1&cohort out=hcuse&cohort(drop=_NAME_) prefix=bl_num_ ;
          by id;
          var bl_numRec;
          id test;
     run;
%mend;
 
%hcUse(ssri_2rx)
%hcUse(ad_2rx)
*%hcUse(thzonly_2rx);
*%hcUse(adthz_2rx);


/*
%macro gethcuse();
     %GLOBAL Nhcuse; %DO j=1 %TO 100; %GLOBAL hcuse&j; %END; 
     proc sql noprint;
          select distinct name into :hcuse1-:hcuse100 from sashelp.vcolumn where upcase(libname) = "WORK" 
				and upcase(memname) = "HCUSE" and upcase(name) ne 'ID';
          %LET Nhcuse = &SqlObs;
     quit;
%mend;
%gethcuse()
*/

/* MERGE ALL COVARIATES BACK TOGETHER */
%macro merge(cohort);
proc sort data=out.&cohort; by id; run;
proc sort data=demog&cohort; by id; run;
proc sort data=baseline&cohort; by id; run;
proc sort data=rx&cohort; by id; run;
proc sort data=hcuse&cohort; by id; run;
data out.cov&cohort;
     merge out.&cohort demog&cohort baseline&cohort rx&cohort hcuse&cohort;
     by id;
     
     array vars{*} _NUMERIC_;
/*
     array vars[*] %DO i=1 %TO &Ncomorb; &&covar&i; %END;
*/
     do i=1 to dim(vars); 
     	if vars(i)=. then vars(i)=0; 
     end;
     drop i;
run;
%mend;

%merge(ssri_2rx)
%merge(ad_2rx)
*%merge(adthz_2rx);
*%merge(thzonly_2rx);
*endrsubmit;
