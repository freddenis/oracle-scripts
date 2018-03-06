CREATE OR REPLACE PACKAGE DBADMIN.manage_oracle_logs AS
    
	PROCEDURE init_log_temp;
    PROCEDURE manage_alert_log (alert_file varchar2, v_file_name varchar2);
    PROCEDURE manage_listener_log (list_file varchar2, ln varchar2, v_file_name varchar2);
    PROCEDURE clean_alert_log(time_interval number);
    PROCEDURE clean_listener_log(time_interval number);
    
END manage_oracle_logs;
/

create or replace PACKAGE BODY manage_oracle_logs AS
    
	/* Initialize the log data from the view V$DIAG_ALERT_EXT to the global temporaray table DIAG_ALERT_EXT_TEMP */
	PROCEDURE init_log_temp
	IS
	BEGIN
		INSERT INTO DIAG_ALERT_EXT_TEMP
		select ORIGINATING_TIMESTAMP, MESSAGE_TEXT,COMPONENT_ID,FILENAME from V$DIAG_ALERT_EXT WHERE ORIGINATING_TIMESTAMP>
		(
		  select min(ORIGINATING_TIMESTAMP) from 
		 (
			select 'alert_log' log_name,max(ORIGINATING_TIMESTAMP) ORIGINATING_TIMESTAMP from DBADMIN.ALERT_LOG_HIST
			union
			select listener_name log_name,max(ORIGINATING_TIMESTAMP) ORIGINATING_TIMESTAMP from DBADMIN.LISTENER_LOG_HIST group by LISTENER_NAME
		 )
		) ;	
	END;
	
    /*The manage_alert_log procedure populates the following tables:

      DBADMIN.ALERT_LOG_HIST - containing raw alert log data
      DBADMIN.ALERT_LOOKUP_ERR - containing the error codes found in the alert log since the last scan

      The procedure outputs a file in the ORACLE_LOG_MANAGEMENT_OUTPUT directory containing all error codes found
      in the alert log since the last scan which can later be used as input to the logrotate script on OS level
      so we can be notified if any errors are found

      The output log is:

      /u01/app/oracle/dba/log/alert_sid_err.txt    -- sid refers to the corepsonding database name for which the log is scanned
    */
    
    PROCEDURE manage_alert_log (alert_file varchar2, v_file_name varchar2)
    IS
        log_time TIMESTAMP(9) WITH TIME ZONE;
        msg varchar2(4000);

        cursor c1 is
        -- select ORIGINATING_TIMESTAMP, MESSAGE_TEXT from V$DIAG_ALERT_EXT WHERE trim(COMPONENT_ID)='rdbms' and trim(FILENAME)=alert_file and ORIGINATING_TIMESTAMP>(select max(ORIGINATING_TIMESTAMP) from DBADMIN.ALERT_LOG_HIST);
        select ORIGINATING_TIMESTAMP, MESSAGE_TEXT from DIAG_ALERT_EXT_TEMP WHERE trim(COMPONENT_ID)='rdbms' and trim(FILENAME)=alert_file and ORIGINATING_TIMESTAMP>(select max(ORIGINATING_TIMESTAMP) from DBADMIN.ALERT_LOG_HIST);

        regexp_cond varchar2(1000);
        lt VARCHAR2(30 CHAR) :='alert';
        v_file UTL_FILE.file_type;

    BEGIN
        v_file := UTL_FILE.fopen ('ORACLE_LOG_MANAGEMENT_OUTPUT', v_file_name, 'w');
        SELECT LISTAGG(ERROR_PREFIX,'[0-9]+|') WITHIN GROUP (order by ERROR_PREFIX) || '[0-9]+' into regexp_cond from DBADMIN.ERROR_TYPE;
        open c1;
        LOOP
            FETCH c1 INTO log_time, msg;
            EXIT WHEN c1%NOTFOUND;
            insert into DBADMIN.ALERT_LOG_HIST (ORIGINATING_TIMESTAMP, MESSAGE_TEXT, REF_ID) values (log_time, msg, DBADMIN.alert_seq.nextval);
            commit;

            if regexp_count(msg,regexp_cond,1, 'i') >= 1
            then
                for item in (
                    select regexp_substr(msg, regexp_cond, 1, level) as err from dual connect by regexp_substr(msg, regexp_cond, 1, level) is not null
                )
                LOOP
                  insert into DBADMIN.ALERT_LOOKUP_ERR (REF_ID, LOG_TYPE, ERROR_CODE) values (DBADMIN.alert_seq.currval, lt, item.err);
                  UTL_FILE.PUT_LINE(v_file,log_time || ' ' || msg);
                END LOOP;
                commit;
            end if;
        END LOOP;
        CLOSE c1;
        UTL_FILE.FCLOSE(v_file);
    END;

    /*The manage_listener_log procedure populates the following tables:

      DBADMIN.LISTENER_LOG_HIST - containing raw listener log data from each listener log (a, b, d and e)
      DBADMIN.LISTENER_LOOKUP_ERR - containing the error codes found in each listener log (a, b, d and e) since the last scan
      DBADMIN.LISTENER_LOG_PARSED - containing parsed listener log data from each listener log (a, b, d and e)

      The procedure outputs a file in the ORACLE_LOG_MANAGEMENT_OUTPUT directory containing all error codes found
      in the listener log since the last scan which can later be used as input to the logrotate script on OS level
      so we can be notified if any errors are found

      The output log is:

      /u01/app/oracle/dba/log/listener_LID_err.txt    -- LID refers to the corepsonding listener name for which the log is scanned (a, b, d or e)
    */
    PROCEDURE manage_listener_log (list_file varchar2, ln varchar2, v_file_name varchar2)
    IS
      log_time TIMESTAMP(9) WITH TIME ZONE;
      msg varchar2(4000);

      cursor c1 is
