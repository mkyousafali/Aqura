-- Manual Fix: Mark those 9 specific COD payments as paid
-- This bypasses the trigger and directly updates the records
-- Use this if migrations 70, 71, 72 are not working

BEGIN;

-- First, check current status
SELECT 
    'BEFORE UPDATE:' as status,
    id,
    payment_method,
    is_paid,
    payment_status,
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
);

-- Forcefully mark as paid (this will trigger the BEFORE UPDATE trigger)
UPDATE vendor_payment_schedule
SET 
    is_paid = TRUE,
    paid_date = COALESCE(paid_date, NOW()),
    payment_status = 'paid',
    updated_at = NOW()
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
AND is_paid IS NOT TRUE;  -- Only update if not already paid

-- Check after update
SELECT 
    'AFTER UPDATE:' as status,
    id,
    payment_method,
    is_paid,
    payment_status,
    paid_date,
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
);

COMMIT;

-- Show summary
DO $$
BEGIN
    RAISE NOTICE '✅ Manual fix completed for 9 COD payments';
    RAISE NOTICE '   - Check the BEFORE/AFTER results above';
    RAISE NOTICE '   - Reload payment manager to see changes';
END $$;
