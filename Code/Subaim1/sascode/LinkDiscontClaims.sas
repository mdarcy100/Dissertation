/* This is a macro that finds all claims of a related drug or drug class after the discontinuation date

   process:
   1) Pass in the cohort; iterate through all individuals and look for 
      	   individuals who had an actual discontinuation date
   
   2) find claims of related drugs after the discontinuation date

   2) return cohort that has the new drug and date of drug initation
*/
options sasautos=(SASAUTOS "/mnt/files/projects/medicare/AntiDepCRC/programs/macros");

%setup(1pct, LinkDiscontClaims.sas, Y)
%macro findDiscontinuationSSRI(inds,startYr,endYr);
       proc sql;
       select count(*) as tmp from (select distinct bene_id,id from &inds);

       create table discontinuers as
       	      select a.id,a.bene_id,a.reason,a.DiscontDate,a.pro,a.lex,a.pax,a.cel,a.zol,a.luv,lastFillDT,numfill from &inds as a
	      	     WHERE a.reason LIKE 'Drug%';
		    
 /*     select * from discontinuers; */	

    * Find all claims that happen after the discontinuation date;
          create table allpostClaims as  select distinct a.srvc_dt, a.DAYSSPLY, a.gnn,b.*
          from (%DO yr=&startyr %TO &endyr;
               select bene_id, srvc_dt, DAYSSPLY, gnn
                from raw.pde_saf_file&yr
          %IF &yr<&endyr %THEN union all corresponding;
          %END; ) as a inner join discontinuers as b
             on a.bene_id = b.bene_id and b.DiscontDate <= a.srvc_dt <= b.DiscontDate+181;

	     * then find claims of only drug of interest after discontinuation date;
	   CREATE table postClaims as select distinct a.*,MIN(a.srvc_dt) as startnewRX format=date9.
	   	  FROM allpostClaims as a
		       WHERE (upcase(a.gnn) contains 'FLUOXETINE' or 
		       	     upcase(a.gnn) contains 'CITALOPRAM' or
		       	     upcase(a.gnn) contains 'PAROXETINE' or
		       	     upcase(a.gnn) contains 'SERTRALINE' or
		       	     upcase(a.gnn) contains 'FLUVOXAMINE' or
		       	     upcase(a.gnn) contains 'ESCITALOPRAM')
			     
		       Group BY a.id,a.DiscontDate
		       HAVING a.srvc_dt=min(a.srvc_dt)
		       ORDER BY a.id, a.srvc_dt;    
	
	select count(*) as tmp from (select distinct id from postClaims);


	/* now link back with the original dataset.  removed the generic name since sometimes multiple types of claims  */
	create table mergedDS as
	       SELECT distinct a.*, MIN(b.srvc_dt) as firstAugment,case when b.startnewRX ne . then 1 else 0 end as SwitchAugment 
	       	      FROM &inds as a 
	       LEFT JOIN postClaims as b on a.id=b.id
		      HAVING b.srvc_dt=min(b.srvc_dt);

	/* aggregate by the number of different SSRI RX  after discontinuation date */
/*	CREATE table mergedAggregated as
	       SELECT distinct a.*, SUM(SwitchAugment) as totalAugment FROM mergedDS
	       GROUP BY a.id,a.DiscontDate
	       ORDER by a.id  */
 quit;

%mend;

proc contents data=out.SSRICov_CRCD2NOInsitu_ITT; run;

%findDiscontinuationSSRI(out.SSRICov_CRCD2NOInsitu_ITT,2007,2012)
* now we need to remerge with main dataset; 

*%getRXPostDiscont(discontinuers,2007, 2012);

proc contents data=out.SSRICov_CRCD2NOInsitu_ITT; run;
proc contents data=mergedDS (obs=20);
run;

proc print data=mergedDS(obs=20);
run;

