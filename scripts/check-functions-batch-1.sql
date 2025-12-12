-- Query 1: approve_customer_account
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'approve_customer_account' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Query 2: check_user_permission
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'check_user_permission' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Query 3: create_system_admin
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'create_system_admin' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Query 4: get_all_users
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'get_all_users' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Query 5: get_users_with_employee_details
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'get_users_with_employee_details' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
