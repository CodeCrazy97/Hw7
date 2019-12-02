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