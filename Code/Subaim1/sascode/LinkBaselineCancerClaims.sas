/* This is a macro that finds all cancer claims of individuals who had a cancer dx
   in the baseline period of time (before index date) and had a CRC diagnosis
   in the followup period.

   process:
   1) subset the main dataset to include only individuals with baseline cancer who also developed CRC in followup
   2) Find the claims of these 
*/
options sasautos=(SASAUTOS "/mnt/files/projects/medicare/AntiDepCRC/programs/macros");
%setup(1pct, LinkBaselinCancerClaims.sas, Y)
%macro subsetData(inds,startdt,cancervar,blcancervar);
       proc sql;
       create table bCancerCases as
       	      select a.id,a.bene_id,a.excludeCancer,a.&startdt,a.&cancervar,a.&blcancervar from &inds as a
	      	     where a.&cancervar eq 1 and a.&blcancervar eq 1;
		    
      select * from bCancerCases;	
	    quit;
	       
%mend;

%macro getCancerClaims(inds);
     /* passing in a unique identifier (combination of bene_id and indexdate*/
     proc sql; 
          create table baselinecancer as 
	  	select distinct a.*,b.dx,b.from_dt from der.alldx as b inner join &inds as a
		on a.bene_id = b.bene_id and a.indexdate-360 <=b.from_dt<=a.indexdate-30
		where b.dx in (select compress(icd9,'.') from cncrexcl.icd9_dx)
		/*group by a.bene_id,a.indexdate*/
		order by a.id;

		
        /*create table baselinecancer2 as 
	select a.* from baselinecancer as a */

	
quit;
%mend;

/* test the data first on the SSRI dataset */
%subsetData(out.SSRICov_CRCD2NOInsitu_ITT,indexdate,CRCCancer,prevCancer_dx)
%getCancerClaims(bCancerCases)

data cancerfreq;
     set baselinecancer;
run;

proc contents data=cancerfreq;
run;

proc sort data=cancerfreq; by excludeCancer; run;

proc freq data=cancerfreq;
     table excludeCancer*prevCancer_dx;
     table excludeCancer*CRCCancer;
run;
title 'frequencies of cancer diagnoses in the baseline period';
proc freq data=cancerfreq;
table dx;
by excludeCancer;
run;
