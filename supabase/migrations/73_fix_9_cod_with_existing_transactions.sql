-- Migration 73: Fix the 9 COD Payments with Existing Transactions
-- These payments have transactions but is_paid = FALSE
-- We need to update is_paid WITHOUT creating duplicate transactions

BEGIN;

-- Temporarily disable the trigger to prevent duplicate transaction creation
ALTER TABLE vendor_payment_schedule DISABLE TRIGGER trigger_auto_create_payment_transaction_and_task;

-- Update the 9 specific COD payments that already have transactions
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
);

-- Re-enable the trigger for future operations
ALTER TABLE vendor_payment_schedule ENABLE TRIGGER trigger_auto_create_payment_transaction_and_task;

-- Verify the fix
SELECT 
    'After fix:' as status,
    SUBSTRING(id::text, 1, 8) as short_id,
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

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 73 completed!';
    RAISE NOTICE '   - Updated 9 COD payments to is_paid = TRUE';
    RAISE NOTICE '   - Did NOT create duplicate transactions';
    RAISE NOTICE '   - Trigger re-enabled for future COD payments';
END $$;
