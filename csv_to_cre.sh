#!/bin/bash
# Fred Denis -- fred.denis3@gmail.com -- Jan 22th 2020
#
# Generate bigquery CREATE TABLE DDL from a csv file, each line containing:
# 	Technology,Vendor,Category,Schema,Table Name,Column Name,Data Type,Primary Key,Comments
#
# A directory is created for each dataset
# Each CREATE TABLE statement ends in a separated file in the corresponding dataset directory
# Some tables are partitioned depending on its dataset which is harcoded
#
# Some default values
#
       IN="a.csv"			#	(-f)
  PROJECT="bmas-eu-mbnl-data-dev"	#	(-p)
  DATASET="PM_TGT"			#	(-d)
PARTITION="NO"				#	(-P)
#
# usage function
#
usage()
{
	cat << !
	. $0 -f <Input csv file> -d <dataset> -p <project>
!
}
#
# Options
#
while getopts "f:p:d:Ph" OPT; do
        case ${OPT} in
	f)	     IN="${OPTARG}"					;;
	d)	DATASET="${OPTARG}"					;;
	p)	PROJECT="${OPTARG}"                                     ;;
	P)    PARTITION="YES"						;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done
#
# Input verification
#
if [[ ! -f ${IN} ]]
then
	printf "\n\t\033[1;36m%s\031[m\n\n" "An input file is needed; cannot continue."
		exit 123
fi
for x in PROJECT DATASET
do
        if [[ -z ${!x} ]]
        then
                printf "\n\t\033[1;31m%s\033[m\n\n" "A value is needed for ${x}; cannot continue."
                exit 124
        fi
done
if [[ ! -d ${DATASET} ]] 
then
	mkdir ${DATASET}
	if [ $? -eq 0 ]
	then
                printf "\n\t\033[1;33m%s\033[m\n\n" "Directory ${DATASET} successfully created."
	fi
fi
if [[ ${DATASET} = "PM_TGT" || ${DATASET} = "PM_STAGE_ALL" ]] 
then
	PARTITION="YES"
fi
printf "%s\n" "Working on project $PROJECT and dataset $DATASET using csv file $IN"
#
# Generate the create tables files
#
grep "^\w" a.csv | tail -n +2 | tr '[:lower:]' '[:upper:]' |\
	awk -F "," -v DATASET="${DATASET}" -v PROJECT="${PROJECT}" -v PARTITION="${PARTITION}"\
	' function print_col(in_col, in_type, in_pk)
	  {	if (in_pk == "Y")
		{	NOTNULL="NOT NULL"							;
		} else {
			NOTNULL=""								;
		}
		printf("%s %s %s\n", in_col, in_type, NOTNULL)		>> OUT			;
	  }
	  function print_end()
	  {
		printf("%s", ")")					>> OUT			;
		if (PARTITION == "YES")
		{	printf("%s", "PARTITION BY DATE(STARTTIME)") 	>> OUT			;
		}
		printf("\n")						>> OUT			;
	  }
	{	if (tab_name == $5)
		{	printf("%s", ",")				>> OUT			;
			print_col($6, $7, $8)							;	
		}	else
		{
			tab_name = $5								;
			if (NR > 1)
			{
				print_end()							;
			}
			OUT=DATASET"/"$4"_"$5".sql"						;	# Output file
			printf("") 					> OUT			;
			printf("%s\n", "CREATE TABLE IF NOT EXISTS `" PROJECT"."DATASET"."$5"`(")	>> OUT	;
			print_col($6, $7, $8)							;	
		}
	 }
         END {		print_end()								;
	     }
         '
#
#
#
NB=`ls $DATASET | wc -l`
printf "%s\n" "$NB create table files have been generated in the $DATASET directory"
#****************************************************************************************#
#*			E N D      O F       S O U R C E				*#
#****************************************************************************************#
