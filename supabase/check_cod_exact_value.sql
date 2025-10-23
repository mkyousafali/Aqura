-- Check EXACT payment_method values for those 9 COD payments
-- This will show us the exact string, including spaces and capitalization

SELECT 
    SUBSTRING(id::text, 1, 8) as short_id,
    '|' || payment_method || '|' as payment_method_with_markers,
    is_paid,
    payment_status,
    (SELECT COUNT(*) FROM payment_transactions WHERE payment_schedule_id = vendor_payment_schedule.id) as has_trans
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
);

-- Also check what the trigger is currently looking for
SELECT 
    'Testing pattern match:',
    CASE 
        WHEN 'Cash on Delivery' ILIKE '%cash on delivery%' THEN '✅ Would match'
        ELSE '❌ Would NOT match'
    END as test_result;
