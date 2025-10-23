-- Check what's happening with the trigger and payment_transactions table

-- 1. Check the foreign key constraint
SELECT 
    con.conname as constraint_name,
    att.attname as column_name,
    cl.relname as table_name,
    fcl.relname as foreign_table_name
FROM pg_constraint con
JOIN pg_class cl ON con.conrelid = cl.oid
JOIN pg_class fcl ON con.confrelid = fcl.oid
JOIN pg_attribute att ON att.attnum = ANY(con.conkey) AND att.attrelid = cl.oid
WHERE con.conname = 'payment_transactions_payment_schedule_id_fkey';

-- 2. Check if there are any orphaned references
SELECT 
    'Orphaned payment_transactions:' as info,
    COUNT(*) as count
FROM payment_transactions pt
WHERE NOT EXISTS (
    SELECT 1 FROM vendor_payment_schedule vps 
    WHERE vps.id = pt.payment_schedule_id
);

-- 3. Check what table the trigger is attached to
SELECT 
    t.tgname as trigger_name,
    c.relname as table_name,
    p.proname as function_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgname = 'trigger_auto_create_payment_transaction_and_task';
