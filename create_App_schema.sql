-- Create the user accounts.

drop role staff_member_role;
drop role student_role;
drop role instructor_role;
drop user App_administrator;

drop view App_schema.student_enrollment_view;
drop view App_schema.instructor_view;
drop table App_schema.students;
drop table App_schema.courses;
drop table App_schema.instructors;
drop table App_schema.enrollment;

create user App_schema identified by AS1234;
grant create session, create any context, create table, create procedure, create view, create trigger to App_schema;

exit