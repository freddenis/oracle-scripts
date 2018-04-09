# Fred Denis -- denis@pythian.com -- March 2017
# Automatically generates an Exadata patching action plan
# For more details about the Exadata patching procedure, you can have a look at https://www.pythian.com/blog/patch-exadata-part-1-introduction-prerequisites/
#
# The current version of the script is 20180408
#
# 20180408 - Fred Denis - Add the -c option to specify the name of the cel01 if not in the default form ${CLUSTER_NAME}cel01
#                         Add a scp of the dbs_group file in case of it is not there for the DB nodes pre-reqs / patching
# 20180404 - Fred Denis - Remove the ib_group file from the ib switch patch command line as patchmgr will find
#                          the ib switch list by itself using the ibswicthes command
# 20180319 - Fred Denis - Add support for the -allow_active_network_mounts option
#                         Minor alignemnt adjustments
#

#
# If we want some "debug" information, comment the line you don't want
#
DEBUG="Yes"
DEBUG="No"

#
# Some default values
#
        DEFAULT_CLUSTER_NAME="mycluster"                                # If a clustername is not specified and if we don't find it
             DEFAULT_GI_HOME="/u01/app/12.1.0.2/grid"                   # If not specified and if we don't find it
                        CONF=/tmp/tmpconf$$                             # Temporary config file
               DBSERVER_TYPE="OL"                                       # Other possible value is OVS
               STATUS_SCRIPT=/home/oracle/pythian/rac-status.sh         # Where the status script is located (this one : https://raw.githubusercontent.com/freddenis/oracle-scripts/master/status.sh)
              VER_TO_INSTALL="."                                        # If no version to install specified, we want to install the highest
            MODIFY_AT_PREREQ=""                                         # No "-modify_at_prereq" by default
            ALLOW_ACTIVE_NFS="Yes"                                      # To use the -allow_active_network_mounts option (available starting from version 12.1.2.1.1)
                       CEL01=""                                         # Name of the Cell 01 we will be using to patch the DB Nodes

#
# A usage function
#
usage()
{
        cat << !

        $0
                -d <DIRECTORY_OF_THE_BUNDLE_PATCH>                      (mandatory)
                -f                                                      (optional) Generate the commands to force umount the NFS before patching (for versions < 12.1.2.1.1)
                -g <GI_HOME>                                            (optional)
                -c <Cel01 name>                                         (optional -- if your cel01 is not named in the form ${CLUSTER_NAME}cel01)
                -h                                                      (generate a HTML action plan, mandatory, default is no HTML)
                -n <NAME_OF_THE_CLUSTER>                                (optional)
                -u                                                      (Unzip and prereqs steps have been done, shows a green "DONE" for the unzip parts, default is unzip has not been done)
                -v <Cells, IB and DB Server version to install>         (optional -- default is the highest)

                # Use the below -[mM] options with caution
                -m                                                      (optional -- use the -modify_at_prereq option when patching the DB Servers; default is -modify_at_prereq is not used)
!
        exit 123
}

#
# Parameters management
#
while getopts ":d:n:humMg:v:fc:" OPT; do
        case ${OPT} in
        d)          PATCH_DIR=`echo ${OPTARG} | sed s'/\/ *$//'`    ;;      # Remove any trailing /
        f)   ALLOW_ACTIVE_NFS="No"                                  ;;
        g)            GI_HOME=`echo ${OPTARG} | sed s'/\/ *$//'`    ;;      # Remove any trailing /
        c)             CEL01=${OPTARG}                              ;;
        h)               HTML="Yes"                                 ;;
        n)       CLUSTER_NAME=${OPTARG}                             ;;
        u)         UNZIP_DONE="Yes"                                 ;;
        v)     VER_TO_INSTALL=${OPTARG}                             ;;      # Cells, IB and DB Server version to install
        m|M) MODIFY_AT_PREREQ="-modify_at_prereq"                   ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage              ;;
        esac
