/* M D'Arcy Sept 25, 2014*/
/* most of this code is modifed from other medicare project code (written by V. Pate)*/
/* this code used to create the cohort of users of */
/* all specific SSRIs on 1 percent sample for years 2007-2012  */	    
/* need to exlude:       	       	      	     	      	  	   	 */
/* 	   1) persons < 65							*/	
/* 	   2) with colon or rectal cancer dx          				*/
/* 	   3)  with < 12 months continuous part AB enrollment 			*/
/*  	   4) people without a second presriptions  				*/
/*	   will need to add a few more things later 				*/

/*
%let server=localhost 1234;
options comamid=tcp remote=server;
signon username=_prompt_;
rsubmit;
*/
options sasautos=(SASAUTOS "/mnt/files/projects/medicare/AntiDepCRC/programs/macros");

%setup(1pct, ssricohort_server, Y)



/* Step 1: Get all RX claims for SSRIs */

%macro getRX(startYr, endYr, drug, nameList);
     %LET numNames = %SYSFUNC(countw(&nameList));
     %LET nameList = %UPCASE(&nameList);
     %PUT &numNames;
     %DO n=1 %TO &numNames; %LET drug&n = %SYSFUNC(STRIP(%SCAN(&nameList, &n))); %END;
     proc sql;
          create table temp.&drug.claims as  select a.*,              
             max('01JAN2007'd, b.abdanystartdt) as startEnroll format=date9. label='Start of ABD Continuous Enrollment',
	     b.abdanyendDT as endPartD format=date9. label='End of ABD Continuous Enrollment' 
          from (%DO yr=&startyr %TO &endyr;
               select bene_id, srvc_dt, DAYSSPLY, gnn,
                    case %DO n=1 %TO &numNames;
                            when upcase(gnn) contains "&&drug&n" then 1 
                         %IF &n=&numNames %THEN else 0 end as nameMatch ;
                    %END;
                from raw.pde_saf_file&yr
                where calculated nameMatch
          %IF &yr<&endyr %THEN union all corresponding;
          %END; ) as a inner join der.enrlper_abdany as b
             on a.bene_id = b.bene_id and b.abdanystartDT <= a.srvc_dt <= b.abdanyendDT;
     quit;
%mend;

%getRX(2007, 2012, PRO, fluoxetine)
%getRX(2007, 2012, CEL, citalopram)
%getRX(2007, 2012, PAX, paroxetine)
%getRX(2007, 2012, ZOL, sertraline)
%getRX(2007, 2012, LUV, fluvoxamine)
%getRX(2007, 2012, LEX, escitalopram)


/* Step 2: Get Periods of Use */

/*%macro useperiods(grace, washout, daysimp, maxDays,*/
/*                  inds, idvar, startenrol, rxdate, endenrol, dayssup, */
/*                  group, outds, wp);*/

%useperiods(30, 180, 30, 90, temp.proclaims, bene_id, startEnroll, srvc_dt, endPartD, dayssply, , temp.useperiods_pro)
%useperiods(30, 180, 30, 90, temp.celclaims, bene_id, startEnroll, srvc_dt, endPartD, dayssply, , temp.useperiods_cel)
%useperiods(30, 180, 30, 90, temp.paxclaims, bene_id, startEnroll, srvc_dt, endPartD, dayssply, , temp.useperiods_pax)
%useperiods(30, 180, 30, 90, temp.zolclaims, bene_id, startEnroll, srvc_dt, endPartD, dayssply, , temp.useperiods_zol)
%useperiods(30, 180, 30, 90, temp.luvclaims, bene_id, startEnroll, srvc_dt, endPartD, dayssply, , temp.useperiods_luv)
%useperiods(30, 180, 30, 90, temp.lexclaims, bene_id, startEnroll, srvc_dt, endPartD, dayssply, , temp.useperiods_lex)
		
