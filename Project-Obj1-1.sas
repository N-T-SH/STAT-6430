filename master 'C:\SASProject\Master.csv';
filename newform 'C:\SASProject\NewForms.csv';
filename assign 'C:\SASProject\Assignments.csv';
filename correct 'C:\SASProject\Corrections.csv';

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


/*stack newform_n and master_n */
data stack_MN;
set master_n newform_n;
run;

/*After stacking, the additional ProjNum from newform will not have corresponding consultant name. The following codes serve as a
a way to fill in the missing consultant name */

data stack_fill (drop = X);
set stack_MN;
retain X; /*keep the last non-missing value in memory*/
if not missing (Consultant) Then X = Consultant; /*fills the new variable with non-missing value */
Consultant = X;
run;

/* merge stack_fill with assign_n */

/** sort assign_n **/
proc sort data=assign_n;
by ProjNum;
run;

/** sort stack_fill **/
proc sort data=stack_fill;
by ProjNum;
run;

/** merge **/
data merge_a;
merge assign_n stack_fill;
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
by ProjNum Date;
run;

*creating newmaster csv;
filename NwMstr 'C:\SASProject\NewMaster.csv';
data _NULL_;
set new_master;
file NwMstr dsd;
put consultant Projnum Date Hours Stage Complete Corrections;
run;

LIBNAME ProjData 'C:\SASProject\';
data ProjData.NewMaster;
set new_master;
run;
/*End of Objective 1, assuming merge is correct*/

/*Objective 2: List of ongoing projects as on 11/4/2010*/
data ongoing ( keep = ProjNum);
set ProjData.NewMaster;
by ProjNum Date;
if complete = 0 and last.ProjNum = 1 then output;
run;

/*Objective 3: */
/*Only outputting to one File right now*/
data Smith(keep = ProjNum Hrs_tot Stage Complete start_date end_date) 
	Brown(keep = ProjNum Hrs_tot Stage Complete start_date end_date) 
	Jones(keep = ProjNum Hrs_tot Stage Complete start_date end_date);
retain Hrs_tot Stage Complete start_date end_date; 
set ProjData.NewMaster;
by ProjNum Date;
array Consult{3} $ Cons1-Cons3 ('Smith' 'Brown' 'Jones');
do i  = 1 to 3;
	if Consultant = Consult(i) then do;/*Iterating over the three consultants*/
		/*Calculating total hours spent on project*/
		if first.ProjNum then do;
			Hrs_tot = Hours;
			start_date = Date;
		end;
		else Hrs_tot = Hrs_tot + Hours;
		/*Outputting to three diffetren tables based on consultant*/
		if last.ProjNum and Consultant = 'Smith' then do;
			end_date = Date;
			output Smith;
		end;
		if last.ProjNum and Consultant = 'Brown' then do;
			end_date = Date;
			output Brown;
		end;
		if last.ProjNum and Consultant = 'Jones' then do;
			end_date = Date;
			output Jones;
		end;
	end;
end;
run;

