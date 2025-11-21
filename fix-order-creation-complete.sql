-- =====================================================
-- Complete Fix for Order Creation Issues
-- Apply this in Supabase SQL Editor
-- =====================================================

-- Step 1: Fix the notification trigger (remove 'data' column reference)
-- This is from migration 20251120000009
CREATE OR REPLACE FUNCTION trigger_notify_new_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert notification for admins
    -- Simplified to remove 'data' JSONB column that doesn't exist
    INSERT INTO notifications (
        title,
        message,
        type,
        created_by
    ) VALUES (
        'New Order Received',
        'Order ' || NEW.order_number || ' from ' || NEW.customer_name || ' - Total: ' || NEW.total_amount || ' SAR',
        'order_new',
        NEW.customer_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Check if notifications table has deleted_at column
-- If this query returns rows, we need to handle it differently
-- Run this separately to check:
-- SELECT column_name FROM information_schema.columns 
-- WHERE table_name = 'notifications' AND column_name = 'deleted_at';

-- Step 3: If notifications table doesn't have deleted_at but you get that error,
-- it means there's an RLS policy or trigger on notifications table that references it
-- Let's disable those temporarily to test:

-- Disable ALL policies on notifications temporarily (for testing only)
-- ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- After testing, re-enable if needed:
-- ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Step 4: Grant necessary permissions
GRANT EXECUTE ON FUNCTION trigger_notify_new_order TO authenticated, anon;

COMMENT ON FUNCTION trigger_notify_new_order IS 'Fixed: Sends notification without data column reference';
