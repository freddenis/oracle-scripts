#!/bin/bash
# Fred Denis -- Sept 16th 2019 
#
# A quick RMAN backup script (oraenv has to work)
#
# The version of the script is 20190916
#
# History
# 20190916 - Fred Denis - Initial Release
#

. ~/.bash_profile > /dev/null 2>&1

BACKUP_TYPE="database"                  # Default backup type (-t)
      LEVEL=0                           # Default incremental backup level
 ORACLE_SID=""                          # Default database to backup (should match oratab)
     ORATAB="/etc/oratab"               # oratab
     A_DATE=$(date +%Y%m%d_%H%M%S)      # A timestamp
        LOG=`dirname $0`/logs
if [[ ! -d ${LOG} ]]
then
        mkdir -p ${LOG}
fi
#
# Show the version of the script (-V)
#
show_version()
{
        VERSION=`awk '{if ($0 ~ /^# 20[0-9][0-9][0-1][0-9]/) {print $2; exit}}' $0`
        printf "\n\t\033[1;36m%s\033[m\n\n" "The current version of "`basename $0`" is "$VERSION"."          ;
}
#
# An usage function
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                                        ;
cat << END
        `basename $0` - A RMAN database backup
END
printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"                                    ;
cat << END
        $0 [-d] [-t] [-l] [-V] [-h]
END
printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"                                    ;
cat << END
        -d      Database to backup (should match oratab)
        -t      Bakcup type: database or archivelog
        -l      Incremental backup level
        -V      Show the version
        -h      Shows this help

END
exit 123
}
while getopts "t:d:l:Vh" OPT; do
        case ${OPT} in
        d)       ORACLE_SID="${OPTARG}"                                 ;;
        t)      BACKUP_TYPE="${OPTARG}"                                 ;;
        l)            LEVEL="${OPTARG}"                                 ;;
        V)      show_version; exit 555                                  ;;
        h)         usage                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage           ;;
        esac
done
if [[ $BACKUP_TYPE != @(database|archivelog) ]]
then
        printf "\n\t\033[1;31m%s\033[m\n\n" "Supported backup types are database or archivelog, cannot continue."       ;
        exit 124                                ;
fi
if [[ -z "${ORACLE_SID}" ]]
then
        printf "\n\t\033[1;31m%s\033[m\n\n" "A database name to backup is mandatory, cannot continue."                  ;
        exit 125                                ;
fi
if ! [[ $(grep $ORACLE_SID $ORATAB) ]]
then
        printf "\n\t\033[1;31m%s\033[m\n\n" "The given database "$ORACLE_SID" does not match "$ORATAB", cannot continue.";
        exit 126
fi
if ! [[ "${LEVEL}" =~ ^[0-9]+$ ]]
then
        printf "\n\t\033[1;31m%s\033[m\n\n" "Backup level has to be a positive integer, cannot continue.";
        exit 127
fi

case $BACKUP_TYPE in
database)
        COMMAND="backup incremental level $LEVEL database plus archivelog delete input"         ;
        LOGFILE=${LOG}/rman_backup_${A_DATE}_${BACKUP_TYPE}_level${LEVEL}.log                   ;;
archivelog)
        COMMAND="backup archivelog all delete input"                                            ;
        LOGFILE=${LOG}/rman_backup_${A_DATE}_${BACKUP_TYPE}.log                                 ;;
esac
. oraenv <<< $ORACLE_SID > /dev/null 2>&1

export NLS_DATE_FORMAT="DD/MM/YYYY HH24:MI:SS"
rman target / << END_RMAN       | tee $LOGFILE
$COMMAND                        ;
delete noprompt obsolete        ;
END_RMAN

echo $LOGFILE

#************************************************************************#
#*                      E N D      O F       S O U R C E                *#
#************************************************************************#
