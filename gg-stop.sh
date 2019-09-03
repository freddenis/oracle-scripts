#!/bin/bash
# Fred Denis -- Sept 3rd 2019
#
# Generate the stop command to stop GG -- do NOT execute it automatically
# To execute it automatically just do ./gg-stop.sh | gssci
#


GGSCI=ggsci

cd $GGHOME

echo "info all"
for R in `echo "info all" | ggsci | grep ^REPLICAT | awk '{print $3}'`
do
        echo "stop "${R}
done

echo "stop mgr"
echo "info all"

#************************************************************************#
#                       E N D      O F      S O U R C E                 *#
#************************************************************************#
