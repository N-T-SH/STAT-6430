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
length type $18;
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

/*Merge the consolidated master with the table where corrections are made*/
data new_master;
update merge_a(in = in1) correct_n(in = in2); /*Update merge_a using correct_n by referring to both ProjNum and Date*/
by ProjNum Date;
if in2 then Corrections = 'Yes'; /*Add columns for corrrections*/
run;

/*Sort the master by ProjNum*/
proc sort data= new_master;
by ProjNum;
run;

/*Sort the project class by ProjNum*/
proc sort data= Proj_Class;
by ProjNum;
run;

/*Add project types to master file*/
data new_master;
merge new_master Proj_Class;
by ProjNum;
if missing(Hours) then Hours = 0; /*Replace missing hours*/ 
run;

/*Sort the updates master*/
proc sort data= new_master;
by ProjNum Date;
run;

*creating newmaster csv to output csv files;
filename NwMstr 'C:\SASProject\NewMaster.csv';
data _NULL_;
set new_master;
file NwMstr dsd;
put consultant Projnum Date Hours stage type Complete Corrections; /*Replaced class with type - type is the var, class was the file*/
format date mmddyy10.; /*formatted date so the CSV writes it correctly */
run;

/*if desired can print with updated clinet-friendly labels*/
proc print data= new_master label;
var consultant Projnum Date Hours stage Complete Corrections type;
label Consultant = 'Consultant' Projnum = 'Project Number' Date = 'Date' Hours = 'Hours Worked'
stage = 'Project Stage' Complete = 'Complete' Corrections = 'Corrections Made' type = 'Project Type';
run; 

/*create permanent sas data set*/
LIBNAME ProjData 'C:\SASProject\';
data ProjData.NewMaster;
set new_master;
run;
/*End of Objective 1*/

/*Objective 2: List of ongoing projects as on 11/4/2010*/
title2 'Ongoing Projects'; /*Add title */

/*add in new_master, sort by Projdate, output completed projects*/
data ongoing ( keep = ProjNum);
set new_master;
by ProjNum Date;
if complete = 0 and last.ProjNum = 1 then output;
run;

proc print data=ongoing noobs label; /*output with title and no observations*/
label projnum = 'Project Number'; /*update projnum label*/
run;


/*Objective 3: */
/*Using the new master file, generate a report of the consulting activity of each consultant on each project as of the last entry date  */
data Smith(keep = ProjNum type Hrs_Smith Proj_Class Complete start_date end_date ) 
	Brown(keep = ProjNum type Hrs_Brown Proj_Class Complete start_date end_date ) 
	Jones(keep = ProjNum type Hrs_Jones Proj_Class Complete start_date end_date /*rename = (Hrs_Jones = Hrs_tot)*/);
retain Hrs_Smith Hrs_Brown Hrs_Jones Proj_Class Stage Complete start_date end_date; 
set new_master;
by ProjNum Date; /*=Sort by date*/

		if first.ProjNum then do; /*Begin to total the hours by Consultant using if else statements*/
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
		/*Outputting to three different tables based on consultant*/
		if last.ProjNum then do;
			end_date = Date;
			if Consultant = 'Smith' then output Smith;
			if Consultant = 'Brown' then output Brown;
			if Consultant = 'Jones' then output Jones;
		end;

run;

/*give titles and print each output for consulting activity */
title3 'Consulting Activity for Smith'; 
proc print data=Smith noobs label; /*output with title and no observations*/
label Hrs_Smith = 'Hours Worked' Complete = 'Complete' Projnum = 'Project Number' 
start_date = 'Start Date' end_date = 'End Date' type = 'Project Type';/*Update Labels*/
run;

title;
title4 'Consulting Activity for Jones';
proc print data=Jones noobs label; /*output with title and no observations*/
label Hrs_Jones = 'Hours Worked' Complete = 'Complete' Projnum = 'Project Number' 
start_date = 'Start Date' end_date = 'End Date' type = 'Project Type';/*Update Labels*/
run;

title;
title5 'Consulting Activity for Brown';
proc print data = Brown noobs label; /*output with title and no observations*/
label Hrs_Brown = 'Hours Worked' Complete = 'Complete' Projnum = 'Project Number' 
start_date = 'Start Date' end_date = 'End Date' type = 'Project Type';  /*Update Labels*/
run;

/*Objective 4: */                                                                                                                                                                                                                                               
/*1st. total amount of hrs spent on different types of projects for each consultant (complete projects only)*/                                                                                                                                                  
proc sort data = smith;                                                                                                                                                                                                                                         
by type;                                                                                                                                                                                                                                                        
run;                                                                                                                                                                                                                                                            
 
 /* Sum hours worked by Consultant Smith*/
data PrjHr_Smith (drop = hrs_smith stage complete start_date end_date projNum);                                                                                                                                                                                 
set smith;                                                                                                                                                                                                                                                      
by type;                                                                                                                                                                                                                                                        
retain Hrs_tot SumHrs;                                                                                                                                                                                                                                          
if first.type then sumHrs=hrs_smith;                                                                                                                                                                                                                            
else sumHrs+hrs_smith;                                                                                                                                                                                                                                          
if last.type then output;                                                                                                                                                                                                                                       
run;                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                
proc sort data = jones;                                                                                                                                                                                                                                         
by type;                                                                                                                                                                                                                                                        
run;                                                                                                                                                                                                                                                            

 /* Sum hours worked by Consultant Jones*/
