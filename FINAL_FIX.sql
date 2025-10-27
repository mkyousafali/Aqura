-- COMPREHENSIVE FIX: Remove all payment_status references and update triggers

-- Step 1: Drop ALL triggers on both tables
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop triggers on receiving_records
    FOR r IN (
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'receiving_records'
        AND event_object_schema = 'public'
    ) LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON receiving_records CASCADE', r.trigger_name);
        RAISE NOTICE '✓ Dropped trigger on receiving_records: %', r.trigger_name;
    END LOOP;
    
    -- Drop triggers on vendor_payment_schedule
    FOR r IN (
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'vendor_payment_schedule'
        AND event_object_schema = 'public'
    ) LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON vendor_payment_schedule CASCADE', r.trigger_name);
        RAISE NOTICE '✓ Dropped trigger on vendor_payment_schedule: %', r.trigger_name;
    END LOOP;
END $$;

-- Step 2: Drop ALL functions that reference payment_status
DO $$
DECLARE
    r RECORD;
    func_def TEXT;
BEGIN
    FOR r IN (
        SELECT 
            n.nspname,
            p.proname,
            p.oid
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
    ) LOOP
        -- Check function definition for payment_status
        func_def := pg_get_functiondef(r.oid);
        
        IF func_def ILIKE '%payment_status%' THEN
            BEGIN
                EXECUTE format('DROP FUNCTION IF EXISTS %I.%I CASCADE', r.nspname, r.proname);
                RAISE NOTICE '✓ Dropped function: %.%', r.nspname, r.proname;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE '⚠ Could not drop function: %.% - %', r.nspname, r.proname, SQLERRM;
            END;
        END IF;
    END LOOP;
END $$;

-- Step 3: Ensure payment_status column is completely removed
ALTER TABLE vendor_payment_schedule DROP COLUMN IF EXISTS payment_status CASCADE;

-- Step 4: Ensure is_paid column exists with proper setup
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'vendor_payment_schedule'
        AND column_name = 'is_paid'
    ) THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN is_paid BOOLEAN DEFAULT false;
    END IF;
    
    ALTER TABLE vendor_payment_schedule ALTER COLUMN is_paid SET DEFAULT false;
    UPDATE vendor_payment_schedule SET is_paid = false WHERE is_paid IS NULL;
END $$;

-- Step 5: Create index for performance
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_is_paid ON vendor_payment_schedule(is_paid);

-- Step 6: Add column comment
COMMENT ON COLUMN vendor_payment_schedule.is_paid IS 'Boolean flag: true=paid, false=not paid';

-- Step 7: Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- Step 8: Final verification
DO $$
DECLARE
    receiving_triggers INTEGER;
    payment_triggers INTEGER;
    funcs_with_payment_status INTEGER := 0;
    has_payment_status BOOLEAN;
    has_is_paid BOOLEAN;
    r RECORD;
    func_def TEXT;
BEGIN
    SELECT COUNT(*) INTO receiving_triggers
    FROM information_schema.triggers
    WHERE event_object_table = 'receiving_records';
    
    SELECT COUNT(*) INTO payment_triggers
    FROM information_schema.triggers
    WHERE event_object_table = 'vendor_payment_schedule';
    
    -- Count functions with payment_status by iterating
    FOR r IN (
        SELECT p.oid
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
    ) LOOP
        func_def := pg_get_functiondef(r.oid);
        IF func_def ILIKE '%payment_status%' THEN
            funcs_with_payment_status := funcs_with_payment_status + 1;
        END IF;
    END LOOP;
    
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
    RAISE NOTICE '✅ COMPREHENSIVE FIX COMPLETED';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 Results:';
    RAISE NOTICE '   Triggers on receiving_records: %', receiving_triggers;
    RAISE NOTICE '   Triggers on vendor_payment_schedule: %', payment_triggers;
    RAISE NOTICE '   Functions with payment_status: %', funcs_with_payment_status;
    RAISE NOTICE '   Has payment_status column: %', has_payment_status;
    RAISE NOTICE '   Has is_paid column: %', has_is_paid;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    
    IF funcs_with_payment_status = 0 AND NOT has_payment_status AND has_is_paid THEN
        RAISE NOTICE '✅ SUCCESS! All payment_status references removed!';
        RAISE NOTICE '';
        RAISE NOTICE '🔄 NEXT STEPS:';
        RAISE NOTICE '   1. Clear browser cache (Ctrl+Shift+Delete)';
        RAISE NOTICE '   2. Restart your dev server';
        RAISE NOTICE '   3. Hard refresh browser (Ctrl+F5)';
        RAISE NOTICE '   4. Test the clearance certificate generation';
    ELSE
        RAISE WARNING '⚠️  ATTENTION REQUIRED:';
        IF funcs_with_payment_status > 0 THEN
            RAISE WARNING '   → % functions still reference payment_status', funcs_with_payment_status;
            RAISE WARNING '   → Run check-receiving-triggers.sql to identify them';
        END IF;
        IF has_payment_status THEN
            RAISE WARNING '   → payment_status column still exists!';
        END IF;
        IF NOT has_is_paid THEN
            RAISE WARNING '   → is_paid column is missing!';
        END IF;
    END IF;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
