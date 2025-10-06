-- COMPLETE REVERT SCRIPT for Push Subscriptions Auto-Cleanup
-- Run this in Supabase SQL Editor to remove all auto-cleanup functions and triggers
-- This ensures your database is back to the original state

-- =================================================================
-- STEP 1: Remove all auto-cleanup triggers
-- =================================================================

DROP TRIGGER IF EXISTS trigger_cleanup_old_push_subscriptions ON push_subscriptions;
DROP TRIGGER IF EXISTS trigger_auto_cleanup_on_login ON user_sessions;

-- =================================================================
-- STEP 2: Remove all auto-cleanup functions
-- =================================================================

DROP FUNCTION IF EXISTS cleanup_old_push_subscriptions();
DROP FUNCTION IF EXISTS auto_cleanup_push_subscriptions_on_login();
DROP FUNCTION IF EXISTS register_push_subscription(uuid, character varying, text, text, text, character varying, character varying, text);
DROP FUNCTION IF EXISTS get_user_push_subscriptions(uuid);

-- =================================================================
-- STEP 3: Ensure original triggers are in place (if they were there)
-- =================================================================

-- Check if the update function exists, if not create it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'update_push_subscriptions_updated_at'
        AND routine_schema = 'public'
    ) THEN
        -- Create the basic update function if it doesn't exist
        EXECUTE '
        CREATE OR REPLACE FUNCTION update_push_subscriptions_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = now();
            RETURN NEW;
        END;
        $func$ LANGUAGE plpgsql;
        ';
    END IF;
END
$$;

-- Recreate original triggers if they don't exist
DO $$
BEGIN
    -- Check and create first trigger
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'trigger_push_subscriptions_updated_at'
        AND event_object_table = 'push_subscriptions'
    ) THEN
        EXECUTE '
        CREATE TRIGGER trigger_push_subscriptions_updated_at 
            BEFORE UPDATE ON push_subscriptions 
            FOR EACH ROW
            EXECUTE FUNCTION update_push_subscriptions_updated_at();
        ';
    END IF;

    -- Check and create second trigger (if it was originally there)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'trigger_update_push_subscriptions_updated_at'
        AND event_object_table = 'push_subscriptions'
    ) THEN
        EXECUTE '
        CREATE TRIGGER trigger_update_push_subscriptions_updated_at 
            BEFORE UPDATE ON push_subscriptions 
            FOR EACH ROW
            EXECUTE FUNCTION update_push_subscriptions_updated_at();
        ';
    END IF;
END
$$;

-- =================================================================
-- STEP 4: Verification queries
-- =================================================================

-- Show remaining functions related to push subscriptions
SELECT 
    routine_name, 
    routine_type,
    'Function exists' as status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%push_subscription%'
ORDER BY routine_name;

-- Show remaining triggers on push_subscriptions table
SELECT 
    trigger_name, 
    event_manipulation,
    action_timing,
    'Trigger exists' as status
FROM information_schema.triggers 
WHERE event_object_table = 'push_subscriptions'
ORDER BY trigger_name;

-- =================================================================
-- FINAL STATUS MESSAGE
-- =================================================================

SELECT 
    '✅ REVERT COMPLETE! All auto-cleanup functions and triggers have been removed.' as status,
    'Your push_subscriptions table is back to its original state.' as message,
    'Only basic update triggers remain (if they were originally there).' as note;