-- users to create App_Admin (app admin) (AA1234)
-- App_Schema (App Schema) (AS1234)
-- LayJ	(Staff in registrar) (L1234)
-- Davis (Student) (D1234)
-- YangM  (Instructor)  (Y1234)

-- *can we use same tablespace and temp tablespace for multiple users

------
drop User App_Admin Cascade;
create user App_Admin
identified by AA1234
default tablespace users
Temporary tablespace temp
Quota 25M on users
Profile default;

Grant create session privilege;


------
drop User App_Schema Cascade;
create user App_Schema 
identified by AS1234
default tablespace users
Temporary tablespace temp
Quota 25M on users
Profile default;

Grant create session privilege;

------
drop User LayJ Cascade;
create user LayJ
identified by L1234
default tablespace users
Temporary tablespace temp
Quota 25 on users
Profile default;

Grant create session privilege;

------
drop User DavisC Cascade;
create user DavisC
identified by D1234
default tablespace users
Temporary tablespace temp
Quota 25 on users
Profile default;

Grant create session privilege;


------
drop User YangM Cascade;
create user YangM
identified by Y1234
default tablespace users
Temporary tablespace temp
Quota 25 on users
Profile default;

Grant create session privilege;

--------------------------------------------------------------------------------
-- ename is a virtual column. Its value derives form last_name and first_name, by
-- including the last name followed by the first letter of the first name.
-- eg. Bereket Degefa = degefab


-- create tablespace and quota for the tables and all necessary views 
create table STUDENTS (
	id number(9, 0) primary key,
	last_name varchar2(30),
	first_name varchar2(30),
	ename varchar2(31) as (last_name || SUBSTR(first_name, 1,1)) unique,
	major varchar2(25)	
);


create table instructors (
	id number(9, 0) primary key,
	last_name varchar2(30),
	first_name varchar2(30),
	ename varchar2(31) as (last_name || SUBSTR(first_name, 1,1)) unique,
	dept varchar2(3)
);


create table courses (
	crn number(5, 0) primary key,
	instructor_id number(9, 0)
);


create table enrollment (
	student_id number(9, 0),
	crn number(5, 0),
	grade number(4)	
);

