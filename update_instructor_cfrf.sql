-- allows instructors to update their information (except for id and ename) in the INSTRUCTORS table

begin
	dbms_rls.drop_policy
	(
		object_schema=>'APP_SCHEMA',
		object_name=>'INSTRUCTORS',
		policy_name=>'INSTRUCTOR_SELECT_TFRF'
	);
end;
/

begin
	dbms_rls.add_policy
	(
		object_schema=>'APP_SCHEMA',
		object_name=>'INSTRUCTORS',
		function_schema=>'APP_ADMINISTRATOR',
		policy_function=>'RLS_FUNC',
		policy_name=>'INSTRUCTOR_UPDATE_CFRF',
		statement_types=>'UPDATE',
		sec_relevant_cols=>'ID, ENAME'
	);
end;
/