data anyuse;
     set temp.useperiods_pro(in=pro) temp.useperiods_cel(in=cel) temp.useperiods_pax(in=pax) temp.useperiods_zol(in=zol) temp.useperiods_luv(in=luv) temp.useperiods_lex(in=lex);
     length drug $10;

     if pro then drug='PROZAC';
          else if cel then drug='CELEXA'; 
          else if pax then drug='PAXIL';
          else if zol then drug='ZOLOFT'; 
          else if luv then drug='LUVOX';
	  else if lex then drug='LEXAPRO';
run;

/* STEP 3: KEEP ONLY PERIODS OF NEW USE */

/* */
/* for new prozac users; join on other AD not being prevalant users */
proc sql; 
     create table newuse_pro_c1 as 
     select a.*, max(a.indexdate-180<=b.discontDate<a.indexdate or b.indexdate<a.indexdate<=b.discontDate) 
                    as prevalentUser_cel,
                 max(a.indexdate-180<=c.discontDate<a.indexdate or c.indexdate<a.indexdate<=c.discontDate) 
                    as prevalentUser_pax,
                 max(a.indexdate-180<=d.discontDate<a.indexdate or d.indexdate<a.indexdate<=d.discontDate) 
                    as prevalentUser_zol,
                 max(a.indexdate-180<=e.discontDate<a.indexdate or e.indexdate<a.indexdate<=e.discontDate) 
                    as prevalentUser_luv,
                 max(a.indexdate-180<=f.discontDate<a.indexdate or f.indexdate<a.indexdate<=f.discontDate) 
                    as prevalentUser_lex

     from temp.useperiods_pro(where=(newuse=1)) as a 
          left join temp.useperiods_cel as b on a.bene_id = b.bene_id
          left join temp.useperiods_pax as c on a.bene_id = c.bene_id
          left join temp.useperiods_zol as d on a.bene_id = d.bene_id
          left join temp.useperiods_luv as e on a.bene_id = e.bene_id
          left join temp.useperiods_lex as f on a.bene_id = f.bene_id
     group by a.bene_id, a.indexdate
     having prevalentUser_cel=0 and prevalentUser_pax=0 and prevalentUser_zol=0 and prevalentUser_luv=0 and prevalentUser_lex=0
     order by bene_id, indexdate;
quit;

/* for new celexa users; join on other AD not being prevalant users */
proc sql; 
     create table newuse_cel_c1 as 
     select a.*, max(a.indexdate-180<=b.discontDate<a.indexdate or b.indexdate<a.indexdate<=b.discontDate) 
                    as prevalentUser_pro,
                 max(a.indexdate-180<=c.discontDate<a.indexdate or c.indexdate<a.indexdate<=c.discontDate) 
                    as prevalentUser_pax,
                 max(a.indexdate-180<=d.discontDate<a.indexdate or d.indexdate<a.indexdate<=d.discontDate) 
                    as prevalentUser_zol,
                 max(a.indexdate-180<=e.discontDate<a.indexdate or e.indexdate<a.indexdate<=e.discontDate) 
                    as prevalentUser_luv,
                 max(a.indexdate-180<=f.discontDate<a.indexdate or f.indexdate<a.indexdate<=f.discontDate) 
                    as prevalentUser_lex
     from temp.useperiods_cel(where=(newuse=1)) as a 
          left join temp.useperiods_pro as b on a.bene_id = b.bene_id
          left join temp.useperiods_pax as c on a.bene_id = c.bene_id
          left join temp.useperiods_zol as d on a.bene_id = d.bene_id
          left join temp.useperiods_luv as e on a.bene_id = e.bene_id
          left join temp.useperiods_lex as f on a.bene_id = f.bene_id
     group by a.bene_id, a.indexdate
    having prevalentUser_pro=0 and prevalentUser_pax=0 and prevalentUser_zol=0 and prevalentUser_luv=0 and prevalentUser_lex=0
     order by bene_id, indexdate;
quit;


