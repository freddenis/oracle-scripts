#!/bin/bash
# Fred Denis - Aug 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Manage RAC services; use -h option for help
#
# The current script version is in dev
#
# History:
# . . .
#

  RAC_STATUS="rac-status.sh"            # rac-status.sh script
        WHAT="relocate"                 # Default action                (-w)
        FROM=""                         # Node from                     (-f) -- for relocate service
          TO=""                         # Node to                       (-t) -- for relocate service
        NODE=""                         # Node to perform the action    (-n) -- for stop / start / disable / enable

if [[ ! -f ${RAC_STATUS} ]]
then
cat << !
        Cannot find ${RAC_STATUS}, please get it from http://bit.ly/2XEXa6j (doc is http://bit.ly/2MFkzDw)
!
        exit 666
fi

usage()
{
        cat << !
        -w:     What to do, possible values are  :
                        relocate / stop / start / disable / enable

        -f:     Node from       (integer)       -- for relocate service
        -t:     Node to         (integer)       -- for relocate service
        -n:     Node            (integer)       -- for stop / start / disable / enable

        -h:     Shows this help
!
        exit 123
}

# Options
while getopts "w:n:f:t:h" OPT; do
        case ${OPT} in
        f)      FROM=${OPTARG}                                                                  ;;
        t)        TO=${OPTARG}                                                                  ;;
        w)      WHAT=`echo ${OPTARG} | tr '[:upper:]' '[:lower:]'`                              ;;
        n)      NODE=${OPTARG}                                                                  ;;
        h)         usage                                                                        ;;
        \?)        echo "Invalid option: -$OPTARG" >&2; usage                                   ;;
        esac
done

if ! [[ "${WHAT}" =~ ^(relocate|stop|start|disable|enable)$ ]]
then
        cat << !
        Actions can only be relocate / stop / start / disable / enable; cannot conntinue;
!
        exit 222
fi

if [[ "${WHAT}" == "relocate" ]]
then
        if [[ -z "${FROM}" || -z "${TO}" ]]
        then
                cat << !
                Selected action is ${WHAT}
                A node from and a node to are mandatory, cannot continue.
!
                exit 124
        fi
        if ! [[ "${FROM}" =~ ^[0-9]+$ ]] || ! [[ "${TO}" =~ ^[0-9]+$ ]]
        then
                cat << !
                Selected action is ${WHAT}
                Nodes numbers have to be integers.
!
                exit 125
        fi
        if [[ "${FROM}" == "${TO}" ]]
        then
                cat << !
                Selected action is ${WHAT}
                Source and destination are same, cannot continue.
!
                exit 126
        fi
else    # Then it is stop/start/disbale/enable
        if ! [[ "${NODE}" =~ ^[0-9]+$ ]]
        then
                cat << !
                Selected action is ${WHAT}
                Node number has to be integers.
!
                exit 127
        fi
fi

./${RAC_STATUS} -Luns | sed s'/ *//g' |\
        awk -F "|" -v FROM="$FROM" -v TO="$TO" -v WHAT="$WHAT" -v NODE="$NODE" '\
        BEGIN\
        {       nb_reloc = 1                                            ;
                nb_stop  = 1                                            ;
                COL_FROM = FROM+2                                       ;       # There are 2 columns before the nodes
                COL_TO   = TO+2                                         ;       # There are 2 columns before the nodes
                COL_NODE = NODE+2                                       ;       # There are 2 columns before the nodes
        }
        function print_a_tab(a_tab, a_counter, a_text)
        {
                if (length(a_tab) > 0)
                {       printf("%s\n", a_text)                          ;
                        for (i=1; i<=a_counter; i++)
                        {
                                printf("%s\n", a_tab[i])                ;
                        }
                }
        }
        {       if ($1 == "DB")
                {       for (i=3; i<=(NF-1); i++)
                        {       nodes[i-2] = $i                         ;
                        }
                }
                if ($0 ~  /----------------/)
                {
                        while (getline)
                        {       if ($0 ~ /----------------/)
                                {       printf("\n")                    ;
                                        break                           ;
                                }
                                if ($1 != "")
                                {
                                        DB=$1                           ;
                                }
                                SERVICE=$2                              ;
                                if (WHAT == "relocate")
                                {
                                        # We relocate the service only if it is Online on the FROM node and not Online on the TO node
                                        if ($COL_FROM ~ /Online/ && $COL_TO !~ /Online/)
                                        {
                                                  reloc[nb_reloc] =  "srvctl relocate service -db "DB" -service "SERVICE" -currentnode "nodes[FROM]" -targetnode "nodes[TO]     ;
                                             reloc_back[nb_reloc] =  "srvctl relocate service -db "DB" -service "SERVICE" -currentnode "nodes[TO]  " -targetnode "nodes[FROM]   ;
                                                nb_reloc++                                                                                                                      ;
                                        }
                                        # If the service is Online on the FROM node and Online on the TO node then we just stop it on the FROM node
                                        if ($COL_FROM ~ /Online/ && $COL_TO ~ /Online/)
                                        {
                                                stop_svc[nb_stop] = "srvctl stop  service -db "DB" -service "SERVICE" -node "nodes[FROM]                                        ;
                                               start_svc[nb_stop] = "srvctl start service -db "DB" -service "SERVICE" -node "nodes[FROM]                                        ;
                                                nb_stop++                                                                                                                       ;
                                        }
                                }
                                if (WHAT == "stop")
                                {       if ($COL_NODE ~ /Online/)
                                        {
                                                stop_svc[nb_stop] = "srvctl stop  service -db "DB" -service "SERVICE" -node "nodes[NODE]                                        ;
                                               start_svc[nb_stop] = "srvctl start service -db "DB" -service "SERVICE" -node "nodes[NODE]                                        ;
                                                nb_stop++                                                                                                                       ;
                                        }
                                }
                                if (WHAT == "start")
                                {       if ($COL_NODE !~ /Online/)
                                        {
                                               start_svc[nb_stop] = "srvctl start service -db "DB" -service "SERVICE" -node "nodes[NODE]                                        ;
                                                stop_svc[nb_stop] = "srvctl stop  service -db "DB" -service "SERVICE" -node "nodes[NODE]                                        ;
                                                nb_stop++                                                                                                                       ;
                                        }
                                }
                        }
                }
        } END\
        {
                if (WHAT == "relocate")
                {       print_a_tab(reloc,      nb_reloc,       "# Relocate services from "nodes[FROM]" to "nodes[TO]                           )       ;
                        print_a_tab(stop_svc,   nb_stop,        "# Stop services on "nodes[FROM]" as they are already Online on "nodes[TO]      )       ;
                        print_a_tab(reloc_back, nb_reloc,       "# Relocate services back to "nodes[FROM]" from "nodes[TO]                      )       ;
                        print_a_tab(start_svc,  nb_stop,        "# Restart services on "nodes[FROM]" after they have been stopped"              )       ;
                }
                if (WHAT == "stop")
                {       print_a_tab(stop_svc,   nb_stop,        "# Stop services on "nodes[NODE]                                                )       ;
                        print_a_tab(start_svc,  nb_stop,        "# Restart services on "nodes[NODE]                                             )       ;
                }
                if (WHAT == "start")
                {       print_a_tab(start_svc,  nb_stop,        "# Start services on "nodes[NODE]                                               )       ;
                        print_a_tab(stop_svc,   nb_stop,        "# Stop services on "nodes[NODE]                                                )       ;
                }
        } '

#****************************************************************************************#
#*                              E N D      O F      S O U R C E                         *#
#****************************************************************************************#
