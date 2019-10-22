#!/bin/bash
# Fred Denis -- Sept 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Generate commands to be able to manage RAC/GI services (relocate, stop, start, enable, disable); please use the -h option for more information
#
# The current script version is 20191022
#
# History:
#
# 20191022 - Fred Denis - No more default output and an error message if none is chosen
# 20190917 - Fred Denis - Option -F to work from a reference file (which should be a rac-status.sh -Luns output)
#                       - Used the -oldinst -newinst syntax for relocate and not currentnode and targetnode which is for policy managed databases
#                       - A -i option to workaround the fact that db_unique_name != db_name and instance_name is built from db_name
# 20190904 - Fred Denis - Initial release
#
#
#       Some default variables
#
  RAC_STATUS="rac-status.sh"            # rac-status.sh script
        ACTION="relocate"               # Default action                (-w)
        FROM=""                         # Node from                     (-f) -- for relocate service
          TO=""                         # Node to                       (-t) -- for relocate service
        NODE=""                         # Node to perform the action    (-n) -- for stop / start / disable / enable
    SHOW_WAY=""                         # Show the actions to performp as per the parameters
 SHOW_RETURN=""                         # Show the opposite actions to be able to come back to the previous situation
  DB_TO_SHOW="."                        # DB to show
  DB_TO_HIDE="nothing_by_default"$$     # DB to hide
 SVC_TO_SHOW="."                        # Service to show
 SVC_TO_HIDE="nothing_by_default"$$     # Service to hide
INSTANCE_PREFIX=""                      # When db_unique_name != db_name to build the instance names
         TMP=/tmp/rac-services$$.tmp    # A tempfile
   FROM_FILE=""                         # File to generate the services commands from a reference file (-F)

#
#       Different OS support
#
OS=`uname`
case ${OS} in
        SunOS)          AWK=`which gawk`                         ;;
        Linux)          AWK=`which awk`                          ;;
        HP-UX)          AWK=`which awk`                          ;;
        AIX)            AWK=`which gawk`                         ;;
        *)              printf "\n\t\033[1;31m%s\033[m\n\n" "Unsupported OS, cannot continue."           ;
                        exit 666                                 ;;
esac
#
#       Be sure we found awk
#
if [[ ! -f ${AWK} ]]
then
        printf "\n\t\033[1;31m%s" "No awk found on your system, cannot continue, if you run Solaris, please ensure that gawk is in your path"
        printf "\t%s\033[m\n\n" ${AWK}
        exit 678
fi
#
#       We need rac-status to be here
#
if [[ ! -f ${RAC_STATUS} && -z ${FILE_FROM} ]]
then
cat << !
        Cannot find ${RAC_STATUS}, please get it from http://bit.ly/2XEXa6j (doc is http://bit.ly/2MFkzDw)
!
        exit 666
