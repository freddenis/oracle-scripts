#!/bin/bash

        data=$1
         TMP="/tmp/runonbqtemp$RANDOM"                            # A tempfile
        cat /dev/null > ${TMP}
        if [[ "$data" =~ ^2 ]]
        then
                data2=$(echo $data | sed s'/_/ /')
                echo $data2 > ${TMP}

                #
                # Load in bq
                #
                gcloud config configurations activate dagops
                #bq query --location=EU --use_legacy_sql=false --format=pretty 'select count(*) from ONETM_INGEST_COPY.dagops_logs'
                #wc -l ${TMP}
                bq load -F "|" ONETM_INGEST_COPY.dagops_logs ${TMP}
                #bq query --location=EU --use_legacy_sql=false --format=pretty 'select count(*) from ONETM_INGEST_COPY.dagops_logs'
                gcloud config configurations activate default
        fi

        if [[ -f ${TMP} ]]
        then
                rm -f ${TMP}
        fi

