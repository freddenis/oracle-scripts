#!/bin/bash
#

         TFA_HOME=/opt/oracle/tfa
              ZIP=TFALite_121263.zip
                          ZIP=p21757377_121020_Generic.zip              # New 12.1.2.8.4
              TMP=/tmp/fictemp$$.log
THIS_IS_AN_UPDATE=""

#
# Check if TFA is already running
#
ps -ef | grep "init.tfa run" | grep -v grep > /dev/null 2>&1

if [ $? -eq "0" ]
then
        THIS_IS_AN_UPDATE="Yes"
        cat << !
        TFA is already running, let's update it.
!
else
        cat << !
        No previous TFA installation found, let's proceed with a fresh install.
!
fi

#
# Check Java version
#
for D in `cat /etc/oratab | egrep "^([a-z]|[+])" | awk 'BEGIN{FS=":"}{print $2}' | sort | uniq`
do
        echo "Checking for Java in " $D " ..."
        JAVA=`find /${D}/jdk/jre -name java`
        ${JAVA} -version > ${TMP} 2>&1
        JAVA_VERSION=`cat ${TMP} | grep -i "^java version" | sed s'/^.*\([1-9]\.[1-9]\).*/\1/'`

# Test  JAVA_VERSION="1.4"

        if [ ${JAVA_VERSION} = "1.5" ] || [ ${JAVA_VERSION} = "1.6" ]
        then
#               echo "Java is " ${JAVA_VERSION} " in " ${D} ", will use this one !"
                JAVA_TO_USE=${D}/jdk/jre
                UNZIP=`find ${D} -name unzip`           # Will use the unzip of the ORACLE_HOME
                UNZIP_PATH=`dirname ${UNZIP}`
                echo ${UNZIP}
                echo ${UNZIP_PATH}
                break
        else
                echo "JAVA version is " ${JAVA_VERSION} " in " ${D}
        fi
done
if [ -z ${JAVA_TO_USE} ]
then
        cat << !
        No Java 1.5 found on this server; cannot proceed with TFA installation.
!
        exit 2
fi

#
# Create TFA_HOME directory
#
if [ ! -d ${TFA_HOME} ]
then
        mkdir -p ${TFA_HOME}
        chown oracle:dba ${TFA_HOME}
fi

#
# Unzip
#
if [ -f ${ZIP} ]
then
        cp ${ZIP} /tmp/${ZIP}
        ${UNZIP} /tmp/${ZIP} -d ${TFA_HOME}
        rm -f /tmp/${ZIP}
fi

#
# Install
#

export PATH=${PATH}:${UNZIP_PATH}
cd ${TFA_HOME}
./installTFALite -tfabase ${TFA_HOME} -javahome ${JAVA_TO_USE} -silent

#
# Some privileges
#

chmod -R a+rx ${TFA_HOME}/repository

#
# A quick check
#
if [ -z $THIS_IS_AN_UPDATE ]
then
        ${TFA_HOME}/bin/tfactl status
        ${TFA_HOME}/bin/tfactl access lsusers
fi

#
# Add env to root and oracle
#
if [ -z $THIS_IS_AN_UPDATE ]
then
        echo "export PATH=\$PATH:${TFA_HOME}/bin" >> $HOME/.bash_profile
        echo "export PATH=\$PATH:${TFA_HOME}/bin" >> /home/oracle/.bash_profile
fi

if [ -f ${TMP} ]
then
        rm -f ${TMP}
fi
/opt/oranfs/media/TFA : MOV001>
