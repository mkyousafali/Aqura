-- =====================================================
-- Fix Order Trigger - Remove data column from notifications insert
-- Created: 2025-11-20
-- Description: Update trigger_notify_new_order to not use 'data' column
-- =====================================================

-- Drop and recreate the trigger function with proper notification columns
CREATE OR REPLACE FUNCTION trigger_notify_new_order()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_name VARCHAR(255);
BEGIN
    -- Get customer name
    SELECT name INTO v_customer_name
    FROM customers
    WHERE id = NEW.customer_id;
    
    -- Insert notification for admins with all required fields
    INSERT INTO notifications (
        title,
        message,
        type,
        created_by,
        created_by_name,
        created_by_role,
        priority,
        status,
        target_type,
        target_roles,
        sent_at
    ) VALUES (
        'New Order Received',
        'Order ' || NEW.order_number || ' from ' || COALESCE(v_customer_name, NEW.customer_name) || ' - Total: ' || NEW.total_amount || ' SAR',
        'order_new',
        NEW.customer_id::text,
        COALESCE(v_customer_name, NEW.customer_name),
        'Customer',
        'high',
        'published',
        'all_admins',
        to_jsonb(ARRAY['Admin', 'Master Admin', 'Operations Manager', 'Branch Manager']),
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_notify_new_order IS 'Trigger function to notify admins of new orders with complete notification structure';
