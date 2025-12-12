-- Run this query in Supabase SQL Editor to get the function definition

SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'create_customer_order' 
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