/* for new paxil users; join on other AD not being prevalant users */
proc sql; 
     create table newuse_pax_c1 as 
     select a.*, max(a.indexdate-180<=b.discontDate<a.indexdate or b.indexdate<a.indexdate<=b.discontDate) 
                    as prevalentUser_pro,
                 max(a.indexdate-180<=c.discontDate<a.indexdate or c.indexdate<a.indexdate<=c.discontDate) 
                    as prevalentUser_cel,
                 max(a.indexdate-180<=d.discontDate<a.indexdate or d.indexdate<a.indexdate<=d.discontDate) 
                    as prevalentUser_zol,
                 max(a.indexdate-180<=e.discontDate<a.indexdate or e.indexdate<a.indexdate<=e.discontDate) 
                    as prevalentUser_luv,
                 max(a.indexdate-180<=f.discontDate<a.indexdate or f.indexdate<a.indexdate<=f.discontDate) 
                    as prevalentUser_lex
     from temp.useperiods_pax(where=(newuse=1)) as a 
          left join temp.useperiods_pro as b on a.bene_id = b.bene_id
          left join temp.useperiods_cel as c on a.bene_id = c.bene_id
          left join temp.useperiods_zol as d on a.bene_id = d.bene_id
          left join temp.useperiods_luv as e on a.bene_id = e.bene_id
          left join temp.useperiods_lex as f on a.bene_id = f.bene_id
     group by a.bene_id, a.indexdate
    having prevalentUser_pro=0 and prevalentUser_cel=0 and prevalentUser_zol=0 and prevalentUser_luv=0 and prevalentUser_lex=0
     order by bene_id, indexdate;
quit;



/* for new zoloft users; join on other AD not being prevalant users */
proc sql; 
     create table newuse_zol_c1 as 
     select a.*, max(a.indexdate-180<=b.discontDate<a.indexdate or b.indexdate<a.indexdate<=b.discontDate) 
                    as prevalentUser_pro,
                 max(a.indexdate-180<=c.discontDate<a.indexdate or c.indexdate<a.indexdate<=c.discontDate) 
                    as prevalentUser_cel,
                 max(a.indexdate-180<=d.discontDate<a.indexdate or d.indexdate<a.indexdate<=d.discontDate) 
                    as prevalentUser_pax,
                 max(a.indexdate-180<=e.discontDate<a.indexdate or e.indexdate<a.indexdate<=e.discontDate) 
                    as prevalentUser_luv,
                 max(a.indexdate-180<=f.discontDate<a.indexdate or f.indexdate<a.indexdate<=f.discontDate) 
                    as prevalentUser_lex
     from temp.useperiods_zol(where=(newuse=1)) as a 
          left join temp.useperiods_pro as b on a.bene_id = b.bene_id
          left join temp.useperiods_cel as c on a.bene_id = c.bene_id
          left join temp.useperiods_pax as d on a.bene_id = d.bene_id
          left join temp.useperiods_luv as e on a.bene_id = e.bene_id
          left join temp.useperiods_lex as f on a.bene_id = f.bene_id
     group by a.bene_id, a.indexdate
    having prevalentUser_pro=0 and prevalentUser_cel=0 and prevalentUser_pax=0 and prevalentUser_luv=0 and prevalentUser_lex=0
     order by bene_id, indexdate;
quit;


/* for new luvox users; join on other AD not being prevalant users */
proc sql; 
     create table newuse_luv_c1 as 
     select a.*, max(a.indexdate-180<=b.discontDate<a.indexdate or b.indexdate<a.indexdate<=b.discontDate) 
                    as prevalentUser_pro,
                 max(a.indexdate-180<=c.discontDate<a.indexdate or c.indexdate<a.indexdate<=c.discontDate) 
                    as prevalentUser_cel,
                 max(a.indexdate-180<=d.discontDate<a.indexdate or d.indexdate<a.indexdate<=d.discontDate) 
                    as prevalentUser_pax,
                 max(a.indexdate-180<=e.discontDate<a.indexdate or e.indexdate<a.indexdate<=e.discontDate) 
                    as prevalentUser_zol,
                 max(a.indexdate-180<=f.discontDate<a.indexdate or f.indexdate<a.indexdate<=f.discontDate) 
                    as prevalentUser_lex
     from temp.useperiods_luv(where=(newuse=1)) as a 
          left join temp.useperiods_pro as b on a.bene_id = b.bene_id
          left join temp.useperiods_cel as c on a.bene_id = c.bene_id
          left join temp.useperiods_pax as d on a.bene_id = d.bene_id
          left join temp.useperiods_zol as e on a.bene_id = e.bene_id
          left join temp.useperiods_lex as f on a.bene_id = f.bene_id
     group by a.bene_id, a.indexdate
    having prevalentUser_pro=0 and prevalentUser_cel=0 and prevalentUser_pax=0 and prevalentUser_zol=0 and prevalentUser_lex=0
     order by bene_id, indexdate;
