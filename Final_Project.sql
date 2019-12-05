-- Final Project - CSC 544
-- November 2019
-- Bereket, Dagmawi, Evan, Ethan

drop user SmithW;
drop user SmithJ;
drop user WarrenE;
drop user WhittakerC;
drop user Staff_1;
drop context user_type_ctx;
drop package App_administrator.user_type_ctx_pkg;
drop user App_administrator cascade;
drop role staff_member_role;
drop role student_role;
drop role instructor_role;
drop user App_schema cascade;

-- Create the user accounts.
create user App_schema identified by AS1234;
grant create session, create any context, create table, create procedure, create view, create trigger to App_schema;
alter user App_schema quota 100M on USERS;

disconnect;

connect App_schema/AS1234@localhost:1521/orclpdb

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

-- view to allow students to see their own records in the enrollment table
create or replace view student_enrollment_view as 
	select student_id, crn, grade 
	from App_schema.enrollment
	where student_id = (select id from App_schema.students where upper(ename) = upper(sys_context('userenv', 'session_user')));

--############################################################################################################

-- Create the App_administrator

disconnect;

connect sys/1234@localhost:1521/orclpdb as sysdba

-- grant App_administrator certain privileges
create user App_administrator identified by AA1234;
grant create session to App_administrator with admin option;
grant select on App_schema.student_enrollment_view to App_administrator with grant option;
grant select, insert, update, delete on App_schema.students to App_administrator with grant option;
grant select, insert, update, delete on App_schema.instructors to App_administrator with grant option;
grant select, insert, update, delete on App_schema.courses to App_administrator with grant option;
grant select, insert, update, delete on App_schema.enrollment to App_administrator with grant option;
grant execute on dbms_rls to App_administrator;
grant create procedure to App_administrator;
grant create role to App_administrator;
grant create any trigger to App_administrator;
grant create any context to App_administrator;
-- grant execute package to App_administrator;
grant administer database trigger to App_administrator;
-- grant execute package to App_administrator;


disconnect;


--############################################################################################################

-- Define roles for other users

connect App_administrator/AA1234@localhost:1521/orclpdb;

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
grant select on App_schema.instructors to student_role; 
grant select on App_schema.students to student_role;

-- create the instructor role that is assigned to instructors
create role instructor_role;
grant update on App_schema.enrollment to instructor_role;
grant update on App_schema.instructors to instructor_role;
grant select on App_schema.students to instructor_role; 
grant select on App_schema.courses to instructor_role; 
grant select on App_schema.enrollment to instructor_role;
grant select on App_schema.instructors to instructor_role; 

--############################################################################################################
-- package to define the user type (instructor, student, or staff member)
create context user_type_ctx using user_type_ctx_pkg;

create or replace package user_type_ctx_pkg
is
	procedure set_user_type;
end;
/


