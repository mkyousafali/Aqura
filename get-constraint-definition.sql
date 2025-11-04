-- Run this SQL in Supabase Dashboard to get the exact constraint definition

-- Get constraint definition
SELECT 
    c.conname AS constraint_name,
    pg_get_constraintdef(c.oid) AS constraint_definition,
    t.relname AS table_name
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE t.relname = 'vendor_payment_schedule'
AND c.conname = 'check_total_deductions_valid'
AND n.nspname = 'public';

-- Also get all constraints on this table
SELECT 
    c.conname AS constraint_name,
    c.contype AS constraint_type,
    pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE t.relname = 'vendor_payment_schedule'
AND n.nspname = 'public'
ORDER BY c.conname;

-- Test the exact calculation that should work
SELECT 
    22401.25 AS bill_amount,
    0 AS discount_amount,
    11837.30 AS grr_amount,
    0 AS pri_amount,
    22401.25 - COALESCE(0, 0) - COALESCE(11837.30, 0) - COALESCE(0, 0) AS calculated_final,
    10563.95 AS expected_final;

-- Check if there are any other numeric columns that might be involved
SELECT 
    column_name,
    data_type,
    numeric_precision,
    numeric_scale
FROM information_schema.columns
WHERE table_name = 'vendor_payment_schedule'
AND table_schema = 'public'
AND data_type IN ('numeric', 'decimal', 'money', 'double precision', 'real')
ORDER BY column_name;