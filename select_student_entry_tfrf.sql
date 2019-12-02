-- allows students to view only their own records in the students table

begin
	dbms_rls.add_policy
	(
		object_schema=>'APP_SCHEMA',
		object_name=>'STUDENTS',
		function_schema=>'APP_ADMINISTRATOR',
		policy_function=>'RLS_FUNC',
		policy_name=>'STUDENT_SELECT_TFRF',
		statement_types=>'SELECT'
	);
end;
/