create or replace package body user_type_ctx_pkg
is
	procedure set_user_type
	is
		i integer;
		s integer;
	begin
		select NVL(count(*), 0) into i from App_schema.instructors
		where upper(ename) = upper(sys_context('userenv', 'session_user'));
		
		select NVL(count(*), 0) into s from App_schema.students
		where upper(ename) = upper(sys_context('userenv', 'session_user'));
		
		if i > 0 then
			dbms_session.set_context('user_type_ctx', 'user_type', 'INSTRUCTOR');
		elsif s > 0 then
			dbms_session.set_context('user_type_ctx', 'user_type', 'STUDENT');
		else
			dbms_session.set_context('user_type_ctx', 'user_type', 'STAFF');
		end if;
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
	
	if sys_context('user_type_ctx', 'user_type') like 'STAFF' then
		return '1 = 1';
	else 
		return 'upper(ENAME) = ''' || upper(sys_context('userenv', 'session_user')) || '''';
	end if;
exception
	when others then
		raise_application_error(-20002, 'Error in VPD function rls_func!');
end;
/
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
-- create the rls function that allows staff and instructors to view all records in the students table, but 
-- allows students to view only their own records

create or replace function rls_func2 (p_schema in varchar2, p_object in varchar2)
return varchar2
as
begin
	
	if sys_context('user_type_ctx', 'user_type') like 'STAFF' or sys_context('user_type_ctx', 'user_type') like 'INSTRUCTOR' then
		return '1 = 1';
	else 
		return 'upper(ENAME) = ''' || upper(sys_context('userenv', 'session_user')) || '''';
	end if;
exception
	when others then
		raise_application_error(-20002, 'Error in VPD function rls_func!');
end;
/
--############################################################################################################

--############################################################################################################
-- create the instructor vpd policy that allows students/instructors to see all information on instructors, except for IDs
begin
	dbms_rls.add_policy
	(
		object_schema=>'APP_SCHEMA',
		object_name=>'STUDENTS',
		function_schema=>'APP_ADMINISTRATOR',
		policy_function=>'RLS_FUNC2',
		policy_name=>'STUDENTS_CFCF',
		statement_types=>'SELECT'
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
	-- let staff update anything in the enrollment table, but instructors are only allowed to update the grades of students in courses they taught
	if sys_context('user_type_ctx', 'user_type') != 'STAFF' then 	
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
	end if;
end;
/

--############################################################################################################
-- function for updating the instructor table

create or replace function update_instructor(
newDept App_schema.instructors.dept%type,
newLast_name App_schema.instructors.last_name%type,
newFirst_name App_schema.instructors.first_name%type
)
return varchar2
as
begin
	update App_schema.instructors set dept = newDept, last_name = newLast_name, first_name = newFirst_name where upper(ename) = upper(sys_context('userenv', 'session_user'));
	return 'TRUE';
end;
/
show err;
grant execute on App_administrator.update_instructor to instructor_role;
--############################################################################################################
-- Test insert and create user statements

disconnect;

connect sys/1234@localhost:1521/orclpdb as sysdba

-- create instructor(s)
create user SmithJ identified by 1234;
grant create session to SmithJ;
grant instructor_role to SmithJ;

create user WarrenE identified by 1234;
grant create session to WarrenE;
grant instructor_role to WarrenE;

create user SmithS identified by 1234;
grant create session to SmithS;
grant instructor_role to SmithS;

create user McDougallY identified by 1234;
grant create session to McDougallY;
grant instructor_role to McDougallY;

-- create staff member(s)
create user Staff_1 identified by 1234;
grant create session to Staff_1;
grant staff_member_role to Staff_1;

-- create student(s)
create user SmithW identified by 1234;
grant create session to SmithW;
grant student_role to SmithW;

create user WhittakerC identified by 1234;
grant create session to WhittakerC;
grant student_role to WhittakerC;


disconnect;
connect App_administrator/AA1234@localhost:1521/orclpdb;

insert into App_schema.instructors (id, last_name, first_name, dept) values (1, 'Smith', 'John', 'CSC');
insert into App_schema.instructors (id, last_name, first_name, dept) values (2, 'Warren', 'Elizabeth', 'HUM');
insert into App_schema.instructors (id, last_name, first_name, dept) values (3, 'McDougall', 'Yozie', 'MAT');
insert into App_schema.instructors (id, last_name, first_name, dept) values (4, 'Smith', 'Sue', 'CSC');

insert into App_schema.students (id, last_name, first_name, major) values (1, 'Smith', 'William', 'Computer Science');
insert into App_schema.students (id, last_name, first_name, major) values (2, 'Whittaker', 'Chance', 'Mathematics');


insert into App_schema.courses (crn, instructor_id) values (49331, 1);
insert into App_schema.courses (crn, instructor_id) values (38192, 2);

insert into App_schema.enrollment (student_id, crn, grade) values (1, 49331, 90);
insert into App_schema.enrollment (student_id, crn, grade) values (2, 49331, 87);
insert into App_schema.enrollment (student_id, crn, grade) values (2, 38192, 67);

/*
-- connect staff
disconnect;
connect Staff_1/1234@localhost:1521/orclpdb;
*/
-- connect instructor
disconnect;
connect SmithJ/1234@localhost:1521/orclpdb
set serveroutput on;
select * from App_schema.instructors;


variable ret varchar2(20);
execute :ret := App_administrator.update_instructor('CSC', 'Willis', 'Willa');
select :ret from dual

select * from App_schema.instructors;
--update App_schema.instructors set last_name = 'Johnson';
--select upper(sys_context('userenv', 'session_user')) from dual;
/*
-- connect student
disconnect;
connect SmithW/1234@localhost:1521/orclpdb
*/
disconnect;
connect sys/1234@localhost:1521/orclpdb as sysdba
