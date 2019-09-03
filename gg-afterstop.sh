#!/bin/bash
# Fred Denis -- Sept 3rd 2019
#
# Check that GG is well stopped
#


ps -ef | grep ggs
fuser -v $GGHOME
ls -ltr $GGHOME/dirpcs/

printf "\n\t\033[1;31m%s\033[m\n\n" "There should be no pcr file remaining, delete them if there are still some."

#************************************************************************#
#                       E N D      O F      S O U R C E                 *#
#************************************************************************#
