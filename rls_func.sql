-- below function causes the "WHERE ename = [user ename]" to be attached to every query for a user.

create or replace function rls_func (p_schema in varchar2, p_object in varchar2)
return varchar2
as
begin
	return 'ENAME = ' || upper(sys_context('userenv', 'session_user'));
exception
	when others then
		raise_application_error(-20002, 'Error in VPD function rls_func!');
end;
/
