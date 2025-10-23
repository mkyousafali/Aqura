-- Check ALL triggers that might be affecting clearance certificate process

-- 1. Check triggers on receiving_records table
SELECT 
    'receiving_records' as table_name,
    tgname as trigger_name,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE 'Unknown'
    END as status,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'receiving_records'::regclass
AND tgname NOT LIKE 'RI_%';  -- Exclude foreign key triggers

-- 2. Check triggers on tasks table
SELECT 
    'tasks' as table_name,
    tgname as trigger_name,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE 'Unknown'
    END as status,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'tasks'::regclass
AND tgname NOT LIKE 'RI_%';

-- 3. Check triggers on vendor_payment_schedule table
SELECT 
    'vendor_payment_schedule' as table_name,
    tgname as trigger_name,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE 'Unknown'
    END as status,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'vendor_payment_schedule'::regclass
AND tgname NOT LIKE 'RI_%';

-- 4. Check triggers on payment_transactions table
SELECT 
    'payment_transactions' as table_name,
    tgname as trigger_name,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE 'Unknown'
    END as status,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'payment_transactions'::regclass
AND tgname NOT LIKE 'RI_%';
