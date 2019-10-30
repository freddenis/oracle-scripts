#!/bin/bash
# Fred Denis -- Oct 30th 2019
#
# Increment dates from a start date till today , show dates and microseconds
# Increment can be specified like 1year, 1year+1week+1day
#

START_DATE="Jan 1 00:00:00 2010"                        # Default start date we execute the SQLs
      INCR="1year"                                      # Default increment when excuting

if [[ -n $1 ]]
then
        INCR=$1
fi
if [[ -n $2 ]]
then
        START_DATE=$2
fi
echo "Date increment is "$INCR
echo "Start date is     "$START_DATE

 FROM_MIC=$(date -d "$START_DATE" "+%s%6N")
if [ $? -ne 0 ]         # Verify that the date format is good
then
        cat << !
        Date format has to be like :
        Jan 1 00:00:00 2010
!
        exit
fi
    TO_MIC=$FROM_MIC
   NOW_MIC=$(date "+%s%6N")

while [ ${TO_MIC} -lt ${NOW_MIC} ]
do
       # Dates in "Jan 1 00:00:00 2010" format
        FROM=$(date --date "$(date -d @$((${FROM_MIC}/1000000))     "+%b %d %T %Y")"           "+%b %d %T %Y"   )
          TO=$(date --date "$(date -d @$(((${FROM_MIC}-1)/1000000)) "+%b %d %T %Y") + ${INCR}" "+%b %d %T %Y"   )

        # Dates microseconds
    FROM_MIC=$(date --date "$FROM" "+%s%6N")
      TO_MIC=$(date --date "$(date -d @$((${FROM_MIC}/1000000))     "+%b %d %T %Y") + ${INCR}" "+%s%6N"         )
      TO_MIC=$((${TO_MIC}-1))

        if [ "$TO_MIC" -gt "$NOW_MIC" ]
        then
            TO_MIC=$NOW_MIC
                TO=$(date --date "$(date -d @$((${TO_MIC}/1000000)) "+%b %d %T %Y")"           "+%b %d %T %Y"   )
        fi
        echo "from:"$FROM":"$TO":"$FROM_MIC":"${TO_MIC}
        # New FROM_MIC
        FROM_MIC=$(date --date "$(date -d @$((${FROM_MIC}/1000000)) "+%b %d %T %Y") + ${INCR}" "+%s%6N"         )
done

