-- Final Project - CSC 544
-- November 2019
-- Bereket, Dagmawi, Evan, Ethan

drop trigger App_administrator.user_type_ctx_trig;
drop view App_schema.student_enrollment_view;
drop view App_schema.instructor_view;
drop table App_schema.students;
drop table App_schema.courses;
drop table App_schema.instructors;
drop table App_schema.enrollment;
drop user App_schema cascade;

-- Create the user accounts.
create user App_schema identified by AS1234;
grant create session, create any context, create table, create procedure, create view, create trigger to App_schema;
alter user App_schema quota 100M on USERS;

disconnect;

connect App_schema/AS1234@orclpdb

--############################################################################################################

-- Create the objects (tables, views, etc.)

create table students(
	id number(9,0) primary key,
	last_name varchar(30),
	first_name varchar(30),
	ename as (last_name || substr(first_name, 1, 1)),
	major varchar(25)
);

create table instructors(
	id number(9,0) primary key,
	last_name varchar(30),
	first_name varchar(30),
	ename as (last_name || substr(first_name, 1, 1)),
	dept varchar(3)
);

create table courses(
	crn number(5,0) primary key,
	instructor_id number(9,0) constraint instructor_id_fkey references instructors(id)
);

create table enrollment(
	student_id number(9,0),
	crn number(5,0),
	grade number(4)
);

-- instructor_view will allow students and instructors to view all information in the instructors table, except for id
create or replace view instructor_view as 
	select first_name, last_name, ename, dept 
	from instructors;
	
-- view to allow students to see their own records in the enrollment table
create or replace view student_enrollment_view as 
	select student_id, crn, grade 
	from enrollment
	where student_id = (select id from students where ename = sys_context('ctx', 'ename'));

--############################################################################################################

-- Create the App_administrator

disconnect;

connect sys/1234@orclpdb as sysdba

drop role staff_member_role;
drop role student_role;
drop role instructor_role;
drop user App_administrator cascade;

-- grant App_administrator certain privileges
create user App_administrator identified by AA1234;
grant create session to App_administrator with admin option;
grant select on App_schema.student_enrollment_view to App_administrator with grant option;
grant select on App_schema.instructor_view to App_administrator with grant option;
grant select, insert, update, delete on App_schema.students to App_administrator with grant option;
grant select, insert, update, delete on App_schema.instructors to App_administrator with grant option;
grant select, insert, update, delete on App_schema.courses to App_administrator with grant option;
grant select, insert, update, delete on App_schema.enrollment to App_administrator with grant option;
grant execute on dbms_rls to App_administrator;
grant create procedure to App_administrator;
grant create role to App_administrator;
grant create any trigger to App_administrator;
-- grant execute package to App_administrator;
grant administer database trigger to App_administrator;
-- grant execute package to App_administrator;


disconnect;


--############################################################################################################

-- Define roles for other users

connect App_administrator/AA1234@orclpdb;

-- create the staff member role
create role staff_member_role;
grant select, insert, update, delete on App_schema.students to staff_member_role; 
grant select, insert, update, delete on App_schema.instructors to staff_member_role;
grant select, insert, update, delete on App_schema.courses to staff_member_role;
grant select, insert, update, delete on App_schema.enrollment to staff_member_role;

-- create the student role
create role student_role;
grant select on App_schema.student_enrollment_view to student_role;
grant select on App_schema.courses to student_role; 
grant select on App_schema.instructor_view to student_role;

-- create the instructor role that is assigned to instructors
create role instructor_role;
grant update on App_schema.enrollment to instructor_role;
grant select on App_schema.students to instructor_role; 
grant select on App_schema.courses to instructor_role; 
grant select on App_schema.enrollment to instructor_role;
grant select on App_schema.instructors to instructor_role; 
grant update on App_schema.instructors to instructor_role;
grant select on App_schema.instructor_view to instructor_role;


--############################################################################################################
-- package to define the user type (instructor, student, or staff member)
create or replace package user_type_ctx_pkg
is
	procedure set_user_type;
end;
/


