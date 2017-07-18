filename master 'C:\SASProject\Master.csv';
filename newform 'C:\SASProject\NewForms.csv';
filename assign 'C:\SASProject\Assignments.csv';
filename correct 'C:\SASProject\Corrections.csv';
filename projclas 'C:\SASProject\ProjClass.csv';

/*import Master data*/
data master_n;

infile master firstobs=2 dsd; /*get rid of the first row in the orginal data */
retain Consultant ProjNum Date Hours Stage Complete; /*Keep the column order*/
informat Date mmddyy10.; /*Corrected date format to Date*/
input Consultant $ ProjNum Date Hours Stage Complete;/*Change internal representation  of dates to sort on the basis of dates*/
run;

/*import NewForm data */
data newform_n;
infile newform firstobs=2 dsd;
retain ProjNum Date Hours Stage Complete;
informat Date mmddyy10.; /*Corrected date format to Date*/
input ProjNum Date Hours Stage Complete;
run;

/*import Assignment data */
data assign_n;
infile assign firstobs=2 dsd;
input Consultant $ ProjNum;
run;

/*import Correction */
data correct_n;
infile correct firstobs=2 dsd;
informat Date mmddyy10.; /*Corrected date format to Date*/
input ProjNum Date Hours Stage;
run;

/*import Project Class */
data Proj_class;
infile projclas firstobs=2 dsd;
input type $ ProjNum;
run;

/*stack newform_n and master_n */
data stack_MN;
set master_n newform_n;
run;


/** sort stack_MN **/
proc sort data=stack_MN;
by ProjNum;
run;

/*Old Assignments*/
data assign_m(keep = Consultant ProjNum);
set stack_MN;
by ProjNum;
if missing(consultant) then delete;
if first.ProjNum then output;
run;

/** sort assign_n **/
proc sort data=assign_n;
by ProjNum;
run;
/** sort assign_m **/
proc sort data=assign_m;
by ProjNum;
run;
/* Merge new and old assignments*/
data assign_merge;
merge assign_m assign_n;
by projNum;
run;

/** merge stacked data with assignments**/
data merge_a;
merge stack_MN(drop = consultant ) assign_merge;
by ProjNum;
run;

/* update merge_a with correct_n */

/**sort correct_n **/
proc sort data= correct_n;
by ProjNum Date;
run;

/**sort merge_a **/
proc sort data= merge_a;
by ProjNum Date;
run;

data new_master;
update merge_a(in = in1) correct_n(in = in2); /*Update merge_a using correct_n by referring to both ProjNum and Date*/
by ProjNum Date;
if in2 then Corrections = 'Yes'; /*Add columns for corrrections*/
run;


proc sort data= new_master;
by ProjNum;
run;

proc sort data= Proj_Class;
by ProjNum;
run;

data new_master;
merge new_master Proj_Class;
by ProjNum;
if missing(Hours) then Hours = 0; /*Replace missing hours*/ 
*retain Consultant ProjNum Type Date Hours Stage Complete Corrections;
run;

proc sort data= new_master;
by ProjNum Date;
run;

*creating newmaster csv;
filename NwMstr 'C:\SASProject\NewMaster.csv';
data _NULL_;
set new_master;
file NwMstr dsd;
put consultant Projnum Date Hours ProjClass Complete Corrections; /*Replaced stage with class*/
run;

LIBNAME ProjData 'C:\SASProject\';
data ProjData.NewMaster;
set new_master;
run;
/*End of Objective 1, assuming merge is correct*/

/*Objective 2: List of ongoing projects as on 11/4/2010*/
data ongoing ( keep = ProjNum);
set new_master;
by ProjNum Date;
if complete = 0 and last.ProjNum = 1 then output;
run;

/*Objective 3: */
/*Only outputting to one File right now*/
/*data Smith(keep = ProjNum Hrs_tot Stage Complete start_date end_date) */
/*	Brown(keep = ProjNum Hrs_tot Stage Complete start_date end_date) */
/*	Jones(keep = ProjNum Hrs_tot Stage Complete start_date end_date);*/
/*retain Hrs_tot Stage Complete start_date end_date; */
/*set ProjData.NewMaster;*/
/*by ProjNum Date;*/
/*array Consult{3} $ Cons1-Cons3 ('Smith' 'Brown' 'Jones');*/
/*do i  = 1 to 3;*/
/*	if Consultant = Consult(i) then do;/*Iterating over the three consultants*/
/*		/*Calculating total hours spent on project*/
/*		if first.ProjNum then do;*/
/*			Hrs_tot = Hours;*/
/*			start_date = Date;*/
/*		end;*/
/*		else Hrs_tot = Hrs_tot + Hours;*/
/*		/*Outputting to three diffetren tables based on consultant*/
/*		if last.ProjNum and Consultant = 'Smith' then do;*/
/*			end_date = Date;*/
/*			output Smith;*/
/*		end;*/
/*		if last.ProjNum and Consultant = 'Brown' then do;*/
/*			end_date = Date;*/
/*			output Brown;*/
/*		end;*/
/*		if last.ProjNum and Consultant = 'Jones' then do;*/
/*			end_date = Date;*/
/*			output Jones;*/
/*		end;*/
/*	end;*/
/*end;*/
/*run;*/

/*Objective 3: */
/*Only outputting to one File right now*/

data Smith(keep = ProjNum Hrs_Smith Proj_Class Complete start_date end_date ) 
	Brown(keep = ProjNum Hrs_Brown Proj_Class Complete start_date end_date ) 
	Jones(keep = ProjNum Hrs_Jones Proj_Class Complete start_date end_date /*rename = (Hrs_Jones = Hrs_tot)*/);
retain Hrs_Smith Hrs_Brown Hrs_Jones Proj_Class Stage Complete start_date end_date; 
set new_master;
by ProjNum Date; /*Added correction for missing hours total from consutant report*/

		if first.ProjNum then do;
			start_date = Date;
			if Consultant = 'Smith' then Hrs_Smith  = Hours;
			if Consultant = 'Brown' then Hrs_Brown  = Hours;
			if Consultant = 'Jones' then Hrs_Jones  = Hours;
		end;
		else do;
			if Consultant = 'Smith' then Hrs_Smith = Hrs_Smith + Hours;
			if Consultant = 'Brown' then Hrs_Brown = Hrs_Brown + Hours;
			if Consultant = 'Jones' then Hrs_Jones = Hrs_Jones + Hours;
		end;
		/*Outputting to three diffetren tables based on consultant*/
		if last.ProjNum then do;
			end_date = Date;
			if Consultant = 'Smith' then output Smith;
			if Consultant = 'Brown' then output Brown;
			if Consultant = 'Jones' then output Jones;
		end;

run;