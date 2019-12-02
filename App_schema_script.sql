-- this script should be run by App_schema

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