quit;


/* for new lexapro users; join on other AD not being prevalant users */
proc sql; 
     create table newuse_lex_c1 as 
     select a.*, max(a.indexdate-180<=b.discontDate<a.indexdate or b.indexdate<a.indexdate<=b.discontDate) 
                    as prevalentUser_pro,
                 max(a.indexdate-180<=c.discontDate<a.indexdate or c.indexdate<a.indexdate<=c.discontDate) 
                    as prevalentUser_cel,
                 max(a.indexdate-180<=d.discontDate<a.indexdate or d.indexdate<a.indexdate<=d.discontDate) 
                    as prevalentUser_pax,
                 max(a.indexdate-180<=e.discontDate<a.indexdate or e.indexdate<a.indexdate<=e.discontDate) 
                    as prevalentUser_zol,
                 max(a.indexdate-180<=f.discontDate<a.indexdate or f.indexdate<a.indexdate<=f.discontDate) 
                    as prevalentUser_luv
     from temp.useperiods_lex(where=(newuse=1)) as a 
          left join temp.useperiods_pro as b on a.bene_id = b.bene_id
          left join temp.useperiods_cel as c on a.bene_id = c.bene_id
          left join temp.useperiods_pax as d on a.bene_id = d.bene_id
          left join temp.useperiods_zol as e on a.bene_id = e.bene_id
          left join temp.useperiods_luv as f on a.bene_id = f.bene_id
     group by a.bene_id, a.indexdate
    having prevalentUser_pro=0 and prevalentUser_cel=0 and prevalentUser_pax=0 and prevalentUser_zol=0 and prevalentUser_luv=0
     order by bene_id, indexdate;
quit;



data allNewSSRIUsers;
     set newuse_pro_c1(in=a) newuse_cel_c1(in=b) newuse_pax_c1(in=c) newuse_zol_c1(in=d) newuse_luv_c1(in=e) newuse_lex_c1(in=f);
     if a then pro=1; else pro=0; 
     if b then cel=1; else cel=0;
     if c then pax=1; else pax=0;
     if d then zol=1; else zol=0;
     if e then luv=1; else luv=0;
     if f then lex=1; else lex=0;

     keep bene_id indexdate pro cel pax zol luv lex filldate2 lastFillDT numFill DiscontDate reason startEnroll endPartD;
run;


/* lets look at what kind of variables are in this dataset */
proc contents data=allnewSSRIUsers;

title 'all new users; 180 d washout';
proc freq data=allnewSSRIUsers;
     table pro;
     table cel;
     table pax;
     table zol;
     table luv;
     table lex;
run;

/* some exclusion criteria - need new users 65+, with 12 months AB enrollment prior*/
/* exclusion criteria, 12 months of enrollment*/

