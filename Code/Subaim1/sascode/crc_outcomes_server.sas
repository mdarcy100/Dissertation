
/*****************************************************************************************************/
/*****************************************************************************************************/
/*                                                                                                   */
/* Program: /mnt/files/projects/medicare/AntiDepCRC/programs/crc_outcomes_server.sas                        */
/* Purpose: Define colon or rectal cancer outcomes based on Definitions 2 from Setoguchi algorithm   */
/*                                                                                                   */
/* Created on: Oct 20, 2014                                                                       */
/* Created by: M D'Arcy                                                                         */
/*                                                                                                   */
/* Inputs: ssri_cohort or AD_cohort, where statemen... see below for example                         */
/*                                                                                                   */
/* Outputs: cohorts of ssri, ad with covariates and outcomes 	                                     */
/*

/* this macro is very similar to Virginia's cancerd2.sas
   inputs: 
   inds = input dataset
   cohort=ssri or AD
   site = cancer site (colon, rectal, crc)
   id = unique identifer for person (not per record)
   startdt = start of followup (frequently fill2) or fill2 + induction period
   enddt = end of followup; either end of enrollment or end of drug use + latency period
   outds = the output dataset with new variables
   outvar = the name of the variable to be output (colon, rectal or CRC)

     %LET dxColorectal = dx like "153%" or dx like "2303%" or dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")) ;  

example call (s):
%getCRCD2(out.covSSRI_2rx,ssri,rectal,bene_id indexdate,filldate2,discontDate,SSRICov_rectalD2_AsTreated, 
	rectal,dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")))


%getCRCD2(out.covSSRI_2rx,ssri,colon,bene_id indexdate,filldate2,discontDate,SSRICov_colonD2_AsTreated, 
	colon, dx like "153%" or dx like "2303%")


%getCRCD2(out.covSSRI_2rx,ssri,CRC,id, filldate2,discontDate,SSRICov_CRCD2_AsTreated, 
	CRC, dx like "153%" or dx like "2303%" or dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")))


%getCRCD2(out.covAD_2rx,AD,CRC,id, filldate2,discontDate,SSRICov_CRCD2_AsTreated, 
	CRC, dx like "153%" or dx like "2303%" or dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")))
 */                                                                                                   
/*                                                                                                   */
/* Updates:                                                                                          */
/*****************************************************************************************************/
/*****************************************************************************************************/
/*
%let server=localhost 1234;
options comamid=tcp remote=server;
signon username=_prompt_;
rsubmit;
*/
options sasautos=(SASAUTOS "/mnt/files/projects/medicare/AntiDepCRC/programs/macros");
%setup(1pct, crc_outcomes_server.sas, Y)

*options symbolgen;

%macro getCRCD2(inds,cohort,site,id, startdt,enddt,outds,outvar,clause);
%put &clause;
     /* Determine unique identifier per person vs per record */
     /*%LET numID = %SYSFUNC(countw(&id));  
     %DO z=1 %TO &numID; /*%LET id&z = %SCAN(&id,&z); %END;*/

     /* passing in a unique identifier (combination of bene_id and indexdate*/
     proc sql; 
          create table _temp_cancerd2 as 
	  	select distinct b.&id,a.from_dt label="Diagnosis Date for &outvar" format=date9.
			from der.alldx(where=(&clause )) as a inner join &inds as b
		on a.bene_id = b.bene_id and b.&startdt <= a.from_dt <= b.&enddt
		order by b.&id,a.from_dt;
		;
/*
	             select distinct a.bene_id, a.indexdate, b.from_dt format=date9.
      	  	      from &inds as a inner join der.alldx(where=(&clause)) as b 
		      on a.bene_id = b.bene_id and a.&startdt <= b.from_dt <= a.&enddt 
		      group by a.bene_id, a.indexdate 
		      order by bene_id, indexdate, from_dt;
*/
/*
			select distinct %DO z=1 %TO %SYSFUNC(countw(&id)); b.&&id&z, %END;
                         a.from_dt label="Diagnosis Date for &outvar" format=date9.
				from der.alldx(where=(&clause )) as a inner join &inds as b
					on a.&id1 = b.&id1 and b.&startdt <= a.from_dt <= b.&enddt
				order by %DO z=1 %TO &numID; b.&&id&z %IF &z<&numID %THEN ,; %END;
				;
*/

		  quit; 

    data &outds;
          merge &inds _temp_cancerd2;
          by &id;
          retain lastdt &outvar;
          if first.&id then do;
	       &outvar._dxdt=.;
               lastdt = from_dt;
               &outvar = 0;
          end;
          else if &outvar = 0 then do;
               if 0 < from_dt - lastdt <= 60 then do;
                    &outvar._dx1dt = lastdt;
		    &outvar._dx2dt = from_dt;
                    &outvar = 1;
                    output;
               end;
               else lastdt = from_dt;
          end;

/*          if last.&&id&Nid and &outvar=0 then output;*/

          label &outvar._dx2dt = "2nd Diagnosis Date for Cancer (by Definition 2)"
                &outvar = "Diagnosis of colon Cancer (by Setoguchi Def2)"
                &outvar._dx1dt = "1st Diagnosis Date for Cancer (by Definition 2)";
