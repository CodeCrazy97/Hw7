-- This script file will be run by the security manager.

create or replace package ctx_pkg
is
	procedure set_ename;
end;
/


create or replace package body ctx_pkg
is
	procedure set_ename
	is
		e App_schema.students.ename%type;
	begin
		select ename into e from App_schema.students
		where upper(ename) = upper(sys_context('userenv', 'session_user'));

		dbms_session.set_context('ctx', 'ename', e);
	exception
		when NO_DATA_FOUND then null;
	end;
end;
/

create or replace trigger ctx_trig
after logon on database 
begin
	App_administrator.ctx_pkg.set_ename;
end;
/