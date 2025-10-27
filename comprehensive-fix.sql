-- Comprehensive Fix: Remove all references to payment_status
-- This handles views, policies, and cached definitions

-- Step 1: Drop any views that reference vendor_payment_schedule
DO $$
DECLARE
    view_record RECORD;
BEGIN
    FOR view_record IN 
        SELECT schemaname, viewname
        FROM pg_views
        WHERE schemaname = 'public'
        AND (
            viewname LIKE '%vendor_payment%' 
            OR viewname LIKE '%payment_schedule%'
        )
    LOOP
        BEGIN
            EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', view_record.schemaname, view_record.viewname);
            RAISE NOTICE '✓ Dropped view: %.%', view_record.schemaname, view_record.viewname;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Could not drop view %.%: %', view_record.schemaname, view_record.viewname, SQLERRM;
        END;
    END LOOP;
END $$;

-- Step 2: Drop and recreate RLS policies on vendor_payment_schedule
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    -- First disable RLS temporarily
    ALTER TABLE vendor_payment_schedule DISABLE ROW LEVEL SECURITY;
    
    -- Drop all existing policies
    FOR policy_record IN 
        SELECT policyname
        FROM pg_policies
        WHERE tablename = 'vendor_payment_schedule'
    LOOP
        BEGIN
            EXECUTE format('DROP POLICY IF EXISTS %I ON vendor_payment_schedule', policy_record.policyname);
            RAISE NOTICE '✓ Dropped policy: %', policy_record.policyname;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Could not drop policy %: %', policy_record.policyname, SQLERRM;
        END;
    END LOOP;
    
    -- Re-enable RLS
    ALTER TABLE vendor_payment_schedule ENABLE ROW LEVEL SECURITY;
    
    RAISE NOTICE '✓ RLS policies reset';
END $$;

-- Step 3: Create simple RLS policies (adjust based on your security needs)
-- Allow authenticated users to read
CREATE POLICY "Enable read access for authenticated users" ON vendor_payment_schedule
    FOR SELECT
    USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- Allow authenticated users to insert
CREATE POLICY "Enable insert access for authenticated users" ON vendor_payment_schedule
    FOR INSERT
    WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- Allow authenticated users to update
CREATE POLICY "Enable update access for authenticated users" ON vendor_payment_schedule
    FOR UPDATE
    USING (auth.role() = 'authenticated' OR auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- Allow authenticated users to delete
CREATE POLICY "Enable delete access for authenticated users" ON vendor_payment_schedule
    FOR DELETE
    USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- Step 4: Refresh schema cache (force PostgreSQL to reload metadata)
SELECT pg_notify('pgrst', 'reload schema');

-- Step 5: Final verification
DO $$
DECLARE
    trigger_count INTEGER;
    func_count INTEGER;
    view_count INTEGER;
    policy_count INTEGER;
    has_payment_status BOOLEAN;
    has_is_paid BOOLEAN;
BEGIN
    -- Count remaining triggers
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers
    WHERE event_object_table = 'vendor_payment_schedule';
    
    -- Count remaining related functions
    SELECT COUNT(*) INTO func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND (
        p.proname LIKE '%vendor_payment%'
        OR p.proname LIKE '%payment_status%'
        OR p.proname LIKE '%payment_schedule%'
    );
    
    -- Count related views
    SELECT COUNT(*) INTO view_count
    FROM pg_views
    WHERE schemaname = 'public'
    AND (
        viewname LIKE '%vendor_payment%'
        OR viewname LIKE '%payment_schedule%'
    );
    
    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'vendor_payment_schedule';
    
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
    RAISE NOTICE '✅ Comprehensive Fix Complete';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 Status:';
    RAISE NOTICE '   Remaining triggers: %', trigger_count;
    RAISE NOTICE '   Remaining functions: %', func_count;
    RAISE NOTICE '   Remaining views: %', view_count;
    RAISE NOTICE '   RLS policies count: %', policy_count;
    RAISE NOTICE '   Has payment_status column: %', has_payment_status;
    RAISE NOTICE '   Has is_paid column: %', has_is_paid;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    
    IF trigger_count = 0 AND NOT has_payment_status AND has_is_paid THEN
        RAISE NOTICE '✅ All checks passed! Database is ready.';
        RAISE NOTICE '';
        RAISE NOTICE '🔄 Next steps:';
        RAISE NOTICE '   1. Restart your application server';
        RAISE NOTICE '   2. Clear browser cache (Ctrl+Shift+Delete)';
        RAISE NOTICE '   3. Hard refresh (Ctrl+F5)';
    ELSE
        RAISE WARNING '⚠️  Some issues may remain. Check the status above.';
    END IF;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
