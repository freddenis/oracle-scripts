#!/bin/bash
# Fred Denis -- Nov 2017 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# An Exadata version summary (https://unknowndba.blogspot.com/2018/04/exa-versionssh-exadata-components.html):
# -- has to be run as root
# -- the server where this script is started should have the root ssh  keys deployed on all the other servers (DB Nodes, Cells and IB Swicthes)
# -- see the usage fonction and/or use the -h option for a complete description
# -- For Cells and DB servers (I found no equivalent for the IB swicthes), I also check the status of the image
#    from the imageinfo command as it can be "failure" even if the good version is shown;
#    I then use a piece of awk to format the "imageinfo -ver -status" output like this :
#      node1:12.2.1.1.3.171017:success
#      node2:12.2.1.1.3.171017:failure    <= a failure status when the good version shown
#      node3:12.2.1.1.3.171017:success
#      node4:12.2.1.1.3.171017:success
#    If a DB servers or cell has a status = failure returned by the imageinfo command, the host will appear
#    in red and a note about this will be shown at the end of the report
#
#
# The current version of the script is 20190528
#
# 20190528 - Fred Denis - Fixed a bug on the headers
# 20190524 - Fred Denis - Better management of the naming of the hosts, cells and IB
# 20180913 - Fred Denis - Add the status = failure information for the Cells and DB Servers
#

#
# Variables
#

DBMACHINE=/opt/oracle.SupportTools/onecommand/databasemachine.xml       # File where we should find the Exadata model

   SHOW_ALL="Yes"
   SHOW_DBS="No"
 SHOW_CELLS="No"
   SHOW_IBS="No"
NB_PER_LINE=$(bc <<< "`tput cols`/22")          # Number of element to print per line
                                                #       -- default adapts to the size of the screen (thanks to tput)
                                                #       -- can be changed at script execution with the -n option

#
# usage function
#

usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                        ;
cat << END
        exa_versions.sh - Show a nice summary of the versions of each component of an Exadata stack
                          (DB servers, Cells and InfiniBand Switches)
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"                    ;
cat << END
        $0 [-d] [-c] [-i] [-n] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"                 ;
cat << END
        $0 needs to be executed as root and the ssh keys to each Exadata component have to be deployed
        With no option $0 will show the versions of all the Exadata components (DB servers, Cells and IB)

        $0 relies on the ibhosts ad the ibswitches commands to find the list of nodes to look at, not on any static [dbs|cell|ib]_group file
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"                     ;
cat << END
        -d      Show the Database servers versions
        -c      Show the Cells (storage servers) versions
        -i      Show the Infiniband Switches versions

        -n      Number of nodes to show per line (default adapts the output to the current screen size)

        -h      Show this help

END
exit 123
}

#
# Options management
#
while getopts "dcin:h" OPT; do
        case ${OPT} in
        d)         SHOW_ALL="No"; SHOW_DBS="Yes"                ;;
        c)         SHOW_ALL="No"; SHOW_CELLS="Yes"              ;;
        i)         SHOW_ALL="No"; SHOW_IBS="Yes"                ;;
        n)      NB_PER_LINE=${OPTARG}                           ;;
        h)      usage                                           ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage          ;;
        esac
done

#
# Few tempfiles
#
         DBS_GROUP=/tmp/dbsgroup$$.tmp
        CELL_GROUP=/tmp/cellgroup$$.tmp
          IB_GROUP=/tmp/ibgroup$$.tmp

#
# Set the ASM env to be able to use some commands (future use)
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1


#
# Show the Exadata model if possible
#
if [ -f ${DBMACHINE} ] && [ -r ${DBMACHINE} ]
then
        cat << !

                Cluster is a `grep -i MACHINETYPES ${DBMACHINE} | sed s'/\t*//' | sed -e s':</*MACHINETYPES>::g' -e s'/^ *//' -e s'/ *$//'`

!
else
        printf "\n"
fi


#
# Fill the tempfiles
#
        ibhosts | grep db  | grep -v cel | sed s'/"//g' | awk '{print $6}'  > ${DBS_GROUP}
        ibhosts | grep cel | sed s'/"//g' | awk '{print $6}'  > ${CELL_GROUP}
        ibswitches                        | awk '{print $10}' > ${IB_GROUP}