*          drop from_dt lastdt;
          format &outvar._dx1dt &outvar._dx2dt date9.;
     run;

proc sql; 
 create table &site.&cohort as 
    select a.*, b.&outvar._dx2dt,b.&outvar._dx1dt, case when b.&outvar ne . then 1 else 0 end as &site.Cancer from &inds as a left join &outds as b 
	    /*on a.bene_id=b.bene_id and a.indexdate=b.indexdate */
	    on a.&id=b.&id;
	   /* group by a.id;*/
quit;

data out.&outds;
     set &site.&cohort;
run;

%mend getCRCD2;

/* 2/10/2015: run the outcomes code on the AD - THZ only cohort. */
/*%getCRCD2(out.covTHZONLY_2rx,ADTHZ,CRC,id,filldate2,endEnrol_itt,THZONLYCov_CRCD2NOInsitu_ITT, 
	CRC, dx like "153%"  or (dx like "154%" and dx ^in ("1542","1543","1544")))*/

/* 1/28/2015 Don't include in situ codes: this code has already been run */
/*%getCRCD2(out.covADTHZ_2rx,AD,CRC,id,filldate2,endEnrol_itt,ADTHZCov_CRCD2NOInsitu_ITT, 
	CRC, dx like "153%"  or (dx like "154%" and dx ^in ("1542","1543","1544")))*/

/* 5/2015 - NEED TO rerun with new prior cancer diagnosis codes */

%getCRCD2(out.covSSRI_2rx,SSRI,CRC,id,filldate2,endEnrol_itt,SSRICov_CRCD2NOInsitu_ITT, 
	CRC, dx like "153%" or (dx like "154%" and dx ^in ("1542","1543","1544")))


%getCRCD2(out.covAD_2rx,AD,CRC,id,filldate2,endEnrol_itt,ADCov_CRCD2NOInsitu_ITT, 
	CRC, dx like "153%" or (dx like "154%" and dx ^in ("1542","1543","1544")))

/* 5/2015 now get only colon cancer cases; append colon cancer status to the crc file */
%getCRCD2(out.SSRICov_CRCD2NOInsitu_ITT,SSRI,colon,id,filldate2,endEnrol_itt,SSRICov_CRCD2NOInsitu_ITT, 
	colon, dx like "153%")


%getCRCD2(out.ADCov_CRCD2NOInsitu_ITT,AD,colon,id,filldate2,endEnrol_itt,ADCov_CRCD2NOInsitu_ITT, 
	colon, dx like "153%")








/* we need the ITT data/outcomes*/
/* 1/25/2015:  need to make the AD thiazide cohort */

/*%getCRCD2(out.covADTHZ_2rx,AD,CRC,id,filldate2,endEnrol_itt,ADTHZCov_CRCD2_ITT, 
	CRC, dx like "153%" or dx like "2303%" or dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")))

*/

/* 1/25/2015:  These cohorts have already been generated ; they include in-situ codes*/
/*
%getCRCD2(out.covSSRI_2rx,SSRI,CRC,id,filldate2,endEnrol_itt,SSRICov_CRCD2_ITT, 
	CRC, dx like "153%" or dx like "2303%" or dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")))


%getCRCD2(out.covAD_2rx,AD,CRC,id,filldate2,endEnrol_itt,ADCov_CRCD2_ITT, 
	CRC, dx like "153%" or dx like "2303%" or dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")))


*/
/*
%getCRCD2(out.covSSRI_2rx,SSRI,CRC,id,filldate2,discontDate,SSRICov_CRCD2_AsTreated, 
	CRC, dx like "153%" or dx like "2303%" or dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")))


%getCRCD2(out.covAD_2rx,AD,CRC,id,filldate2,discontDate,ADCov_CRCD2_AsTreated, 
	CRC, dx like "153%" or dx like "2303%" or dx="2304" or (dx like "154%" and dx ^in ("1542","1543","1544")))
*/



/*
%getCRCD2(out.covSSRI_2rx,colon,id,filldate2,discontDate,SSRICov_colonD2_AsTreated, 
	colon, dx like "153%" or dx like "2303%")

%getCRCD2(out.covSSRI_2rx,rectal,id,filldate2,discontDate,SSRICov_rectalD2_AsTreated, 
	rectal,dx like "2304%" or (dx like "154%" and dx ^in ("1542","1543","1544")))

*/

*endrsubmit;


/*
%getCRC(ssri_2rx,colon)
%getCRC(ssri_2rx,rectal)
%getCRC(ssri_2rx,crc)*/

/* Now merge with the original dataset information */



/*
proc sql; 
     create table RectalSSRICohort as 
     	    select a.*, case when b.rectal_def2 ne . then 1 else 0 end as rectalCancer,b.rectal_def2_dx1dt, b.rectal_def2_dx2dt 
	    from out.covssri_2rx as a left join temp.rectaldef2_ssri_2rx as b 
	    on a.bene_id=b.bene_id and a.indexdate=b.indexdate
	    group by a.bene_id having min(a.indexdate)=a.indexdate;
quit;
*/

/*

/*
data out.rectal_CovOut_ssri_2rx;
     set RectalSSRICohort;
run;
*/