create or replace package body user_type_ctx_pkg
is
	procedure set_user_type
	is
		i App_schema.instructors.ename%type;
		s App_schema.students.ename%type;
	begin
		select ename into i from App_schema.instructors
		where upper(ename) = upper(sys_context('userenv', 'session_user'));
		
		select ename into s from App_schema.students
		where upper(ename) = upper(sys_context('userenv', 'session_user'));
		
		if i is not null then
			dbms_session.set_context('user_type_ctx', 'user_type', 'INSTRUCTOR');
		elsif s is not null then
			dbms_session.set_context('user_type_ctx', 'user_type', 'STUDENT');
		else
			dbms_session.set_context('user_type_ctx', 'user_type', 'STAFF');
		end if;
	exception
		when NO_DATA_FOUND then null;
	end;
end;
/
show err;
create or replace trigger user_type_ctx_trig
after logon on database 
begin
	App_administrator.user_type_ctx_pkg.set_user_type;
end;
/

--############################################################################################################
-- create the rls function

-- below function causes the "WHERE ename = [user ename]" to be attached to every query for a user.
create or replace function rls_func (p_schema in varchar2, p_object in varchar2)
return varchar2
as
begin
	-- for instructors, attach a where condition to prevent them from seeing other instructor ids
	-- for staff, allow them full access to view ids in the instructors table (don't return a where condition)
	return 'upper(ENAME) = ''' || upper(sys_context('userenv', 'session_user')) || ''' or ' || sys_context('user_type_ctx', 'user_type') || ' like ''STAFF''';
exception
	when others then
		raise_application_error(-20002, 'Error in VPD function rls_func!');
end;
/
--############################################################################################################

/*
--############################################################################################################
-- allow instructors to update their own information, except for id and ename
begin
	dbms_rls.add_policy
	(
		object_schema=>'APP_SCHEMA',
		object_name=>'INSTRUCTORS',
		function_schema=>'APP_ADMINISTRATOR',
		policy_function=>'RLS_FUNC',
		policy_name=>'INSTRUCTOR_UPDATE_CFRF',
		statement_types=>'UPDATE',
		sec_relevant_cols=>'LAST_NAME, FIRST_NAME, DEPT'
	);
end;
/
*/
--############################################################################################################


--############################################################################################################
-- create the instructor vpd policy that allows students/instructors to see all information on instructors, except for IDs
begin
	dbms_rls.add_policy
	(
		object_schema=>'APP_SCHEMA',
		object_name=>'INSTRUCTORS',
		function_schema=>'APP_ADMINISTRATOR',
		policy_function=>'RLS_FUNC',
		policy_name=>'INSTRUCTORS_CFCF',
		statement_types=>'SELECT',
		sec_relevant_cols=>'ID',
		sec_relevant_cols_opt=>dbms_rls.all_rows
	);
end;
/

--############################################################################################################

--############################################################################################################
-- need to create a trigger for updating the enrollment table (instructors can only update of classes for which they teach)

create or replace trigger enrollment_update_trigger
before update on App_schema.enrollment
referencing new as new old as old
for each row
declare
	instr_id App_schema.instructors.id%type;
	instr_id2 App_schema.courses.instructor_id%type;
begin
	select id into instr_id from App_schema.instructors where upper(ename) = upper(sys_context('userenv', 'session_user'));
	select instructor_id into instr_id2 from App_schema.courses where crn = :old.crn;
	
	if (instr_id != instr_id2) then
		raise_application_error(-20001, 
				chr(10) || 
				'You can only update grades of courses you teach.' ||
				chr(10));
	elsif (:new.student_id != :old.student_id or :new.crn != :old.crn) then 
		raise_application_error(-20001, 
				chr(10) || 
				'You are allowed to update only the grades.' ||
				chr(10));
	end if;
end;
/

--############################################################################################################

--############################################################################################################
-- Test insert and create user statements

disconnect;

connect sys/1234@orclpdb as sysdba

drop user SmithW;
drop user SmithJ;
drop user WarrenE;
drop user Staff_1;

-- create instructor(s)
create user SmithJ identified by 1234;
grant create session to SmithJ;
grant instructor_role to SmithJ;

create user WarrenE identified by 1234;
grant create session to WarrenE;
grant instructor_role to WarrenE;

-- create staff member(s)
create user Staff_1 identified by 1234;
grant create session to Staff_1;
grant staff_member_role to Staff_1;

-- create student(s)
create user SmithW identified by 1234;
grant create session to SmithW;
grant student_role to SmithW;



disconnect;
connect App_administrator/AA1234@orclpdb;

insert into App_schema.instructors (id, last_name, first_name, dept) values (1, 'Smith', 'John', 'CSC');
insert into App_schema.instructors (id, last_name, first_name, dept) values (2, 'Warren', 'Elizabeth', 'HUM');
insert into App_schema.instructors (id, last_name, first_name, dept) values (3, 'McDougall', 'Yozie', 'MAT');
insert into App_schema.instructors (id, last_name, first_name, dept) values (4, 'Smith', 'Sue', 'CSC');

/*
insert into App_schema.students (id, last_name, first_name, major) values (1, 'Smith', 'William', 'Computer Science');
insert into App_schema.students (id, last_name, first_name, major) values (2, 'Whittaker', 'Chance', 'Mathematics');


insert into App_schema.courses (crn, instructor_id) values (49331, 1);
insert into App_schema.courses (crn, instructor_id) values (38192, 2);

insert into App_schema.enrollment (student_id, crn, grade) values (1, 49331, 90);
insert into App_schema.enrollment (student_id, crn, grade) values (2, 49331, 87);
insert into App_schema.enrollment (student_id, crn, grade) values (2, 38192, 67);
*/

disconnect;
connect Staff_1/1234@orclpdb;

select * from App_schema.instructors;

disconnect;
connect SmithJ/1234@orclpdb

select * from App_schema.instructors;
select sys_context('user_type_ctx', 'user_type') from dual;
--############################################################################################################

-- create a trigger that allows instructors to update the grade of a student in a course they taught


/*
QUESTIONS

1. Should we specify the tablespace size for the App_schema? (Presumably, it will require a lot of storage.)
2. Does App_schema need EXECUTE DBMS_RLS privilege? Or should that go to App_administrator?
3. To prevent an instructor from updating id, ename, is the 02_vpd_instructor_cfrf.sql the correct way?
4. For staff_member_role, do I need to specify the table the privileges apply to, or will "SELECT ANY ON APP_SCHEMA" work?
5. Should the App_administrator create the roles?
6. Students don't need the "select on students" privilege, do they? (They will have the TFRF context so they can view their own records.)
7. We may have to create a context for students to view enrollment. (Currently, it is a view.) Since instructors are granted the privilege to 
	view this table via the instructor_role, what will happen when an instructor tries to view the table? Will the context come first or the 
	privilege?
8. How to do an update trigger?
9. For the context, who executes the RLS_FUNCTION (inside rls_func.sql) and when?
10. Our set_ename package has a problem: it should fire for either a student or an instructor. How would we know the difference? Would we just 
	check the value of ename, if it's null, then go to the instructors table and try finding the ename there?

PROBLEMS:
Privileges that couldn't be granted to APP_SCHEMA...
	EXECUTE dbms_rls 
	create package
	Also, couldn't create the ctx_trig trigger (after logon on database was the issue)

Privileges that couldn't be granted to App_administrator...
	EXECUTE package

Tried granting the select on view to App_administrator, it just said: ORA-00993: missing GRANT keyword

------------------------------------------------------------------------------------------------------------------

Need to create a trigger before update on enrollment.
------------------------------------------------------------------------------------------------------------------
PROBLEM WITH VPD:
	Can create the INSTRUCTOR_UPDATE_CFRF policy, but it allows instructors to update their id. How to prevent this? Would using a VPD just not be appropriate here?


------------------------------------------------------------------------------------------------------------------
NOTES
App_administrator will need to be granted the CREATE ROLE privilege

*/