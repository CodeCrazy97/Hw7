-- trigger for allowing instructors to update the grade in the enrollment table

create or replace trigger enrollment_update_trigger
before update on App_schema.enrollment
for each row
declare
	instructor_id App_schema.instructors.id%type;
begin
	select id into instructor_id from instructors where ename = upper(sys_context('userenv', 'session_user'));
	if (instructor_id != (select instructor_id from courses where crn = :old.crn)) then
		raise_application_error(-20001, 
				chr(10) || 
				'You can only update grades of courses you teach.' ||
				chr(10));
	end if;
end;
/