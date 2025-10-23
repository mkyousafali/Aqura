-- Debug Query: Check Cash-on-Delivery Payments
-- Run this in Supabase SQL Editor to see what's actually in the database

-- 1. Check what payment methods exist
SELECT DISTINCT payment_method, COUNT(*) as count
FROM vendor_payment_schedule
GROUP BY payment_method
ORDER BY payment_method;

-- 2. Check the 9 specific COD payments from your logs
SELECT 
    id,
    payment_method,
    is_paid,
    paid_date,
    payment_status,
    bill_number,
    vendor_name,
    created_at,
    (SELECT COUNT(*) FROM payment_transactions WHERE payment_schedule_id = vendor_payment_schedule.id) as has_transaction
FROM vendor_payment_schedule
WHERE id IN (
    'a3e1dc96-b809-4b13-9764-07a26b6b215c',
    '2554beb9-a442-488d-938a-b9aa04387950',
    '6f38a56c-89f3-4ffe-8af4-26e079adbb52',
    'bb8797b6-4ecb-4260-89af-bbb678a7bad5',
    '9c372b5b-34eb-4131-92b3-1482737db644',
    '740b97db-b559-4dd0-923b-54bb3adf54d1',
    '5888af58-6df6-41c9-97dd-5a6749131940',
    '7503faf3-9f94-4f9f-9c62-2e654cf4cbc0',
    '02cde397-41da-450a-8cc5-125ba32839a9'
)
ORDER BY created_at DESC;

-- 3. Check all unpaid COD-like payments
SELECT 
    id,
    payment_method,
    is_paid,
    bill_number,
    vendor_name,
    (SELECT COUNT(*) FROM payment_transactions WHERE payment_schedule_id = vendor_payment_schedule.id) as has_transaction
FROM vendor_payment_schedule
WHERE 
    (is_paid IS FALSE OR is_paid IS NULL)
    AND (
        payment_method ILIKE '%cash%'
        OR payment_method ILIKE '%cod%'
        OR payment_method ILIKE '%delivery%'
    )
ORDER BY created_at DESC
LIMIT 20;

-- 4. Check if trigger exists
SELECT 
    tgname as trigger_name,
    tgenabled as enabled,
    tgtype as trigger_type
FROM pg_trigger
WHERE tgname = 'trigger_auto_create_payment_transaction_and_task';

-- 5. Check if function exists
SELECT 
    proname as function_name,
    prosrc as function_source_length
FROM pg_proc
WHERE proname = 'auto_create_payment_transaction_and_task';