fi
#
# Show the version of the script (-V)
#
show_version()
{
        VERSION=`${AWK} '{if ($0 ~ /^# 20[0-9][0-9][0-1][0-9]/) {print $2; exit}}' $0`
        printf "\n\t\033[1;36m%s\033[m\n" "The current version of "`basename $0`" is "$VERSION"."          ;
}
#
# An usage function shows with the -h option
#
usage()
{
printf "\n\033[1;37m%-8s\033[m\n" "NAME"                ;
cat << END
        `basename $0` - A rac-status.sh based script to generate the commands to manage the Oracle services
END

printf "\n\033[1;37m%-8s\033[m\n" "SYNOPSIS"            ;
cat << END
        $0 [-a] [-f] [-t] [-n] [-r] [-R] [-w] [-W] [-V] [-h]
END

printf "\n\033[1;37m%-8s\033[m\n" "DESCRIPTION"         ;
cat << END
        `basename $0` is based on rac-status.sh (which can be downloaded from http://bit.ly/2XEXa6j; doc is http://bit.ly/2MFkzDw)
        `basename $0` needs rac-status.sh version 20190830 minimum
        `basename $0` executes rac-status.sh to get a status of all the services across the RAC/GI and then generate the commands
                      to achieve the action passed in parameter (-a) with a bit of smartness:
                        - relocate: to relocate services from a node (-f) to another node (-t)
                                    - if a service is already running on the target node, we stop it on the source node
                        - stop    : to stop services on a node
                                    - if a service is already stopped we do nothing
                        - start   : to start service on a node
                                    - if a service is already started we do nothing
                                    - if a service is disabled we do not start it
                        - enable  : to enable services on a node
                                    - are enabled only disabled services
                        - disable : to disable services on a node
                                    - are disabled only enabled services
        `basename $0` generates the commands to achieve the action you want as well as the commands to return to the previous situation
        `basename $0` generates commands only and do NOT execute them; if you want to execute them automatically please do:
                        ./`basename $0` <OPTIONS> | bash
                      but be sure to have previously saved the commands go to back to the previous state !
END

printf "\n\033[1;37m%-8s\033[m\n" "OPTIONS"             ;
cat << END
        -a:     Action to generate the commands for, possible values are  : relocate / stop / start / disable / enable

        -f:     Node from       (integer)       -- for relocate service only
        -t:     Node to         (integer)       -- for relocate service only
        -n:     Node            (integer)       -- for stop / start / disable / enable
                The nodes number are expected to be integers (as the columns shown by rac-status.sh)
                ./`basename $0` -a relocate -f 4 -t 6           # Relocate the services from node 4 to node 6
                ./`basename $0` -a stop -n 3                    # Stop the services on node 3

        -i:     Instance prefix when db_unique_name != db_name

        -F:     A file containing a rac-status -Luns output used as a reference

        -w:     Show the commands to achieve what we want to do
        -W:     Hide the commands to achieve what we want to do (handy when you only want the way back commands)
        -r:     Show the commands to return to the original status
        -R:     Hide the commands to return to the original status

        -d:     The DB(s) you want to     show the services (act as a grep    so -d prod would     show the myprod1  and myprod2  databases)
        -D:     The DB(s) you want to NOT show the services (act as a grep -v so -D prod would NOT show the myprod1  and myprod2  databases)
        -s:     The service(s) you want to     show         (act as a grep    so -s bkup would     show the prdbkup1 and prdbkup2 services )
        -S:     The service(s) you want to NOT show         (act as a grep -v so -S bkup would NOT show the prdbkup1 and prdbkup2 services )

        -V:     Shows the version of the script
        -h:     Shows this help
END
        exit 123
}
#
#       Options
#
while getopts "a:n:f:t:F:d:D:s:S:hwWrRVi:" OPT; do
        case ${OPT} in
        f)             FROM=${OPTARG}                                                                   ;;
        t)               TO=${OPTARG}                                                                   ;;
        F)        FILE_FROM=${OPTARG}                                                                   ;;
        a)           ACTION=`echo ${OPTARG} | tr '[:upper:]' '[:lower:]'`                               ;;
        n)             NODE=${OPTARG}                                                                   ;;
        w)         SHOW_WAY="YES"                                                                       ;;
        W)         SHOW_WAY="NO"                                                                        ;;
        r)      SHOW_RETURN="YES"                                                                       ;;
        R)      SHOW_RETURN="NO"                                                                        ;;
        d)       DB_TO_SHOW=${OPTARG}                                                                   ;;
        D)       DB_TO_HIDE=${OPTARG}                                                                   ;;
        s)      SVC_TO_SHOW=${OPTARG}                                                                   ;;
        S)      SVC_TO_HIDE=${OPTARG}                                                                   ;;
        i)  INSTANCE_PREFIX=${OPTARG}                                                                   ;;
        V)      show_version; exit 567                                                                  ;;
        h)         usage                                                                                ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage                                           ;;
        esac
done
#
# Input verification
#
if [[ -z ${SHOW_WAY} ]] && [[ -z ${SHOW_RETURN} ]]
then
        cat << !
        You need to specify the output you want (-w and/or -r).
        Please use -h to show the available options.
!
        exit 278
fi
if ! [[ "${ACTION}" =~ ^(relocate|stop|start|disable|enable)$ ]]
then
        cat << !
        Actions can only be relocate / stop / start / disable / enable; cannot conntinue;
!
        exit 222
fi
if [[ "${ACTION}" == "relocate" ]]
then
        if [[ -z "${FROM}" || -z "${TO}" ]]
        then
                cat << !
                Selected action is ${ACTION}
                A node from and a node to are mandatory, cannot continue.
!
                exit 124
        fi
        if ! [[ "${FROM}" =~ ^[0-9]+$ ]] || ! [[ "${TO}" =~ ^[0-9]+$ ]]
        then
                cat << !
                Selected action is ${ACTION}
                Nodes numbers have to be integers.
!
                exit 125
        fi
        if [[ "${FROM}" == "${TO}" ]]
        then
                cat << !
                Selected action is ${ACTION}
                Source and destination are same, cannot continue.
!
                exit 126
        fi
else    # Then it is stop/start/disbale/enable
        case $ACTION in
        start  )        OPPOSITE="stop"         ;;
        stop   )        OPPOSITE="start"        ;;
        enable )        OPPOSITE="disable"      ;;
        disable)        OPPOSITE="enable"       ;;
        esac

        if ! [[ "${NODE}" =~ ^[0-9]+$ ]]
        then
                cat << !
                Selected action is ${ACTION}
                Node number has to be integers.
