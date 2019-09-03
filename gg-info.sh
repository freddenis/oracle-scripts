#!/bin/bash
#
# Fred Denis -- Sept 3rd 2019
#
# Check GG infos
#

GGSCI=ggsci
cd $GGHOME

(echo "info all"
for R in `echo "info all" | ggsci | grep ^REPLICAT | awk '{print $3}'`
do
        echo "info "${R}" detail showch"
        echo "send "${R}" status"
        echo "send "${R}" logend"
        echo "lag  "${R}
done) | ggsci

#************************************************************************#
#                       E N D      O F      S O U R C E                 *#
#************************************************************************#
