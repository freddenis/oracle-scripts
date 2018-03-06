#!/bin/bash
#
# Fred Denis -- denis@pythian.com -- March 2018 -- CR 1186213
# Print a nice output of the log management logfiles
#

FILE=$1

if [ -z ${FILE} ]
then
	cat << !
	A logfile is needed, please provide one, cannot continue.
!
	exit 123
fi

if [ ! -f ${FILE} ]
then
	cat << !
	${FILE} does not exists, cannot continue.
!
	exit 345
fi


#grep -e "Step" -e "^Elapsed" ${FILE} | sed s'/^.*>//g' |\
cat ${FILE} | sed s'/^.*>//g' |\
	awk -v FILE="${FILE}" '  	BEGIN {FS=":"; printf("\n\t%s\n", FILE)	; printf("\t");for (k=1; k<=80; k++) {printf("%s", "-");}; printf("\n");}
		{	if ($1 ~ /Step/)
			{	STEP=$0	;
				printf ("\t%-35s\t:", $0)	;
				while(getline)
				{	if ($1 ~ /Elapsed/)
					{
						sub("Elapsed:", "", $0)	;
						printf ("%s\n", $0)	;
						break				;
					}
				}
			}
			if ($1 ~ /Log management already running/)
			{
				printf ("\t%s\n", $0)	;
			}
		}
		END { printf("\n\n");}'