data PrjHr_Jones (drop = Hrs_jones stage complete start_date end_date projNum);                                                                                                                                                                                 
set jones;                                                                                                                                                                                                                                                      
by type;                                                                                                                                                                                                                                                        
retain Hrs_tot SumHrs;                                                                                                                                                                                                                                          
if first.type then sumHrs=Hrs_jones;                                                                                                                                                                                                                            
else sumHrs+Hrs_jones;                                                                                                                                                                                                                                          
if last.type then output;                                                                                                                                                                                                                                       
run;                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                
proc sort data = brown;                                                                                                                                                                                                                                         
by type;                                                                                                                                                                                                                                                        
run;                                                                                                                                                                                                                                                            

 /* Sum hours worked by Consultant Brown*/
data PrjHr_Brown (drop = Hrs_brown stage complete start_date end_date projNum);                                                                                                                                                                                 
set brown;                                                                                                                                                                                                                                                      
by type;                                                                                                                                                                                                                                                        
retain Hrs_tot SumHrs;                                                                                                                                                                                                                                          
if first.type then sumHrs=hrs_brown;                                                                                                                                                                                                                            
else sumHrs+hrs_brown;                                                                                                                                                                                                                                          
if last.type then output;                                                                                                                                                                                                                                       
run;                                                                                                                                                                                                                                                            

 /* Sort new data sets by type*/
proc sort data = Prjhr_smith;                                                                                                                                                                                                                                   
by type;                                                                                                                                                                                                                                                        
run;                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                
proc sort data = Prjhr_brown;                                                                                                                                                                                                                                   
by type;                                                                                                                                                                                                                                                        
run;                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                
proc sort data = Prjhr_jones;                                                                                                                                                                                                                                   
by type;                                                                                                                                                                                                                                                        
run;                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                
data Prjhr_sb;                                                                                                                                                                                                                                                  
merge Prjhr_smith (rename = (SumHrs = Smith)) Prjhr_brown (rename = (SumHrs = Brown));                                                                                                                                                                          
by type;                                                                                                                                                                                                                                                        
run;                                                                                                                                                                                                                                                            

 /* Create Data Set with all consultant's totals*/
data Prjhr_all;                                                                                                                                                                                                                                                 
merge Prjhr_jones (rename = (SumHrs = Jones)) Prjhr_sb;                                                                                                                                                                                                         
by type;                                                                                                                                                                                                                                                        
run; 

/* Set the graphics environment */                                                                                                                                                                                                                              
goptions reset=all cback=white border htitle=12pt htext=10pt;                                                                                                                                                                                                   
                                                                                                                                                                                                                                                                
/* Define the title */                                                                                                                                                                                                                                          
title1 'Total Hours by Project Type';                                                                                                                                                                                                                           
                                                                                                                                                                                                                                                                
/* Define the axis characteristics */                                                                                                                                                                                                                           
axis1 value=none label=none;                                                                                                                                                                                                                                    
axis2 label=(angle=90 "Hours");                                                                                                                                                                                                                                 
axis3 label=none;                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                                
/* Define the legend options */                                                                                                                                                                                                                                 
legend1 frame;                                                                                                                                                                                                                                                  
                                                                                                                                                                                                                                                                
/* Generate the graph */                                                                                                                                                                                                                                        
proc gchart data=new_master;                                                                                                                                                                                                                                    
   vbar consultant / subgroup=consultant group=type sumvar=hours                                                                                                                                                                                                
                  legend=legend1 space=0 gspace=4                                                                                                                                                                                                               
                  maxis=axis1 raxis=axis2 gaxis=axis3;                                                                                                                                                                                                          
run;                                                                                                                                                                                                                                                            
quit;

/*2nd. average time spent on types of projects */  

*Create new data set that totals the hours spent on each project;
title;
title7 'Average Hours Worked by Project Type';
data HoursbyType (keep = projnum hours type hourstot);
set new_master;
by ProjNum;
retain hourstot;
if first.projnum then hourstot=0;
hourstot = hourstot + hours;
if last.projnum then output;
run;

*find the average and display using proc statement;
proc means data=HoursbyType n mean std min max;
class type;
var hourstot;
label type = 'Project Type';
run;

/*3rd. Period of time spent in each project stage */
data DurbyStage (keep = projnum Stage Duration) ;
retain start end;
set New_master;
by ProjNum Stage;
retain Duration;
        if first.Stage then do;
            start = Date;
            end;
        if last.Stage then do;
            end = Date;
            duration = end - start; /*Calculation of duration taken to complete the stage*/
            output;
            end;
run;
/*Sorting data by stage*/
proc sort data= DurbyStage;
by Stage;
run;
/*Boxplot showing duration distribution by stage*/
title;
title5 ''Duration of Time by Project Stage';
proc boxplot data=DurbyStage;
plot Duration*Stage;
run;

