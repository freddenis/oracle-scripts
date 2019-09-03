#!/bin/bash
# Fred Denis -- Sept 3rd 2019
#
# Generate the start commands to cwstartstop GG -- do NOT execute it automatically
# To execute it automatically just do ./gg-start.sh | ggsci
#


GGSCI=ggsci

cd $GGHOME

echo "info all"
echo "start mgr"
for R in `echo "info all" | ggsci | grep ^REPLICAT | awk '{print $3}'`
do
        echo "start "${R}
done

echo "info all"

#************************************************************************#
#                       E N D      O F      S O U R C E                 *#
#************************************************************************#
