-- Emergency Fix: Force drop all triggers and functions on vendor_payment_schedule
-- Run this if the migration didn't work properly

-- Step 1: Drop ALL triggers on vendor_payment_schedule
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'vendor_payment_schedule'
        AND event_object_schema = 'public'
    ) LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON vendor_payment_schedule CASCADE', r.trigger_name);
        RAISE NOTICE 'Dropped trigger: %', r.trigger_name;
    END LOOP;
END $$;

-- Step 2: Drop ALL functions with vendor_payment or payment in the name
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%vendor_payment%'
            OR p.proname LIKE '%payment_status%'
            OR p.proname LIKE '%payment_schedule%'
        )
    ) LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %I.%I(%s) CASCADE', r.nspname, r.proname, r.args);
        RAISE NOTICE 'Dropped function: %.%(%)', r.nspname, r.proname, r.args;
    END LOOP;
END $$;

-- Step 3: Verify payment_status column is gone
DO $$
DECLARE
    col_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'vendor_payment_schedule'
        AND column_name = 'payment_status'
    ) INTO col_exists;
    
    IF col_exists THEN
        ALTER TABLE vendor_payment_schedule DROP COLUMN payment_status CASCADE;
        RAISE NOTICE '✓ Dropped payment_status column';
    ELSE
        RAISE NOTICE '✓ payment_status column already removed';
    END IF;
END $$;

-- Step 4: Ensure is_paid column exists and has proper defaults
DO $$
BEGIN
    -- Add is_paid if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'vendor_payment_schedule'
        AND column_name = 'is_paid'
    ) THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN is_paid BOOLEAN DEFAULT false;
        RAISE NOTICE '✓ Added is_paid column';
    ELSE
        RAISE NOTICE '✓ is_paid column already exists';
    END IF;
    
    -- Set default for is_paid
    ALTER TABLE vendor_payment_schedule ALTER COLUMN is_paid SET DEFAULT false;
    
    -- Update any NULL values to false
    UPDATE vendor_payment_schedule SET is_paid = false WHERE is_paid IS NULL;
END $$;

-- Step 5: Create index on is_paid
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_is_paid ON vendor_payment_schedule(is_paid);

-- Step 6: Add comment
COMMENT ON COLUMN vendor_payment_schedule.is_paid IS 'Boolean flag indicating if payment has been completed (true=paid, false=not paid)';

-- Final verification
DO $$
DECLARE
    trigger_count INTEGER;
    func_count INTEGER;
    has_payment_status BOOLEAN;
    has_is_paid BOOLEAN;
BEGIN
    -- Count remaining triggers
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers
    WHERE event_object_table = 'vendor_payment_schedule';
    
    -- Count remaining functions
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND (
        p.proname LIKE '%vendor_payment%'
        OR p.proname LIKE '%payment_status%'
        OR p.proname LIKE '%payment_schedule%'
    );
    
    -- Check columns
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'vendor_payment_schedule'
        AND column_name = 'payment_status'
    ) INTO has_payment_status;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'vendor_payment_schedule'
        AND column_name = 'is_paid'
    ) INTO has_is_paid;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Emergency Fix Complete';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 Status:';
    RAISE NOTICE '   Remaining triggers: %', trigger_count;
    RAISE NOTICE '   Remaining functions: %', func_count;
    RAISE NOTICE '   Has payment_status column: %', has_payment_status;
    RAISE NOTICE '   Has is_paid column: %', has_is_paid;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    
    IF trigger_count = 0 AND func_count = 0 AND NOT has_payment_status AND has_is_paid THEN
        RAISE NOTICE '✅ All checks passed! Database is ready.';
    ELSE
        RAISE WARNING '⚠️  Some issues may remain. Check the status above.';
    END IF;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