proc sql;
     create table cohort_enroll as
     select distinct a.*, strip(a.bene_id) || strip(put(a.indexdate,date9.)) as id,b.sex, b.race, b.dob, b.death_dt, 
           max("01JAN2007"d, b.abstartDT) as abstartDT label='Start Continuous A,B Enrollment' format=date9.,
           min(b.abendDT, b.death_dt) as endEnrol_itt label='End of Continuous A,B Enrollment' format=date9.,
           a.indexdate - calculated abstartDT as daysBL_AB label='Baseline Days of Continuous AB Coverage',
           case when .z < b.death_dt <= a.discontDate then 'Died' else 'NA' end as reason
               label='Reason for Discontinuation',
          case when month(b.dob) = month(a.indexdate) and day(dob) > day(indexdate) 
               then int(intck('month',dob,indexdate)/12)-1
               else int(intck('month',dob,indexdate)/12)
          end as age label='Age on Index Date'
     from allnewSSRIUsers as a left join der.enrlper_ab as b
          on a.bene_id = b.bene_id and b.abstartDT <= a.indexdate <= b.abendDT
     having daysBL_AB >= &bldays
	order by bene_id, indexdate
     ;
quit;

title 'with 12 months of parts of AB enrollment';
data ssri_cohort;
     set cohort_enroll;
	 run;

proc freq data=ssri_cohort;
     table pro;
     table cel;
     table pax;
     table zol;
     table luv;
     table lex;
run;

/* exclusion criteria, > 65 */

title 'age 65+';
/* will also need to exclude base on prior colon/rectal cancer diagnoses */
data ssri_cohort;
     set cohort_enroll;
     where age >= 65;
run;

proc contents data=ssri_cohort;


proc freq data=ssri_cohort;
     table pro;
     table cel;
     table pax;
     table zol;
     table luv;
     table lex;
run;

/*************** STEP 5: APPLY EXCLUSION CRITERIA *************/
/* Flag cohort members based on inclusion/exclusion criteria: */
/*                                     */
/*   1) no prevalent cancer (V10.05 = history large intenstine */
/*                           V10.06 = rectum, 153 all, 154 all
/*  3382F, 3384F, 3386F, 3388F, 3390F, G8371, G8372, G8377        */
/**************************************************************/

proc contents data=cncrexcl.icd9_dx;

proc sql;
     create table excludeDX as
     select distinct a.bene_id, a.indexdate,a.id
	 from ssri_cohort as a inner join der.alldx as b
	 	on a.bene_id = b.bene_id and a.indexdate-360 <= max(b.from_dt, b.thru_dt) 
                                 and .z < min(b.from_dt, b.thru_dt) <= a.indexdate
	 where b.dx in (select distinct compress(icd9,'.') from cncrexcl.icd9_dx as c where c.icd9 in 
	 ('V10.05','V10.06','154.0','154.1','154.8','153.0','153.1',
	 '153.2','153.3','153.4','153.6','153.7','153.8','153.9'))
	 order by id;
quit;
/*select distinct CPT from cncrexcl.cpt_trt  */

proc sql;
     create table excludePrcd as
     select distinct a.bene_id, a.indexdate,a.id
	 from ssri_cohort as a inner join der.allcpt as b
	 	on a.bene_id = b.bene_id and a.indexdate-360 <= b.proc_dt <= a.indexdate
	 where b.proc in ('3382F','3384F','3386F','3388F','3390F','G8371','G8372','G9084','G9085','G9086',
	       	      	 'G9087','G9088','G9089','G9090','G9091','G9092','G9092','G9093','G9094','G9095') 
	 order by id;
quit;

proc sort data=ssri_cohort; by id; run;

data out.ssricohort;
	merge ssri_cohort excludeDX(in=d) excludePrcd(in=e);
	by id;

     if age <= 65 then excludeAge = 1; else excludeAge = 0;
     if d or e then excludeCancer=1; else excludeCancer = 0;

	label excludeCancer = 'Flag indicating to exclude due to prevalent cancer on or prior to index date'
           excludeAge = 'Flag indicating to exclude based on age<=65';
run;


proc freq data=out.ssricohort;
     table pro*excludeCancer;
     table cel*excludeCancer;
     table pax*excludeCancer;
     table zol*excludeCancer;
     table luv*excludeCancer;
     table lex*excludeCancer;
run;


* Find pts w/ eligible 6-m washout periods and 2nd Rx*;

Data out.ssri_2rx;
     set out.ssricohort;
     if filldate2 ne . ; 
     run;

*endrsubmit;
