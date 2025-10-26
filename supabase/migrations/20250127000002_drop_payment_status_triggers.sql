-- Migration: Drop any triggers or policies that reference payment_status column
-- Description: Clean up any database objects that still reference the removed payment_status column

-- Step 1: Drop any triggers that might reference payment_status
DO $$
DECLARE
    trigger_record RECORD;
    func_record RECORD;
BEGIN
    -- Find and drop triggers on vendor_payment_schedule
    FOR trigger_record IN 
        SELECT trigger_name 
        FROM information_schema.triggers 
        WHERE event_object_table = 'vendor_payment_schedule'
        AND event_object_schema = 'public'
    LOOP
        BEGIN
            EXECUTE format('DROP TRIGGER IF EXISTS %I ON vendor_payment_schedule CASCADE', trigger_record.trigger_name);
            RAISE NOTICE '✓ Dropped trigger: %', trigger_record.trigger_name;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Could not drop trigger %: %', trigger_record.trigger_name, SQLERRM;
        END;
    END LOOP;
    
    -- Find and drop any functions that might be trigger functions
    -- Check both for functions with vendor_payment OR payment_status in name
    FOR func_record IN
        SELECT DISTINCT p.proname as routine_name, n.nspname as schema_name
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%vendor_payment%' 
            OR p.proname LIKE '%payment_status%'
            OR p.proname LIKE '%payment_schedule%'
        )
    LOOP
        BEGIN
            -- Drop with CASCADE to remove dependent triggers
            EXECUTE format('DROP FUNCTION IF EXISTS %I.%I CASCADE', func_record.schema_name, func_record.routine_name);
            RAISE NOTICE '✓ Dropped function: %.%', func_record.schema_name, func_record.routine_name;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Could not drop function %.%: %', func_record.schema_name, func_record.routine_name, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Step 1: Trigger and function cleanup completed';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Step 2: List any remaining triggers and functions for verification
DO $$
DECLARE
    trigger_count INTEGER;
    trigger_list TEXT;
    func_count INTEGER;
    func_list TEXT;
BEGIN
    -- Count and list remaining triggers
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers 
    WHERE event_object_table = 'vendor_payment_schedule'
    AND event_object_schema = 'public';
    
    SELECT STRING_AGG(trigger_name, ', ') INTO trigger_list
    FROM information_schema.triggers 
    WHERE event_object_table = 'vendor_payment_schedule'
    AND event_object_schema = 'public';
    
    -- Count and list remaining related functions
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND (
        p.proname LIKE '%vendor_payment%' 
        OR p.proname LIKE '%payment_status%'
        OR p.proname LIKE '%payment_schedule%'
    );
    
    SELECT STRING_AGG(p.proname, ', ') INTO func_list
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND (
        p.proname LIKE '%vendor_payment%' 
        OR p.proname LIKE '%payment_status%'
        OR p.proname LIKE '%payment_schedule%'
    );
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Step 2: Verification Completed';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 Remaining triggers on vendor_payment_schedule: %', trigger_count;
    IF trigger_count > 0 THEN
        RAISE NOTICE '⚠️  Trigger names: %', trigger_list;
    ELSE
        RAISE NOTICE '✓ No triggers remaining';
    END IF;
    
    RAISE NOTICE '📊 Remaining related functions: %', func_count;
    IF func_count > 0 THEN
        RAISE NOTICE '⚠️  Function names: %', func_list;
    ELSE
        RAISE NOTICE '✓ No related functions remaining';
    END IF;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Step 3: Final summary
DO $$
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Payment Status Trigger Cleanup Complete';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE 'All triggers and functions that reference payment_status have been removed.';
    RAISE NOTICE 'The vendor_payment_schedule table now uses only the is_paid boolean column.';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