--      select ORIGINATING_TIMESTAMP, MESSAGE_TEXT from V$DIAG_ALERT_EXT WHERE trim(COMPONENT_ID)='tnslsnr' and trim(FILENAME)=list_file and ORIGINATING_TIMESTAMP>(select max(ORIGINATING_TIMESTAMP) from DBADMIN.LISTENER_LOG_HIST where LISTENER_NAME=ln);
	  select ORIGINATING_TIMESTAMP, MESSAGE_TEXT from DIAG_ALERT_EXT_TEMP WHERE trim(COMPONENT_ID)='tnslsnr' and trim(FILENAME)=list_file and ORIGINATING_TIMESTAMP>(select max(ORIGINATING_TIMESTAMP) from DBADMIN.LISTENER_LOG_HIST where LISTENER_NAME=ln);

      regexp_cond varchar2(1000);

      ld VARCHAR2(40 CHAR);
      cs varchar2(1000);
      pi varchar2(1000);
      ac VARCHAR2(30 CHAR);
      sn VARCHAR2(30 CHAR);
      rc VARCHAR2(30 CHAR);
      lt VARCHAR2(30 CHAR) :='tnslsnr';

      field_pattern number;

      v_file UTL_FILE.file_type;

    BEGIN
      v_file := UTL_FILE.fopen ('ORACLE_LOG_MANAGEMENT_OUTPUT', v_file_name, 'w');
      SELECT LISTAGG(ERROR_PREFIX,'[0-9]+|') WITHIN GROUP (order by ERROR_PREFIX) || '[0-9]+' into regexp_cond from DBADMIN.ERROR_TYPE;
      open c1;
      LOOP
          FETCH c1 INTO log_time, msg;
          EXIT WHEN c1%NOTFOUND;

          insert into DBADMIN.LISTENER_LOG_HIST (ORIGINATING_TIMESTAMP, MESSAGE_TEXT, LISTENER_NAME, REF_ID) values (log_time, msg, ln, DBADMIN.listener_seq.nextval);
          commit;

          if regexp_count(msg,regexp_cond,1, 'i') >= 1
            then
                for item in (
                    select regexp_substr(msg, regexp_cond, 1, level) as err from dual connect by regexp_substr(msg, regexp_cond, 1, level) is not null
                )
                LOOP
                  insert into DBADMIN.LISTENER_LOOKUP_ERR (REF_ID, LOG_TYPE, LISTENER_NAME, ERROR_CODE) values (DBADMIN.listener_seq.currval, lt, ln, item.err);
                  UTL_FILE.PUT_LINE(v_file,log_time || ' ' || msg);
                END LOOP;
                commit;
          end if;

          field_pattern:= regexp_count(msg,'[^*]+', 1,'i');

          if  field_pattern >= 1  and msg NOT LIKE '%TIMESTAMP * CONNECT DATA [* PROTOCOL INFO] * EVENT [* SID] * RETURN CODE%'
          then
                if field_pattern = 3
                /*Pattern example:

                  26-JUL-2016 08:14:10 * ping * 0

                  LOG_DATE         : 26-JUL-2016 08:14:10
                  ACTION           : ping
                  RETURN_CODE      : 0
                */
                then
                      ld:=ltrim(regexp_substr(msg, '[^*]+', 1, 1));
                      ac:=ltrim(regexp_substr(msg, '[^*]+', 1, 2));
                      rc:=ltrim(regexp_substr(msg, '[^*]+', 1, 3));
                      insert into DBADMIN.LISTENER_LOG_PARSED (LOG_DATE, CONNECT_STRING, PROTOCOL_INFO, ACTION, SERVICE_NAME, RETURN_CODE, LISTENER_NAME) values (to_date(ld,'DD-MON-YYYY hh24:mi:ss'),null,null,ac,null,rc,ln);
                      commit;
                else
                   if field_pattern = 4
                   then
                        if ltrim(regexp_substr(msg, '[^*]+', 1, 2)) like '%CONNECT_DATA%'
                         /*Pattern example:

                           16-MAR-2017 09:00:05 * (CONNECT_DATA=(CID=(PROGRAM=)(HOST=datatest2.energyservicesgroup.net)(USER=oracle))(COMMAND=status)(ARGUMENTS=64)(SERVICE=(ADDRESS=(PROTOCOL=TCP)(HOST=datatest2.energyservicesgroup.net)(PORT=1521)))(VERSION=186647552)) * status * 0

                           LOG_DATE         : 16-MAR-2017 09:00:05
                           CONNECT_STRING   : (CONNECT_DATA=(CID=(PROGRAM=)(HOST=datatest2.energyservicesgroup.net)(USER=oracle))(COMMAND=status)(ARGUMENTS=64)(SERVICE=(ADDRESS=(PROTOCOL=TCP)(HOST=datatest2.energyservicesgroup.net)(PORT=1521)))(VERSION=186647552))
                           ACTION           : status
                           RETURN_CODE      : 0
                        */
                        then
                              ld:=ltrim(regexp_substr(msg, '[^*]+', 1, 1));
                              cs:=ltrim(regexp_substr(msg, '[^*]+', 1, 2));
                              ac:=ltrim(regexp_substr(msg, '[^*]+', 1, 3));
                              rc:=ltrim(regexp_substr(msg, '[^*]+', 1, 4));
                              insert into DBADMIN.LISTENER_LOG_PARSED (LOG_DATE, CONNECT_STRING, PROTOCOL_INFO, ACTION, SERVICE_NAME, RETURN_CODE, LISTENER_NAME) values (to_date(ld,'DD-MON-YYYY hh24:mi:ss'),cs,null,ac,null,rc,ln);
                              commit;
                        else
                              /*Pattern example:

                                16-MAR-2017 09:00:01 * service_update * P2CT1 * 0

                                LOG_DATE         : 16-MAR-2017 09:00:01
                                ACTION           : service_update
                                SERVICE_NAME     : P2CT1
                                RETURN_CODE      : 0
                              */
                              ld:=ltrim(regexp_substr(msg, '[^*]+', 1, 1));
                              ac:=ltrim(regexp_substr(msg, '[^*]+', 1, 2));
                              sn:=ltrim(regexp_substr(msg, '[^*]+', 1, 3));
                              rc:=ltrim(regexp_substr(msg, '[^*]+', 1, 4));
                              insert into DBADMIN.LISTENER_LOG_PARSED (LOG_DATE, CONNECT_STRING, PROTOCOL_INFO, ACTION, SERVICE_NAME, RETURN_CODE, LISTENER_NAME) values (to_date(ld,'DD-MON-YYYY hh24:mi:ss'),null,null,ac,sn,rc,ln);
                              commit;
                        end if;
                   else
                        if field_pattern = 6
                        /*Pattern example:

                          16-MAR-2017 09:01:02 * (CONNECT_DATA=(SERVER=DEDICATED)(SID=REPT1)(SERVICE_NAME=REPT1.icsolutions.com)(CID=(PROGRAM=C:\oracle\ora10g\bin\sqlplus.exe)(HOST=DBASERVER)(USER=dba_sched))) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.1.150)(PORT=3857)) * establish * REPT1.icsolutions.com * 0

                          LOG_DATE         : 16-MAR-2017 09:01:02
                          CONNECT_STRING   : (CONNECT_DATA=(SERVER=DEDICATED)(SID=REPT1)(SERVICE_NAME=REPT1.icsolutions.com)(CID=(PROGRAM=C:\oracle\ora10g\bin\sqlplus.exe)(HOST=DBASERVER)(USER=dba_sched)))
                          PROTOCOL_INFO    : (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.1.150)(PORT=3857)) * establish * REPT1.icsolutions.com * 0
                          ACTION           : establish
                          SERVICE_NAME     : REPT1.icsolutions.com
                          RETURN_CODE      : 0
                        */
                        then
                              ld:=ltrim(regexp_substr(msg, '[^*]+', 1, 1));
                              cs:=ltrim(regexp_substr(msg, '[^*]+', 1, 2));
                              pi:=ltrim(regexp_substr(msg, '[^*]+', 1, 3));
                              ac:=ltrim(regexp_substr(msg, '[^*]+', 1, 4));
                              sn:=ltrim(regexp_substr(msg, '[^*]+', 1, 5));
                              rc:=ltrim(regexp_substr(msg, '[^*]+', 1, 6));
                              insert into DBADMIN.LISTENER_LOG_PARSED (LOG_DATE, CONNECT_STRING, PROTOCOL_INFO, ACTION, SERVICE_NAME, RETURN_CODE, LISTENER_NAME) values (to_date(ld,'DD-MON-YYYY hh24:mi:ss'),cs,pi,ac,sn,rc,ln);
                              commit;
                        end if;
                   end if;
                end if;
          end if;
      END LOOP;
      CLOSE c1;
      UTL_FILE.FCLOSE(v_file);
    END;

    /*The clean_alert_log procedure cleans all data older then <time_interval> days from the following two tables:

      DBADMIN.ALERT_LOG_HIST
      DBADMIN.ALERT_LOOKUP_ERR
    */
    PROCEDURE clean_alert_log(time_interval number)
    IS
    BEGIN
        delete from DBADMIN.ALERT_LOG_HIST where ORIGINATING_TIMESTAMP<sysdate-time_interval;
        commit;
    END;

    /*The clean_listener_log procedure cleans all data older then <time_interval> days from the following three tables:

      DBADMIN.LISTENER_LOG_HIST
      DBADMIN.LISTENER_LOOKUP_ERR
      DBADMIN.LISTENER_LOG_PARSED
    */
    PROCEDURE clean_listener_log(time_interval number)
    IS
    BEGIN
	-- Fred Denis -- denis@pythian.com -- Feb 28th 2018 -- CR 1186213
	-- Add the /*+ INDEX(LISTENER_LOG_HIST LSNR_LOG_HIST_IDX1) */ Hint for Prod Japan
        -- delete from DBADMIN.LISTENER_LOG_HIST where ORIGINATING_TIMESTAMP<sysdate-time_interval;
        delete from /*+ INDEX(a LSNR_LOG_HIST_IDX1) */ DBADMIN.LISTENER_LOG_HIST a where ORIGINATING_TIMESTAMP<sysdate-time_interval;
	-- END Fred Denis -- denis@pythian.com -- Feb 28th 2018 -- CR 1186213

        delete from DBADMIN.LISTENER_LOG_PARSED where LOG_DATE<sysdate-time_interval;
        commit;
    END;
END manage_oracle_logs;