done

if [ -z ${PATCH_DIR} ]
then
        cat << !
        A patch directory is needed, cannot continue without.
!
        usage
fi
if [ -z ${CLUSTER_NAME} ]       # If cluster_name is not specified, we try to guess it or we put a default value
then
        HOST=`hostname -s`
        if [[ ${HOST} == *"db"* || ${HOST} == *"cel"* ]]
        then
                CLUSTER_NAME=`echo ${HOST} | sed 's/db[[:digit:]]*//; s/cel[[:digit:]]*//'`
        else
                CLUSTER_NAME=${DEFAULT_CLUSTER_NAME}
        fi
fi
if [ -z ${CEL01} ]              # Build te default cel01 name if not specified from the command line
then
        CEL01=${CLUSTER_NAME}cel01
fi
if [ -z ${GI_HOME} ]            # If Grid Home is not set, we try to find out, if not we put a default
then
        GI_HOME=`grep ASM /etc/oratab | awk 'BEGIN {FS=":"} {print $2}' | grep "^/"`
        if [ -z ${GI_HOME} ]
        then
                GI_HOME=${DEFAULT_GI_HOME}
        fi
fi

#
# Grep and format the information we need from the bundle.xml file
# I choose to put everything in a temporary config file in case of we would need to only keep config files instead of bundle.xml file later on
#
            BUNDLE_XML="${PATCH_DIR}/bundle.xml"

        if [ ! -f ${BUNDLE_XML} ]
        then
                cat << !
        Cannot find the bundle.xml file in ${PATCH_DIR}, this does not look like to be the good directory.
