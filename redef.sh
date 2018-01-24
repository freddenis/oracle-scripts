#!/bin/bash
# Fred DENIS -- January 2013
# Redef online of a table (the objective to compress the table online)
#


#
# some default values
#
        TMP=/tmp/redef$$.sql
   cat /dev/null > $TMP
   PARALLEL=16                  # Parallelism for the redefinition
COMPRESSION=" compress for archive high "
      DEBUG="NO"
      DEBUG=""                  # comment to not debug

#
# Usage function
#
usage() {
        cat << !
        $0 -o OWNER -t TABLE -d DESTINATION_TABLESPACE
!
        exit 1
}

#
# Manage the options
#
while getopts "o:t:d:" OPTION
do
        case $OPTION in
        o )     OWNER=`echo ${OPTARG} | tr '[a-z]' '[A-Z]'`      ;;
        t )     TABLE=`echo ${OPTARG} | tr '[a-z]' '[A-Z]'`      ;;
        d )       TBS=`echo ${OPTARG} | tr '[a-z]' '[A-Z]'`      ;;
        :) echo " l'option -$OPTARG need a value "              ; usage         ;;
        \?) echo "Option -$OPTARG inconnue"                     ; usage         ;;
        esac
done

if [[ -z $DEBUG ]]
then
        echo "owner             : "     $OWNER
        echo "table             : "     $TABLE
        echo "dest tablespace   : "     $TBS
fi

if [[ -z $OWNER ]] || [[ -z $TABLE ]] || [[ -z $TBS ]]
then
        usage
fi

#
# Check if the table exists
#
RESULT=`sqlplus -S '/ as sysdba' << END_SQL
        set pages 999   ;
        set head off    ;
        set feed off    ;
        select count(*) from dba_tables where table_name = '${TABLE}' and owner = '${OWNER}'    ;
END_SQL`
if [[ -z $DEBUG ]]
then
        echo "result SQL table : " $RESULT
fi
if [ $RESULT -eq "0" ]
then
        cat << !
        The table ${OWNER}.${TABLE} does not exists.
!
        exit 3
fi

#
# Check if the destination tablespace exists
#
RESULT=`sqlplus -S '/ as sysdba' << END_SQL
        set pages 999   ;
        set head off    ;
        set feed off    ;
        select count(*) from dba_tablespaces where tablespace_name = '${TBS}' ;
END_SQL`
if [[ -z $DEBUG ]]
then
        echo "Result SQL tablespaces : " $RESULT
fi

if [ $RESULT -eq "0" ]
then
        cat << !
        The tablespace ${TBS} does not exists.
!
        exit 4
fi

INTERIM=I${TABLE}               # Name of the interim table

cat << END_SQL >> $TMP
set pages 999                   ;
set lines 200                   ;
set timing on                   ;
whenever sqlerror exit failure  ;
set serveroutput on             ;

alter session force parallel dml parallel $PARALLEL             ;
alter session force parallel query parallel $PARALLEL           ;

prompt -- Size of the table and index before redef
select tablespace_name, segment_name, round(bytes/1024/1024) "MB" from dba_segments where owner = '${OWNER}' and segment_name = '${TABLE}' ;
select tablespace_name, segment_name, round(bytes/1024/1024) "MB" from dba_segments where owner = '${OWNER}' and segment_name in (select index_name from dba_indexes where owner = '${OWNER}' and table_name = '${TABLE}') ;
select count(*) from ${OWNER}.${TABLE}  ;

prompt -- Can redef table ?
exec DBMS_REDEFINITION.CAN_REDEF_TABLE('${OWNER}', '${TABLE}', DBMS_REDEFINITION.CONS_USE_ROWID);

prompt -- Creation of the interim table ${INTERIM}
-- for inittranscreate table ${OWNER}.${INTERIM} ${COMPRESSION} tablespace ${TBS} as select * from ${OWNER}.${TABLE} where 1 = 2 ;
create table ${OWNER}.${INTERIM} tablespace ${TBS} as select * from ${OWNER}.${TABLE} where 1 = 2 ;
alter table ${OWNER}.${INTERIM} initrans 100 maxtrans 255 ;
select ini_trans, max_trans from dba_tables where table_name = '${TABLE}' and  owner = '${OWNER}' ;

prompt -- check constraint before redef
select table_name, constraint_type, constraint_name, status from dba_constraints where owner = '${OWNER}' and table_name = '${TABLE}' ;
select table_name, constraint_type, constraint_name, status from dba_constraints where owner = '${OWNER}' and table_name = '${INTERIM}' ;

prompt -- Drop constraint of the interim table (to avoid ORA-01442 error)
begin
        for i in (select owner, table_name, constraint_name from dba_constraints where owner = '${OWNER}' and table_name = '${INTERIM}')
        loop
                execute immediate 'alter table ' || i.owner || '.' || i.table_name || ' drop constraint ' || i.constraint_name  ;
        end loop ;
end ;
/

prompt -- redef table
BEGIN
DBMS_REDEFINITION.START_REDEF_TABLE(
        uname           => '${OWNER}',
        orig_table      => '${TABLE}',
        int_table       => '${INTERIM}',
        options_flag    => DBMS_REDEFINITION.CONS_USE_ROWID);
END ;
/

prompt  -- copy table dependents
DECLARE
        error_count pls_integer := 0;
BEGIN
        DBMS_REDEFINITION.COPY_TABLE_DEPENDENTS('${OWNER}', '${TABLE}', '${INTERIM}', dbms_redefinition.cons_orig_params, TRUE,TRUE,TRUE,FALSE,error_count);
        DBMS_OUTPUT.PUT_LINE('errors := ' || TO_CHAR(error_count));
end ;
/

prompt -- check for errors
select object_name, base_table_name, ddl_txt from DBA_REDEFINITION_ERRORS;

prompt -- sync interim table
exec DBMS_REDEFINITION.SYNC_INTERIM_TABLE('${OWNER}', '${TABLE}', '${INTERIM}') ;

prompt -- finish redef
exec DBMS_REDEFINITION.FINISH_REDEF_TABLE('${OWNER}', '${TABLE}', '${INTERIM}') ;

prompt -- move the index of the table to the new tablespace
begin
        for i in (select owner, index_name from dba_indexes where owner = '${OWNER}' and table_name = '${TABLE}')
        loop
                execute immediate 'alter index ' || i.owner || '.' || i.index_name || ' rebuild tablespace ${TBS} online ' ;
        end loop ;
end ;
/

prompt -- Size of the table and index before redef
select tablespace_name, segment_name, round(bytes/1024/1024) "MB" from dba_segments where owner = '${OWNER}' and segment_name = '${TABLE}' ;
select tablespace_name, segment_name, round(bytes/1024/1024) "MB" from dba_segments where owner = '${OWNER}' and segment_name in (select index_name from dba_indexes where owner = '${OWNER}' and table_name = '${TABLE}') ;
select count(*) from ${OWNER}.${TABLE}  ;

prompt -- check constraint after redef
select table_name, constraint_type, constraint_name, status from dba_constraints where owner = '${OWNER}' and table_name = '${TABLE}' ;
exit ;

prompt -- drop interim table
drop table ${OWNER}.${INTERIM} ;
END_SQL

#sqlplus / as sysdba << !
#       @${TMP}
#!

#cat $TMP
echo $TMP
#rm $TMP

