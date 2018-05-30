-- Fred DENIS le 27/02/2006
-- Give SID of a PID

set lines 200
column "Process OS" format a12
column status format a12 ;
column machine format a20 ;

accept pid prompt 'Enter an OS PID : '

select a.pid, b.machine, a.spid "Process OS", b.sid, b.serial#, b.program, b.status, b.logon_time
from v$process a, v$session b
where a.addr = b.paddr
and a.spid = &pid ;
