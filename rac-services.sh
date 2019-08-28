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
                A node from and a node to are mandatory, cannot continue.
!
                exit 124
        fi
        if ! [[ "${FROM}" =~ ^[0-9]+$ ]] || ! [[ "${TO}" =~ ^[0-9]+$ ]]
        then
                cat << !
                Nodes numbers have to be integers.
!
                exit 125
        fi
        if [[ "${FROM}" == "${TO}" ]]
        then
                cat << !
                Source and destination are same, cannot continue.
!
                exit 126
        fi
else    # Then it is stop/start/disbale/enable
        if ! [[ "${NODE}" =~ ^[0-9]+$ ]]
        then
                cat << !
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
                                                reloc[nb_reloc] =  "srvctl relocate service -db "DB" -service "SERVICE" -currentnode "nodes[FROM]" -targetnode "nodes[TO]       ;
                                           reloc_back[nb_reloc] =  "srvctl relocate service -db "DB" -service "SERVICE" -currentnode "nodes[TO]  " -targetnode "nodes[FROM]     ;
                                                nb_reloc++                      ;
                                        }
                                        # If the service is Online on the FROM node and Online on the TO node then we just stop it on the FROM node
                                        if ($COL_FROM ~ /Online/ && $COL_TO ~ /Online/)
                                        {
                                                stop_svc[nb_stop] = "srvctl stop  service -db "DB" -service "SERVICE" -node "nodes[FROM]                                        ;
                                               start_svc[nb_stop] = "srvctl start service -db "DB" -service "SERVICE" -node "nodes[FROM]                                        ;
                                                nb_stop++                       ;
                                        }
                                }
                                if (WHAT == "stop")
                                {       if ($COL_NODE ~ /Online/)
                                        {
                                                print "srvctl "WHAT" service -db "DB" -service "SERVICE" -node "nodes[NODE]                                                             ;
                                        }
                                }
                        }
                }
        } END\
        {
                if (length(reloc) > 0)
                {       printf("%s\n", "# Relocate services from "nodes[FROM]" to "nodes[TO])                           ;
                        for (i=1; i<=nb_reloc; i++)
                        {
                                printf("%s\n", reloc[i])        ;
                        }
                }

                if (length(stop_svc) > 0)
                {       printf("%s\n", "# Stop services on "nodes[FROM]" as they are already Online on "nodes[TO])      ;
                        for (i=1; i<=nb_stop; i++)
                        {
                                printf("%s\n", stop_svc[i])     ;
                        }
                }

                if (length(reloc_back) > 0)
                {       printf("%s\n", "# Relocate services back to "nodes[FROM]" from "nodes[TO])                       ;
                        for (i=1; i<=nb_reloc; i++)
                        {
                                printf("%s\n", reloc_back[i])        ;
                        }
                }

                if (length(start_svc) > 0)
                {       printf("%s\n", "# Restart services on "nodes[FROM]" after they have been stopped")              ;
                        for (i=1; i<=nb_stop; i++)
                        {
                                printf("%s\n", start_svc[i])     ;
                        }
                }

        } '

#****************************************************************************************#
#*                              E N D      O F      S O U R C E                         *#
#****************************************************************************************#
