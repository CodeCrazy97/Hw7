-- allows instructors to view their own entry in the INSTRUCTORS table

begin
	dbms_rls.add_policy
	(
		object_schema=>'APP_SCHEMA',
		object_name=>'INSTRUCTORS',
		function_schema=>'APP_ADMINISTRATOR',
		policy_function=>'RLS_FUNC',
		policy_name=>'INSTRUCTOR_SELECT_TFRF',
		statement_types=>'SELECT'
	);
end;
/