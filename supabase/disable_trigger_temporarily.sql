-- FINAL FIX: Disable the COD trigger that's breaking clearance certificates
-- The trigger is firing during clearance certificate process and causing errors
-- COD payments will need to be marked as paid manually until we fix this properly

BEGIN;

-- Disable the problematic trigger
ALTER TABLE vendor_payment_schedule DISABLE TRIGGER trigger_auto_create_payment_transaction_and_task;

-- Verify it's disabled
SELECT 
    tgname as trigger_name,
    CASE tgenabled
        WHEN 'O' THEN 'Enabled'
        WHEN 'D' THEN '✅ DISABLED (Good - no more errors)'
        ELSE 'Unknown'
    END as status
FROM pg_trigger
WHERE tgname = 'trigger_auto_create_payment_transaction_and_task';

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '✅ Trigger has been DISABLED';
    RAISE NOTICE '   - Clearance certificate should work now';
    RAISE NOTICE '   - COD payments will need to be marked manually for now';
END $$;
