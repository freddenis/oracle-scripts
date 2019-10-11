#!/bin/bash
# Fred Denis -- Oct 2019 -- http://unknowndba.blogspot.com -- fred.denis3@gmail.com
#
# Show a status of the backups of the databases running on an OCI server
#
# Dev

N=4

for X in `dbcli list-databases | tac | awk '{if ($1 ~ /^--------/) {exit;} else {print $2;}}' | sort`
do
        dbcli list-jobs | grep -i $X | tail -$N |\
        awk -v DB="$X" 'BEGIN {failed=0;}
                        {       if ($0 ~ /Failure/)
                                {
                                        "dbcli describe-job -i "$1 " | grep Message " | getline err             ;
                                        sub(/^ *Message:/, "", err);
                                        printf("\033[1;36m%s\033[m\n", "=>" err)        ;
                                        printf("\033[1;31m%s\033[m\n", $0)      ;
                                        failed++                                ;
                                } else 
                                {       print $0                                ;
                                }
                        } END\
                        {       for (i=1;i<=80;i++)
                                {       printf("\033[1;37m%s\033[m", "-")       ;
                                }
                                printf("\n")                                    ;
                                printf("\033[1;37m%s\033[m", "*** " DB " backup jobs *** -- ")              ;
                                printf("\033[1;31m%s\033[m\n", failed " failures"  )    ;
                        }' | tac
done


#********************************************************************************************************#
#                               E N D     O F      S O U R C E                                          *#
#********************************************************************************************************#