( if [[ "$SHOW_DBS" == "Yes" ]] || [[ "$SHOW_ALL" == "Yes" ]]
  then
        dcli -g ${DBS_GROUP} -l root "imageinfo -ver -status" | sort | awk -F ": " '{if(node==""){node=$1}; if($2 != "") {status=$3; getline; printf ("%s:%s:%s:%s\n","db", node, $3, status);  node="" ;}}'
        echo ""
  fi
  if [[ "$SHOW_CELLS" == "Yes" ]] || [[ "$SHOW_ALL" == "Yes" ]]
  then
        dcli -g ${CELL_GROUP} -l root "imageinfo -ver -status" | grep "Active" | sort | awk -F ": " '{if(node==""){node=$1}; if($2 != "") {status=$3; getline; printf ("%s:%s:%s:%s\n","cel", node, $3, status);  node="" ;}}'
        echo ""
  fi
  if [[ "$SHOW_IBS" == "Yes" ]] || [[ "$SHOW_ALL" == "Yes" ]]
  then
        dcli -g ${IB_GROUP}  -l root version | grep -v BIOS | grep "version:" | awk '{print "ib:", $1, $NF}' | sort
        echo ""
  fi
)\
        | awk -v NB_PER_LINE="$NB_PER_LINE" ' BEGIN \
                {             FS =      ":"                                                                             ;
                  # some colors
                     COLOR_BEGIN =      "\033[1;"                                                                       ;
                       COLOR_END =      "\033[m"                                                                        ;
                             RED =      "31m"                                                                           ;
                           GREEN =      "32m"                                                                           ;
                          YELLOW =      "33m"                                                                           ;
                            BLUE =      "34m"                                                                           ;
                            TEAL =      "36m"                                                                           ;
                           WHITE =      "37m"                                                                           ;

                  # Columns size
                        COL_SIZE =      20                                                                              ;

                  # Some variables
                        nb_node  =      0                                                                               ;
                        FAILURES =      0                                                                               ;
                }
                function print_a_line(size)
                {
                        printf("%s", COLOR_BEGIN WHITE)                                                                 ;
                        for (k=1; k<=size;k++) {printf("%s", "-");}                                                     ;
                        printf("%s", COLOR_END"\n")                                                                     ;
                }
                #
                # A function to center the outputs with colors
                #
                function center(str, n, color)
                {       right = int((n - length(str)) / 2)                                                              ;
                         left = n - length(str) - right                                                                 ;
                        return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END, "", str, "" )             ;
                }
                {       if ($0 !~ /^$/)
                        {
                                            nb_node++                                                                   ;
                                               type = $1                                                                ;
                                   db_node[nb_node] = $2                                                                ;
                                db_version[nb_node] = $3                                                                ;
                                 db_status[nb_node] = $4                                                                ;

                                while (getline)
                                {
                                        if ($0 ~ /^$/)
                                        {
                                                # A Header
                                                if (type == "db")      {printf("%s\n", center("-- Database Servers",         40,RED))};
                                                if (type == "cel")     {printf("%s\n", center("-- Cells",                    30,RED))};
                                                if (type == "ib")      {printf("%s\n", center("-- Infiniband Switches",      40,RED))};
                                                printf("\n")                                                            ;
                                                version_ref = db_version[1]                                             ;

                                                for (a=0; a<nb_node; a+=NB_PER_LINE)
                                                {
                                                        nb_printed = 0                                                  ;

                                                        # Print the node names
                                                        for (i=a+1; i<=a+NB_PER_LINE; i++)
                                                        {
                                                                COLOR=WHITE                                             ;
                                                                if(db_status[i] == "failure") {COLOR=RED; FAILURES=1}   ;
                                                                if (length(db_node[i]) > 0)
                                                                {
                                                                        printf("%s", center(db_node[i],COL_SIZE,COLOR)) ;
                                                                        nb_printed++                                    ;
                                                                }
                                                        }

                                                        printf("\n")                                                    ;
                                                        print_a_line(COL_SIZE*nb_printed+NB_TO_SHOW)                    ;

                                                        # Print the nodes versions
                                                        for (i=a+1; i<=a+NB_PER_LINE; i++)
                                                        {
                                                                if (length(db_version[i]) > 0)
                                                                {
                                                                        if (db_version[i] == version_ref)
                                                                        {       A_COLOR=BLUE                            ;
                                                                        }
                                                                        else
                                                                        {
                                                                                A_COLOR=TEAL                            ;
                                                                        }
                                                                        printf("%s", center(db_version[i],COL_SIZE,A_COLOR));
                                                                }
                                                        }
                                                        printf("\n")                                                    ;
                                                        print_a_line(COL_SIZE*nb_printed+NB_TO_SHOW)                    ;
                                                        printf("\n\n")                                                  ;
                                                }       # END  for (a=0; a<nb_node; a+=NB_PER_LINE)

                                                nb_node = 0                                                             ;
                                                delete db_node                                                          ;
                                                delete db_version                                                       ;
                                                delete db_status                                                        ;
                                                break                                                                   ;
                                        }       # END if ($0 ~ /^$/)

                                                  nb_node++                                                             ;
                                           db_node[nb_node] = $2                                                        ;
                                        db_version[nb_node] = $3                                                        ;
                                         db_status[nb_node] = $4                                                        ;
                                }       # END while (getline)
                        }       # END  if ($0 !~ /^$/)
                } END { if (FAILURES == 1)
                        {       printf("%s\n\n", "Note : Please investigate the hosts in red as they have a status = failure returned by the imageinfo command.")       ;
                        }
                }'

# Delete tempfiles

if [ -f ${DBS_GROUP} ]  ; then rm -f ${DBS_GROUP}       ; fi
if [ -f ${CELL_GROUP} ] ; then rm -f ${CELL_GROUP}      ; fi
if [ -f ${IB_GROUP} ]   ; then rm -f ${IB_GROUP}        ; fi


#*******************************************************************************************************#
#                               E N D     O F      S O U R C E                                          #
#*******************************************************************************************************#
