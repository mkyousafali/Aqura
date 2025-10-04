-- COMPLETE Database Fix for Warning System
-- Execute this in Supabase SQL Editor to fix ALL warning system issues

-- Fix 1: Drop and recreate sync_fine_paid_columns function
DROP FUNCTION IF EXISTS sync_fine_paid_columns() CASCADE;

CREATE OR REPLACE FUNCTION sync_fine_paid_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Update fine_paid_date and fine_paid_at based on fine_status (NOT fine_payment_status)
    IF NEW.fine_status = 'paid' THEN
        NEW.fine_paid_date = COALESCE(NEW.fine_paid_date, CURRENT_TIMESTAMP::date);
        NEW.fine_paid_at = COALESCE(NEW.fine_paid_at, CURRENT_TIMESTAMP);
    ELSIF NEW.fine_status IN ('pending', 'cancelled', 'waived') THEN
        -- Clear paid date/time if status changes from paid to something else
        IF OLD.fine_status = 'paid' AND NEW.fine_status != 'paid' THEN
            NEW.fine_paid_date = NULL;
            NEW.fine_paid_at = NULL;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Fix 2: Drop and recreate create_warning_history function 
DROP FUNCTION IF EXISTS create_warning_history() CASCADE;

CREATE OR REPLACE FUNCTION create_warning_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle different trigger operations
    IF TG_OP = 'INSERT' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            new_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            NEW.id,
            'created',
            row_to_json(NEW),
            NEW.issued_by,
            NEW.issued_by_username,
            'Warning created'
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            old_values,
            new_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            NEW.id,
            'updated',
            row_to_json(OLD),
            row_to_json(NEW),
            NEW.issued_by,
            NEW.issued_by_username,
            'Warning updated'
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            old_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            OLD.id,
            'deleted',
            row_to_json(OLD),
            OLD.deleted_by,
            'system',
            'Warning deleted'
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Fix 3: Recreate all triggers
DROP TRIGGER IF EXISTS trigger_sync_fine_paid_columns ON employee_warnings;
DROP TRIGGER IF EXISTS trigger_create_warning_history ON employee_warnings;

CREATE TRIGGER trigger_sync_fine_paid_columns 
    BEFORE INSERT OR UPDATE ON employee_warnings 
    FOR EACH ROW
    EXECUTE FUNCTION sync_fine_paid_columns();

CREATE TRIGGER trigger_create_warning_history
    AFTER INSERT OR DELETE OR UPDATE ON employee_warnings 
    FOR EACH ROW
    EXECUTE FUNCTION create_warning_history();

-- Verification
SELECT 'Database triggers and functions fixed successfully' as status;

-- Check functions exist
SELECT 
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname IN ('sync_fine_paid_columns', 'create_warning_history');