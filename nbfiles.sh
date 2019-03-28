#!/bin/bash
# Fred Denis -- March 2018
# Show number of files and size per day in a directory
#

    DIR="/u01/app/oracle/admin/floltp/adump"
    DIR="/opt/oracle/admin/mov001/adump"
    DIR="/opt/oranfs/export/diskonly"
PATTERN="*.aud"
PATTERN="*"
  EMAIL="denis@pythian.com"
    OUT="nbfilesout$$.png"
        echo $OUT

 TMP=/tmp/nbfilestemp$$
TMP2=/tmp/nbfilestemp2$$

GNUPLOT=`which gnuplot`
#GNUPLOT=""

find ${DIR} -type f -name "${PATTERN}" -printf '%TY-%Tm-%Td %s\n' |\
        awk ' {         tab[$1]+=$2                                                     ;
                        tab2[$1]++                                                      ;
              }
             END {      n=asorti(tab, tab_sorted)                                       ;
                        for (i=1; i<=n; i++)
                        {
                                          x =tab_sorted[i]                              ;       # For code visibility
                                        sum+=tab[x]/1024/1024                           ;
                                total_files+=tab2[x]                                    ;

                                printf("%12s%8d%12d\n", x, tab[x]/1024/1024, tab2[x])   ;

                        }
                        printf("%12s%8d%12d\n", "Total", sum, total_files)              ;
                }
            ' > ${TMP}

if [[ -n ${GNUPLOT} ]]
then
        echo "lets graph"
        cat ${TMP} | grep -v "Total" > ${TMP2}
        cat $TMP2
        gnuplot << END
                set term png
                set output "${OUT}"
                set timefmt "%Y-%m-%d"
                set xdata time
                set ytics
                set ylabel 'MB'
                set y2tics
                set y2label 'Nb files'
                plot '${TMP2}' using 1:2 axes x1y1 with lines title 'MB' smooth cspline,\
                 '' using 1:3 axes x1y2 with lines title 'Nb files' smooth cspline
END
else
        printf "%-12s%8s%12s\n" "   Date" "   MB" "     Nb Files "                              ;
        cat ${TMP}
fi


#,goryunov@pythian.com
sendmail -t <<EOT
TO:denis@pythian.com
FROM:root@tamans124.com
Subject:${DIR}|${PATTERN}
MIME-Version: 1.0
Content-Type: multipart/related;boundary="XYZ"

--XYZ
Content-Type: text/html; charset=ISO-8859-15
Content-Transfer-Encoding: 7bit

<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=ISO-8859-15">
</head>
<body bgcolor="#ffffff" text="#000000">
<img src="cid:part1.06090408.01060107" alt="">
</body>
</html>

--XYZ
Content-Type: image/png;name="${OUT}"
Content-Transfer-Encoding: base64
Content-ID: <part1.06090408.01060107>
Content-Disposition: inline; filename="${OUT}"

$(base64 ${OUT})
--XYZ
EOT

# <img src="cid:part1.06090408.01060107" alt="">


for F in ${TMP} ${OUT} ${TMP2}
do
        if [[ -f ${F} ]]
        then
                rm -f ${F}
        fi
done

#***************************************************************#
#               E N D      O F       S O U R C E                #
#***************************************************************#