!
        usage
        fi
               VERSION=`grep patch_abstract ${BUNDLE_XML} | sed 's/.*- //; s/)"//'`             # Better way I found to get the target version

                awk -v VERSION="$VERSION" '
                BEGIN\
                {
                             OFS="|"                                                            ;
                        PATCHMGR="CANNOT_FIND_PATCHMGR_PLEASE_DOWNLOAD_IT_FROM_PATCH_21634633"  ;
                }
                {
                        # Look for the GI patch
                        if ($0 ~ "Database/")
                        {
                                sub(/.*location=\"/, "", $0)                                    ;
                                sub(/".*$/, "", $0)                                             ;
                                PATH = $0                                                       ;
                                TYPE="UNKNOWN"                                                  ;
                                while (getline)
                                {
                                        if ($0 ~ / patch_id/)
                                        {
                                                sub (/.*patch_id="/, "", $0)                    ;
                                                sub (/".*$/, "", $0)                            ;
                                                PATCH_ID = $0                                   ;
                                        }
                                        if (PATH ~ /OPatch/)
                                        {       print "OPATCH", PATH, PATCH_ID                  ;
                                                break                                           ;
                                        }
                                        if (PATH ~ /OPlan/)
                                        {
                                                print "OPLAN", PATH, PATCH_ID                   ;
                                                break                                           ;
                                        }
                                        if ($0 ~ /type="cluster"/ )
                                        {
                                                print "GI", PATH, PATCH_ID                      ;
                                        }
                                        if ($0 ~ /<\/subpatch>/)
                                        {
                                                break                                           ;
                                        }
                                }
                        }       # End of if ($0 ~ "Database/")

                        # Look for the cell and IB patchs and versions
                        if ($0 ~ /ExadataStorageServer_InfiniBandSwitch/)
                        {
                                sub(/.*location="/, "", $0)                                     ;
                                sub(/".*$/, "", $0)                                             ;
                                CELL_DIR=$0                                                     ;
                                sub(/.*Infrastructure\//, "", $0)                               ;
                                sub(/\/.*$/, "", $0)                                            ;
                                # fredif ( $0 > CELL_VERSION)
                                # fred{
                                        CELL_VERSION=$0                                         ;
                                        while (getline)
                                        {       if ($0 ~  / patch_id/)
                                                {       sub (/.*patch_id="/, "", $0)            ;
                                                        sub(/".*$/, "", $0)                     ;
                                                        CELL_PATCH_ID=$0                        ;
                                                }
                                                if ($0 ~ /target_type type="oracle_exadata/)
                                                {
                                                        while (getline)
                                                        {       if ($0 ~ /version_after_patching/)
                                                                {
                                                                        sub (/.*version_after_patching="/, "", $0)      ;
                                                                        sub (/".*$/, "", $0)                            ;
                                                                        CELL_VERSION_AFTER_PATCHING=$0                  ;
                                                                        break                                           ;
                                                                }
                                                        }
                                                }
                                                if ($0 ~ /<\/target_types>/)
                                                {
                                                        # A non dotted version to generate the names of the zip files
                                                        NON_DOTTED_VERSION=CELL_VERSION          ;
                                                        gsub(/\./, "", NON_DOTTED_VERSION)       ;

                                                        # Cells and IB infos
                                                        print "CELLS", CELL_DIR, CELL_VERSION, CELL_VERSION_AFTER_PATCHING, "p"CELL_PATCH_ID"_"NON_DOTTED_VERSION"_Linux-x86-64.zip"              ;

                                                        next                                    ;
                                                }
                                        }
                                #fred}
                        }       # End of if ($0 ~ /ExadataStorageServer_InfiniBandSwitch/)

                        # Look for patchmgr
                        if ($0 ~  /DBServerPatch/)
                        {
                                sub(/.*location="/, "", $0)                                     ;
                                sub(/".*$/, "", $0)                                             ;
                                PATCHMGR=$0                                                     ;
                                while (getline)         # I could do only 1 getline but in case Oracle changes something one day, we ll be ready
                                {       if ($0 ~  / patch_id/)
                                        {       sub (/.*patch_id="/, "", $0)                    ;
                                                sub(/".*$/, "", $0)                             ;
                                                PATCHMGR_PATCH_ID=$0                            ;
                                                break                                           ;
                                        }
                                         if ($0 ~ /<\/subpatch>/)
                                        {
                                                PATCHMGR_PATCH_ID="NOT_FOUND"                   ;
                                                next                                            ;
                                        }
                                }

                        }       # End of if ($0 ~  /DBServerPatch/)

                        # Look for DB server patches
                        if ($0 ~ /ExadataDatabaseServer/)
                        {
                                sub(/.*location="/, "", $0)                                     ;
                                sub(/".*$/, "", $0)                                             ;
                                DB_DIR=$0                                                       ;
                                sub(/.*Infrastructure\//, "", $0)                               ;
                                sub(/\/.*$/, "", $0)                                            ;
                                DB_SERVER_VERSION=$0                                            ;
                                NON_DOTTED_VERSION=DB_SERVER_VERSION                            ;
                                gsub(/\./, "", NON_DOTTED_VERSION)                              ;

                                while (getline)
                                {       if ($0 ~  / patch_id/)
                                        {       sub (/.*patch_id="/, "", $0)                    ;
                                                sub(/".*$/, "", $0)                             ;
                                                DB_SERVER_PATCH_ID=$0                           ;
                                        }
                                        if ($0 ~ /target_type type="host"/)
                                        {
                                                sub (/.*version_after_patching="/, "", $0)      ;
                                                sub (/".*$/, "", $0)                            ;
                                                DB_SERVER_VERSION_AFTER_PATCHING=$0             ;
                                        }
                                        if ($0 ~ /<\/target_types>/)
                                        {
                                                print "DB_SERVER", DB_DIR, DB_SERVER_VERSION, DB_SERVER_VERSION_AFTER_PATCHING, "p"DB_SERVER_PATCH_ID"_"NON_DOTTED_VERSION"_Linux-x86-64.zip"   ;
                                                break                                           ;
                                        }
                                }
                        }       # End of if ($0 ~ /ExadataDatabaseServer/)

                }
                END\
                {
                        # Patchmgr infos
                        print "PATCHMGR", PATCHMGR, "p"PATCHMGR_PATCH_ID"_*_Linux-x86-64.zip"   ;       # I put a star in the name as for Jan 2017 the bundle do not show the correct version
                }' ${BUNDLE_XML} > ${CONF}


#
# Grep what is needed from the config file
#

           CELL_AND_IB=`grep "^CELLS"     ${CONF}                         | grep ${VER_TO_INSTALL} | sort | tail -1     | awk 'BEGIN{FS="|"} {print $2}'`
       CELL_AND_IB_ZIP=`grep "^CELLS"     ${CONF}                         | grep ${VER_TO_INSTALL} | sort | tail -1     | awk 'BEGIN{FS="|"} {print $5}' | sed s'/[0-9]_L/0_L/'`  # Seems that the last digit is always a 0 ? (see CR 1187741)
        TARGET_VERSION=`grep "^CELLS"     ${CONF}                         | grep ${VER_TO_INSTALL} | sort | tail -1     | awk 'BEGIN{FS="|"} {print $4}'`
               OL6_DIR=`grep "^DB_SERVER" ${CONF} | grep ${DBSERVER_TYPE} | grep ${VER_TO_INSTALL} | sort | tail -1     | awk 'BEGIN{FS="|"} {print $2}'`
                   ISO=`grep "^DB_SERVER" ${CONF} | grep ${DBSERVER_TYPE} | grep ${VER_TO_INSTALL} | sort | tail -1     | awk 'BEGIN{FS="|"} {print $5}' | sed s'/[0-9]_L/0_L/'` # Seems that the last digit is always a 0 ? (see CR 1187741)
              PATCHMGR=`grep "^PATCHMGR"  ${CONF}                                                                       | awk 'BEGIN{FS="|"} {print $2}'`
          PATCHMGR_ZIP=`grep "^PATCHMGR"  ${CONF}                                                                       | awk 'BEGIN{FS="|"} {print $3}'`
                OPATCH=`grep "^OPATCH"    ${CONF}                                                                       | awk 'BEGIN{FS="|"} {print $2}'`
                GI_DIR=`grep "^GI"        ${CONF} | grep ${VERSION}                                                     | awk 'BEGIN{FS="|"} {print $2}'`               # I take the latest version for the GI
              GI_PATCH=`grep "^GI"        ${CONF} | grep ${VERSION}                                                     | awk 'BEGIN{FS="|"} {print $3}'`               # I take the latest version for the GI
             GI_BUNDLE=${PATCH_DIR}/${GI_DIR}/${GI_PATCH}/bundle.xml

#
# Define some prompts to put in the action plan
#
         DBROOTPROMPT="[root@${CLUSTER_NAME}db01 ~]#"
        CELROOTPROMPT="[root@${CEL01} ~]#"
       DBORACLEPROMPT="[oracle@${CLUSTER_NAME}db01 ~]$"

#
# Show debug info (check the DEBUG variable on top of this script if you want / don't want these debug information)
#
        if [ "${DEBUG}" = "Yes" ]
        then
                cat ${CONF}
        cat << !
                Ver to Install  :       ${VER_TO_INSTALL}
                Bundle file     :       ${BUNDLE_XML}
                Target version  :       ${TARGET_VERSION}
                Version         :       ${VERSION}
                OL6_DIR         :       ${OL6_DIR}
                ISO RPM         :       ${ISO}
                Patchmgr        :       ${PATCHMGR}
                Patchmgr ZIP    :       ${PATCHMGR_ZIP}
                opatch 12c      :       ${OPATCH}
                Cluster Name    :       ${CLUSTER_NAME}
                Cells and IB    :       ${CELL_AND_IB}
                Cells and IB ZIP:       ${CELL_AND_IB_ZIP}
                GI_DIR          :       ${GI_DIR}
                GI_PATCH        :       ${GI_PATCH}
                GI_BUNDLE       :       ${GI_BUNDLE}
                GRID_HOME       :       ${GI_HOME}
                UNZIP_DONE      :       ${UNZIP_DONE}
!
        fi

#
# Define HTML or shell tags and colors depending on the chosen option
#

if [ "${HTML}" = "Yes" ]
then
         S_H2="<hr style='border-style: dotted;'><h2 style='font-size:18px;text-decoration:underline'>"
         E_H2="</h2>"
         S_H3="<h3>"
         E_H3="</h3>"
        S_PRE="<blockquote style='background-color:beige;font-style:normal;'><pre style=white-space:pre-wrap>"
        E_PRE="</pre></blockquote>"
          S_B="<b>"
          E_B="</b>"
       U_DONE="<font color='green';><b> ( Done )</b></font>"
else
  COLOR_BEGIN="\033[1;"
    COLOR_END="\033[0m"
          RED=$COLOR_BEGIN"31m"
        GREEN=$COLOR_BEGIN"32m"
       YELLOW=$COLOR_BEGIN"33m"
         BLUE=$COLOR_BEGIN"34m"
        WHITE=$COLOR_BEGIN"37m"

         S_H2=${RED}
         E_H2=${COLOR_END}
         S_H3=${BLUE}
         E_H3=${COLOR_END}
         S_B=${WHITE}
         E_B=${COLOR_END}
         TAB="\t"
      U_DONE=${GREEN}" ( Done )"${COLOR_END}
fi

if [ "${UNZIP_DONE}" != "Yes" ]
then
        U_DONE=""               # if no -u option, we just put nothing after the unzip paragraph
fi


#
# Generate the procedure thanks to the info we got in the previous steps
#

echo -e "
****************************** START COPYING THE ACTION PLAN BELOW THIS LINE ******************************

${S_H2}1/ Cell patching ${E_H2}

${S_H3}1.1/ First of all, you need to unzip the ${CELL_AND_IB_ZIP} file${U_DONE}:${E_H3}

${S_PRE}
${TAB} ${DBROOTPROMPT} ${S_B} cd ${PATCH_DIR}/${CELL_AND_IB}                                                                                    ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} nohup unzip `basename ${CELL_AND_IB_ZIP}` &                                                                       ${E_B}

${TAB} -- This should create a ${S_B} patch_${TARGET_VERSION} ${E_B} directory with the cell patch
${E_PRE}

${S_H3}1.2/ Cells pre requisites${U_DONE}:${E_H3}
${S_PRE}
${TAB} ${DBROOTPROMPT} ${S_B} cd ${PATCH_DIR}/${CELL_AND_IB}/patch_${TARGET_VERSION}                                                            ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ./patchmgr -cells ~/cell_group -patch_check_prereq -rolling                                                       ${E_B}
${E_PRE}

${S_H3}1.3/ You can then apply the patch (with a check of the version before and after):${E_H3}

${S_PRE}
${TAB} ${DBROOTPROMPT} ${S_B} dcli -g ~/cell_group -l root imageinfo -ver                                                                       ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} cd ${PATCH_DIR}/${CELL_AND_IB}/patch_${TARGET_VERSION}                                                            ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ./patchmgr -cells ~/cell_group -reset_force                                                                       ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ./patchmgr -cells ~/cell_group -cleanup                                                                           ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ./patchmgr -cells ~/cell_group -patch_check_prereq -rolling                                                       ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} nohup ./patchmgr -cells ~/cell_group -patch -rolling &                                                            ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ./patchmgr -cells ~/cell_group -cleanup                                                                           ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} dcli -g ~/cell_group -l root imageinfo -ver                                                                       ${E_B}
${E_PRE}

${S_H2}2/ InfiniBand Switches patching ${E_H2}

${S_H3}2.1 / IB Switches prerequisites${U_DONE}:${E_H3}

${S_PRE}
${TAB} ${DBROOTPROMPT} ${S_B} cd ${PATCH_DIR}/${CELL_AND_IB}/patch_${TARGET_VERSION}                                                            ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ./patchmgr -ibswitches -ibswitch_precheck -upgrade                                                                ${E_B}
${E_PRE}

${S_H3}2.2 / Apply the patch on the IB Switches:${E_H3}

${S_PRE}
${TAB} ${DBROOTPROMPT} ${S_B} dcli -g ~/ib_group -l root version                                                                                ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} cd ${PATCH_DIR}/${CELL_AND_IB}/patch_${TARGET_VERSION}                                                            ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ./patchmgr -ibswitches ~/ib_group -ibswitch_precheck -upgrade                                                     ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} nohup ./patchmgr -ibswitches ~/ib_group -upgrade &                                                                ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} dcli -g ~/ib_group -l root version                                                                                ${E_B}
${E_PRE}

${S_H2}3/ Database Servers patching ${E_H2}

- As we cannot patch a node we are connected to, we will start the patch from a cell server (${CEL01}). To be able to do that, we need to copy patchmgr and the ISO file on this cell server. Do NOT unzip the ISO file, patchmgr will take care of it.
-- Use the script ${S_B}${STATUS_SCRIPT}${E_B} to monitore the instances during the patch application

${S_H3}3.1/ Copy what is needed to ${CEL01}:${E_H3}

-- Create a ${S_B}/tmp/SAVE${E_B} directory in order to avoid the automatic maintenance jobs that purge /tmp every day (directories > 5 MB and older than 1 day). If not, these maintenance jobs will delete the dbnodeupdate.zip file that is mandatory to apply the patch -- this won't survive a reboot though

${S_PRE}
${TAB} ${DBROOTPROMPT} ${S_B} ssh root@${CEL01} mkdir /tmp/SAVE                                                                                 ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} scp ${PATCH_DIR}/${PATCHMGR}/${PATCHMGR_ZIP} root@${CEL01}:/tmp/SAVE/.                                            ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} scp ${PATCH_DIR}/${OL6_DIR}/${ISO} root@${CEL01}:/tmp/SAVE/.                                                      ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} scp ~/dbs_group root@${CEL01}:~/.                                                                                 ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ssh root@${CEL01}                                                                                                 ${E_B}
${TAB} ${CELROOTPROMPT} ${S_B} cd /tmp/SAVE                                                                                                     ${E_B}
${TAB} ${CELROOTPROMPT} ${S_B} nohup unzip ${PATCHMGR_ZIP} &                                                                                    ${E_B}

${TAB} This should create a ${S_B} dbserver_patch_`basename ${PATCHMGR}` ${E_B} directory
${E_PRE}

${S_H3}3.2/ Do the prerequisites${U_DONE}:${E_H3}

-- Consider using the ${S_B}-modify_at_prereq${E_B} option ${S_B}with extra caution${E_B} if you face some dependencies issues (-m or -M option of the action plan generator script)

${S_PRE}
${TAB} ${CELROOTPROMPT} ${S_B} cd /tmp/SAVE/dbserver_patch_`basename ${PATCHMGR}`                                                               ${E_B}
${TAB} ${CELROOTPROMPT} ${S_B} ./patchmgr -dbnodes ~/dbs_group -precheck ${MODIFY_AT_PREREQ} -iso_repo /tmp/SAVE/${ISO} -target_version ${TARGET_VERSION} ${E_B}
${E_PRE}

-- You can safely ignore the below warning (this is a patchmgr bug for a while) if the GI version is > 11.2.0.2 -- which is most likely the case
${S_PRE}
(*) - Yum rolling update requires fix for 11768055 when Grid Infrastructure is below 11.2.0.2 BP12
${E_PRE}

${S_H3}3.3/ We can now proceed with the rolling patch on the database servers:${E_H3}

-- ${S_B}Direct connect to the ${CEL01} server${E_B}, if you go through ${CLUSTER_NAME}db01 or another database server, you will lose your connection when it will be rebooted
"

if [ "${ALLOW_ACTIVE_NFS}" = "No" ]
then
        ALLOW_ACTIVE_NFS_OPTION=""
echo -e "-- Before applying the patch, we first need to umount the NFS on all the database servers:${E_H3}
 - The below command will generate the umount command; add \"${S_B}| bash${E_B}\" at the and and it will umount everything automatically
 - If something prevents a NFS to umount, you can check what it is with \"${S_B}lsof FS_NAME${E_B}\" or \"${S_B}fuser -c -u FS_NAME${E_B}\" and kill it with \"${S_B}fuser -c -k FS_NAME${E_B}\"
 - Nothing should prevent ${S_B}umount -l${E_B} to work
${S_PRE}
${TAB} ${DBROOTPROMPT} ${S_B} df -t nfs | awk '{if (\$NF ~ /^\//){print \"umount -l \" \$NF}}'                                         ${E_B}
${E_PRE}
${TAB} Note : You may consider using the ${S_B}-allow_active_network_mounts${E_B} option if your source version is > 12.1.2.1.1 (default)"
else
        ALLOW_ACTIVE_NFS_OPTION="-allow_active_network_mounts"
fi


echo -e "
-- Apply the patch
${S_PRE}
${TAB} ${CELROOTPROMPT} ${S_B} dcli -g ~/dbs_group -l root imageinfo -ver                                                                       ${E_B}
${TAB} ${CELROOTPROMPT} ${S_B} cd /tmp/SAVE/dbserver_patch_`basename ${PATCHMGR}`                                                               ${E_B}
${TAB} ${CELROOTPROMPT} ${S_B} ./patchmgr -dbnodes ~/dbs_group -precheck ${MODIFY_AT_PREREQ} -iso_repo /tmp/SAVE/${ISO} -target_version ${TARGET_VERSION} ${E_B}
${TAB} ${CELROOTPROMPT} ${S_B} nohup ./patchmgr -dbnodes ~/dbs_group -upgrade -iso_repo /tmp/SAVE/${ISO} -target_version ${TARGET_VERSION} ${ALLOW_ACTIVE_NFS_OPTION} -rolling & ${E_B}

${TAB} Note : the ${S_B}${ALLOW_ACTIVE_NFS_OPTION}${E_B} option is available starting from 12.1.2.1.1, please regenerate the action plan using the ${S_B}-f${E_B} option if you run a version < 12.1.2.1.1

-- You can monitore the patch looking at the nohup.out file (tail -f nohup.out) or the patchmgr.out file

${TAB} ${CELROOTPROMPT} ${S_B} dcli -g ~/dbs_group -l root imageinfo -ver                                                                       ${E_B}
${E_PRE}


${S_H2}4/ Grid Infrastructure patching ${E_H2}

${S_H3}4.1/ To start with, be sure that the patch has been unzipped (as oracle user to avoid any further permission issue)${U_DONE}:${E_H3}

${S_PRE}
${TAB} ${DBORACLEPROMPT} ${S_B} cd ${PATCH_DIR}/${GI_DIR}                                                                                       ${E_B}
${TAB} ${DBORACLEPROMPT} ${S_B} nohup unzip  p${GI_PATCH}*_Linux-x86-64.zip &                                                                   ${E_B}
${TAB} -- This should create a ${S_B} ${GI_PATCH} ${E_B} directory.
${E_PRE}

-- Upgrade opatch if opatch is not already at the latest version: ${U_DONE}
${S_PRE}
${TAB} ${DBORACLEPROMPT} ${S_B}dcli -g ~/dbs_group -l oracle ${GI_HOME}/OPatch/opatch version | grep Version                                    ${E_B}
${TAB} ${DBORACLEPROMPT} ${S_B}dcli -g ~/dbs_group -l oracle -f ${PATCH_DIR}/${OPATCH}/p6880880_12*_Linux-x86-64.zip -d /tmp                    ${E_B}
${TAB} ${DBORACLEPROMPT} ${S_B}dcli -g ~/dbs_group -l oracle \"unzip -o /tmp/p6880880_12*_Linux-x86-64.zip -d ${GI_HOME}; ${GI_HOME}/OPatch/opatch version; rm /tmp/p6880880_12*_Linux-x86-64.zip\" | grep Version${E_B}
${E_PRE}

-- It is also recommended to execute the prerequisites: ${U_DONE}
${S_PRE}
${TAB} ${DBROOTPROMPT} ${S_B} . oraenv <<< \`grep \"^+ASM\" /etc/oratab | awk -F \":\" '{print \$1}'\`                                          ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} cd ${PATCH_DIR}/${GI_DIR}/${GI_PATCH}                                                                             ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} ${GI_HOME}/OPatch/opatchauto apply -oh ${GI_HOME} -analyze                                                        ${E_B}
${E_PRE}

${S_H3}4.2/ Apply the patch ${S_B}on each node one after the other (${CLUSTER_NAME}db01 then (${CLUSTER_NAME}db02, etc...)${E_B}:${E_H3}

-- Use the script ${S_B}${STATUS_SCRIPT}${E_B} to monitore the instances during the patch application
${S_PRE}
${TAB} -- Check the inventory before the patch
${TAB} ${DBORACLEPROMPT} ${S_B} . oraenv <<< \`grep \"^+ASM\" /etc/oratab | awk -F \":\" '{print \$1}'\`                                        ${E_B}
${TAB} ${DBORACLEPROMPT} ${S_B} ${GI_HOME}/OPatch/opatch lsinventory -all_nodes                                                                 ${E_B}

${TAB} -- Apply the patch on the node
${TAB} ${DBROOTPROMPT} ${S_B} cd ${PATCH_DIR}/${GI_DIR}/${GI_PATCH}                                                                             ${E_B}
${TAB} ${DBROOTPROMPT} ${S_B} nohup ${GI_HOME}/OPatch/opatchauto apply -oh ${GI_HOME} &                                                         ${E_B}

${TAB} -- Check the inventory after the patch
${TAB} ${DBORACLEPROMPT} ${S_B} . oraenv <<< \`grep \"^+ASM\" /etc/oratab | awk -F \":\" '{print \$1}'\`                                        ${E_B}
${TAB} ${DBORACLEPROMPT} ${S_B} ${GI_HOME}/OPatch/opatch lsinventory -all_nodes                                                                 ${E_B}

${TAB} -- jump to the next node an re apply 4.2
${E_PRE}

-- Opatch will most likely finish with some warnings :

${S_PRE}
${TAB} [Jun 5, 2016 5:50:47 PM]     --------------------------------------------------------------------------------
${TAB} [Jun 5, 2016 5:50:47 PM]     The following warnings have occurred during OPatch execution:
${TAB} [Jun 5, 2016 5:50:47 PM]     1) OUI-67303:
${TAB}                       Patches [   20831113   20299018   19872484 ] will be rolled back.
${TAB} [Jun 5, 2016 5:50:47 PM]     --------------------------------------------------------------------------------
${TAB} [Jun 5, 2016 5:50:47 PM]     OUI-67008:OPatch Session completed with warnings.

${TAB} Checking the logfiles, you will find that this is probably due to superset patches :

${TAB}   Patch : 23006522 Bug Superset of 20831113

${TAB} If you check this patch number, you will find that this is an old patch : Patch 20831113: OCW PATCH SET UPDATE 12.1.0.2.4

${TAB} Then this is safely ignorable as opatch rollback old patches after having applied the new ones.
${E_PRE}

****************************** STOP COPYING THE ACTION PLAN ABOVE THIS LINE ******************************
"



#************************************************************************************************#
#*                              E N D      O F      S O U R C E                                 *#
#************************************************************************************************#


