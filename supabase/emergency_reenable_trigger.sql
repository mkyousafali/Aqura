-- Emergency Fix: Re-enable the trigger if it's still disabled

BEGIN;

-- Check current status
DO $$
DECLARE
    v_trigger_status CHAR(1);
BEGIN
    SELECT tgenabled INTO v_trigger_status
    FROM pg_trigger
    WHERE tgname = 'trigger_auto_create_payment_transaction_and_task';
    
    IF v_trigger_status = 'D' THEN
        RAISE NOTICE '❌ Trigger is DISABLED - re-enabling now...';
    ELSE
        RAISE NOTICE '✅ Trigger is already ENABLED';
    END IF;
END $$;

-- Force enable the trigger
ALTER TABLE vendor_payment_schedule ENABLE TRIGGER trigger_auto_create_payment_transaction_and_task;

-- Verify it's enabled
SELECT 
    tgname as trigger_name,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled (ERROR!)'
        ELSE 'Unknown'
    END as status
FROM pg_trigger
WHERE tgname = 'trigger_auto_create_payment_transaction_and_task';

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '✅ Trigger has been re-enabled';
    RAISE NOTICE '   - Future COD payments will now work correctly';
    RAISE NOTICE '   - The clearance certificate error should be fixed';
END $$;
