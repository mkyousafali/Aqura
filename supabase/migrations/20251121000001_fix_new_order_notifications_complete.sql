-- =====================================================
-- Complete Fix for New Order Notifications
-- Created: 2025-11-21
-- Description: Properly notify admin and master admin users when customer places order
-- =====================================================

-- Function to notify admins of new orders with proper recipient creation
CREATE OR REPLACE FUNCTION trigger_notify_new_order()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_name VARCHAR(255);
    v_notification_id UUID;
    v_admin_user RECORD;
BEGIN
    -- Get customer name
    SELECT name INTO v_customer_name
    FROM customers
    WHERE id = NEW.customer_id;
    
    -- Create the notification
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
        'role_based',
        to_jsonb(ARRAY['Admin', 'Master Admin']),
        NOW()
    )
    RETURNING id INTO v_notification_id;
    
    -- Create notification_recipients for all Admin and Master Admin users
    FOR v_admin_user IN 
        SELECT id, role_type
        FROM users
        WHERE status = 'active'
        AND role_type IN ('Admin', 'Master Admin')
    LOOP
        INSERT INTO notification_recipients (
            notification_id,
            user_id,
            role,
            is_read,
            delivery_status
        ) VALUES (
            v_notification_id,
            v_admin_user.id,
            v_admin_user.role_type,
            FALSE,
            'delivered'
        );
    END LOOP;
    
    -- Also queue push notification
    INSERT INTO notification_queue (
        notification_id,
        user_id,
        payload,
        notification_priority,
        status
    )
    SELECT 
        v_notification_id,
        id,
        jsonb_build_object(
            'title', 'New Order Received',
            'body', 'Order ' || NEW.order_number || ' - ' || NEW.total_amount || ' SAR',
            'data', jsonb_build_object(
                'order_id', NEW.id,
                'order_number', NEW.order_number,
                'type', 'order_new'
            )
        ),
        'high',
        'pending'
    FROM users
    WHERE status = 'active'
    AND role_type IN ('Admin', 'Master Admin');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger to ensure it's attached properly
DROP TRIGGER IF EXISTS trigger_new_order_notification ON orders;
CREATE TRIGGER trigger_new_order_notification
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION trigger_notify_new_order();

COMMENT ON FUNCTION trigger_notify_new_order IS 'Notifies all Admin and Master Admin users when a new order is placed';

