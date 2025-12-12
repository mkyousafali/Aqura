-- Run this query in Supabase SQL Editor to get generate_order_number function

SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'generate_order_number' 
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
