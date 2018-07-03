-- Fred DENIS le 3 Juin 2003
-- Liste les sessions lockantes et les session lockees
-- Affiche les types de lock ainsi que les objets qu ils lockent
--
-- Lock Modes :
--      0, None                 => None (on attend pas un lock, on a un lock)
--      1, Null (NULL)          => Null
--      2, Row-S (SS)           => Sub-Shared
--      3, Row-X (SX)           => Sub-Exclusive
--      4, Share (S)            => Shared
--      5, S/Row-X (SSX)        => Shared-Sub-Exclusive
--      6, Exclusive (X)        => Exclusive

set linesize 200                        ;
set pages 9000				;

column  sid                format  999999     ;
column  rbs                format  999     ;
column  slot               format  9999    ;
column  seq               format  9999999 ;
column  lmode            format  99999   ;
column  request          format  9999999 ;
column  username       format  a15     ;
column  object_name   format  a20     ;
column  ctime             format  999999  ;
column object_type 	format a16;

set feedback on                         ;

prompt Qui lock qui                     ;

SELECT  (SELECT username FROM v$session WHERE sid=a.sid) blocker,
        a.sid, ' is blocking ',
        (SELECT username FROM v$session WHERE sid=b.sid) blockee,
        b.sid
  FROM  gv$lock a, gv$lock b
 WHERE  a.block         =       1
   AND  b.request       >       0
   AND  a.id1           =       b.id1
   AND  a.id2           =       b.id2
ORDER BY a.sid ;
set feedback off ;

--prompt ;
--prompt Liste des locks et les objets lockes par user et par session
--SELECT  s.username,
--        l.sid,
--        s.serial#,
--        trunc(id1/power(2,16)) rbs,
--        bitand(id1,to_number('ffff','xxxx'))+0 slot,
--        id2 seq,
--        l.lmode,
--        l.request,
--        a.object_name,
--        a.object_type, l.ctime
--  FROM  v$lock l, v$session s, v$locked_object o, all_objects a
-- WHERE  l.type          =       'TX'            -- Transaction Lock
--   AND  l.sid           =       s.sid
--   AND  o.session_id    =       s.sid
--   AND  a.object_id     =       o.object_id
--ORDER BY s.username ;
----AND   s.username = USER ;
--
--prompt ;
--
--set feedback on ;
--
-- select sid, BLOCKING_SESSION, FINAL_BLOCKING_INSTANCE, FINAL_BLOCKING_SESSION from v$session where event = 'library cache pin' order by FINAL_BLOCKING_SESSION ;

--------------------------------------------------------------------
----              E N D      O F      S O U R C E                 --
--------------------------------------------------------------------
--
