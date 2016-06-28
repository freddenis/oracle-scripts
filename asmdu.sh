#!/bin/bash
# Fred Denis -- fred.denis3@gmail.com -- June 2016
#
# - If no parameter specified, show a du of each DiskGroup
# - If a parameter, print a du of each subdirectory
#


D=$1


#
# Colored thresholds (Red, Yellow, Green)
#
            CRITICAL=90
             WARNING=75


#
# Set the ASM env
#
OLD_SID=${ORACLE_SID}
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`
export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1


#
# A quick list of what is running on the server
#
ps -ef | grep pmon | grep -v grep | awk '{print $NF}' | sed s'/.*_pmon_//' | egrep "^([+]|[Aa-Zz])" | sort | awk -v H="`hostname -s`" 'BEGIN {printf("%s", "Databases on " H " : ")} { printf("%s, ", $0)} END{printf("\n")}' | sed s'/, $//'


#
# Manage parameters
#
if [[ -z $D ]]
then        # No directory provided, will check all the DG
            DG=`asmcmd lsdg | grep -v State | awk '{print $NF}' | sed s'/\///'`
            SUBDIR="No"                 # Do not show the subdirectories details if no directory is specified
else
            DG=`echo $D | sed s'/\/.*$//g'`
fi


#
# A header
#
printf "\n%25s%16s%16s%14s"          "DiskGroup" "Total_MB" "Free_MB" "% Free"
printf "\n%25s%16s%16s%14s\n"        "---------" "--------" "-------" "------"


#
# Show DG info
#
for X in ${DG}
do
            asmcmd lsdg ${X} | tail -1 |\
                awk -v DG="$X"  -v W="$WARNING" -v C="$CRITICAL" '\
                BEGIN \
                {COLOR_BEGIN =           "\033[1;"                          ;
                   COLOR_END =           "\033[m"                           ;
                         RED =           COLOR_BEGIN"31m"                   ;
                       GREEN =           COLOR_BEGIN"32m"                   ;
                      YELLOW =           COLOR_BEGIN"33m"                   ;
                       COLOR =           GREEN                              ;
                }
                {   FREE = sprintf("%12d", $8/$7*100)                   ;
                    if ((100-FREE) > W)         {COLOR=YELLOW                       ;}
                    if ((100-FREE) > C)         {COLOR=RED                          ;}
                    printf("%25s%16s%16s%s\n", DG, $7, $8, COLOR FREE COLOR_END) ; }'
done
printf "\n"


#
# Subdirs info
#
if [ -z ${SUBDIR} ]
then
(for DIR in `asmcmd ls ${D}`
do
            echo ${DIR} `asmcmd du ${D}/${DIR} | tail -1`
done) | awk -v D="$D" ' BEGIN { printf("\n\t\t%40s\n\n", D " subdirectories size")                  ;
                                    printf("%25s%16s%16s\n", "Subdir", "Used MB", "Mirror MB")          ;
                                    printf("%25s%16s%16s\n", "------", "-------", "---------")          ;}
                            {
                                    printf("%25s%16s%16s\n", $1, $2, $3)        ;
                                    use += $2                                   ;
                                    mir += $3                                   ;
                            }
                            END {   printf("\n\n%25s%16s%16s\n", "------", "-------", "---------")  ;
                                    printf("%25s%16s%16s\n\n", "Total", use, mir)                       ;} '
fi




#************************************************************************#
#*                          E N D          O F          S O U R C E                     *#
#************************************************************************#