!
                exit 127
        fi
fi
if [[ -n ${FILE_FROM} && ! -f ${FILE_FROM} ]]
then
        cat << !
        Cannot find ${FILE_FROM}; cannot continue;
!
        exit 128
fi
#
# Do the job
#
if [[ -n ${FILE_FROM} ]]
then
        cat ${FILE_FROM}      | sed s'/ *//g' > ${TMP}
else
        ./${RAC_STATUS} -Luns | sed s'/ *//g' > ${TMP}
fi

cat ${TMP} |\
        ${AWK} -F "|" -v     FROM="$FROM"     -v TO="$TO"  -v NODE="$NODE"  -v   ACTION="$ACTION"    \
                      -v SHOW_WAY="$SHOW_WAY" -v SHOW_RETURN="$SHOW_RETURN" -v OPPOSITE="$OPPOSITE" -v INSTANCE_PREFIX="$INSTANCE_PREFIX" '\
        BEGIN\
        {       nb_reloc = 1                                            ;
                nb_stop  = 1                                            ;
                      nb = 1                                            ;
                 nb_info = 1                                            ;
                COL_FROM = FROM+2                                       ;       # There are 2 columns before the nodes
                COL_TO   = TO+2                                         ;       # There are 2 columns before the nodes
                COL_NODE = NODE+2                                       ;       # There are 2 columns before the nodes
        }
        function print_header(a_text)
        {
                printf("%s\n",    "#")                                  ;
                printf("%s %s\n", "#", a_text)                          ;
                printf("%s\n",    "#")                                  ;
        }
        #
        # Get a string and return it with a nice case: first character in upper case ad the others in lower case (ABCD => Abcd)
        #
        function nice_case(str)
        {
                return sprintf("%s", toupper(substr(str,1,1)) tolower(substr(str,2,length(str))))               ;
        }
        function show_output()
        {
               if (length(tab_info) > 0)
               {       print_a_tab(tab_info,  "# Disabled services we wont start")                              ;
               }

                if (length(tab_way)>0)
                {       if (SHOW_WAY == "YES")
                        {       print_header("WAY: Services to "nice_case(ACTION))                              ;
                                print_a_tab(tab_way,       "# "nice_case(ACTION)" services on "nodes[NODE])     ;
                        }
                        if (SHOW_RETURN == "YES")
                        {       printf("\n")                                                                    ;
                                print_header("RETURN: Services to "nice_case(OPPOSITE))                         ;
                                print_a_tab(tab_return,    "# "nice_case(OPPOSITE)" services on "nodes[NODE])   ;
                        }
                } else {
                        print_header("There is no service to "ACTION" on "nodes[NODE]".")                       ;
                }
        }
        function gen_srvctl(what)
        {       return sprintf("%s", "srvctl "what" service -db "DB" -service "SERVICE" -instance "INSTANCE_PREFIX NODE)     ;
        }
        function print_a_tab(a_tab, a_text)
        {
                if (length(a_tab) > 0)
                {       printf("%s\n", a_text)                                                                  ;
                        for (i=1; i<=length(a_tab); i++)
                        {
                                printf("%s\n", a_tab[i])                                                        ;
                        }
                }
        }
        {       if ($1 == "DB")
                {       for (i=3; i<=(NF-1); i++)
                        {       nodes[i-2] = $i                                                                 ;
                        }
                }
                if ($0 ~  /----------------/)
                {
                        while (getline)
                        {       if ($0 ~ /----------------/)
                                {       printf("\n")                                                            ;
                                        break                                                                   ;
                                }
                                if ($1 != "")
                                {
                                        DB=$1                                                                   ;
                                        if (INSTANCE_PREFIX == "")
                                        {       INSTANCE_PREFIX = DB                                            ;
                                        }
                                }
                                SERVICE=$2                                                                      ;
                                if (ACTION == "relocate")
                                {
                                        # We relocate the service only if it is Online on the FROM node and not Online on the TO node
                                        if ($COL_FROM ~ /Online/ && $COL_TO !~ /Online/)
                                        {
                                                  reloc[nb_reloc] =  "srvctl relocate service -db "DB" -service "SERVICE" -oldinst "INSTANCE_PREFIX FROM" -newinst "INSTANCE_PREFIX TO     ;
                                             reloc_back[nb_reloc] =  "srvctl relocate service -db "DB" -service "SERVICE" -oldinst "INSTANCE_PREFIX TO" -newinst "INSTANCE_PREFIX FROM     ;
                                                        nb_reloc++                                                                                                              ;
                                        }
                                        # If the service is Online on the FROM node and Online on the TO node then we just stop it on the FROM node
                                        if ($COL_FROM ~ /Online/ && $COL_TO ~ /Online/)
                                        {
                                                stop_svc[nb_stop] = "srvctl stop  service -db "DB" -service "SERVICE" -node "nodes[FROM]                                        ;
                                               start_svc[nb_stop] = "srvctl start service -db "DB" -service "SERVICE" -node "nodes[FROM]                                        ;
                                                         nb_stop++                                                                                                              ;
                                        }
                                }
                                if (ACTION == "stop")                                           # We only stop the started servives
                                {       if ($COL_NODE ~ /Online/)
                                        {       tab_way[nb] = gen_srvctl("stop")                ;
                                             tab_return[nb] = gen_srvctl("start")               ;
                                                        nb++                                    ;
                                        }
                                }
                                if (ACTION == "start")
                                {       if ($COL_NODE !~ /Online/)
                                        {       if ($COL_NODE ~ /x/)                            # A disabled service so we wont start it
                                                {       info[nb_info] = "# Service "SERVICE" is disabled on node "nodes[NODE]" so we wont start it."    ;
                                                             nb_info++                          ;
                                                } else {
                                                        tab_way[nb] = gen_srvctl("start")       ;
                                                     tab_return[nb] = gen_srvctl("stop")        ;
                                                                nb++                            ;
                                                }
                                        }
                                }
                                if (ACTION == "enable")
                                {       if ($COL_NODE ~ /x/)                                    # We only enable the disabled services
                                        {       tab_way[nb] = gen_srvctl("enable")              ;
                                             tab_return[nb] = gen_srvctl("disable")             ;
                                                        nb++                                    ;
                                        }
                                }
                                if (ACTION == "disable")
                                {       if ($COL_NODE !~ /x/)                                   # We only disable the enabled services
                                        {       tab_way[nb] = gen_srvctl("disable")             ;
                                             tab_return[nb] = gen_srvctl("enable")              ;
                                                        nb++                                    ;
                                        }
                                }
                        }
                }
        } END\
        {       # Show the generated commands
                if (ACTION == "relocate")
                {       if ((length(reloc)>0) || (length(stop_svc)>0))
                        {       if (SHOW_WAY == "YES")
                                {       print_header("WAY: Services to relocate / stop")                                                                ;
                                        print_a_tab(reloc,      "# Relocate services from "nodes[FROM]" to "nodes[TO]                           )       ;
                                        print_a_tab(stop_svc,   "# Stop services on "nodes[FROM]" as they are already Online on "nodes[TO]      )       ;
                                }
                                if (SHOW_RETURN == "YES")
                                {       printf("\n")                                                                                                    ;
                                        print_header("RETURN: Services to relocate back / start")
                                        print_a_tab(reloc_back, "# Relocate services back to "nodes[FROM]" from "nodes[TO]                      )       ;
                                        print_a_tab(start_svc,  "# Restart services on "nodes[FROM]" after they have been stopped"              )       ;
                                }
                        } else {
                                print_header("There is no service to relocate or stop on "nodes[FROM]", they are already all up on node "nodes[TO]" and/or stopped on node "nodes[FROM]".")     ;
                        }
                } else {
                        show_output()                                                                                                                   ;
                }
        } ' | ${AWK} -v DB_TO_SHOW="$DB_TO_SHOW" -v SVC_TO_SHOW="$SVC_TO_SHOW"\
                     -v DB_TO_HIDE="$DB_TO_HIDE" -v SVC_TO_HIDE="$SVC_TO_HIDE"\
                       '{       if ($1 == "srvctl")
                                {
                                        SVC_GREP = "-service .*"SVC_TO_SHOW".*";
                                      SVC_UNGREP = "-service .*"SVC_TO_HIDE".*";
                                         DB_GREP = "-db .*"DB_TO_SHOW".*";
                                       DB_UNGREP = "-db .*"DB_TO_HIDE".*";
                                        if (($0 ~ SVC_GREP) && ($0 ~ GREP) && ($0 !~ SVC_UNGREP) && ($0 !~ DB_UNGREP))
                                        {       print $0        ;
                                        }
                                } else {
                                        print $0        ;
                                }
                      }'

# Delete tempfile
if [[ -f ${TMP} ]]
then
        rm -f ${TMP}
fi

#****************************************************************************************#
#*                              E N D      O F      S O U R C E                         *#
#****************************************************************************************#
