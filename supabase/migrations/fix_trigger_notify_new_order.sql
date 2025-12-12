-- Fix trigger_notify_new_order function to use is_admin and is_master_admin instead of role_type

CREATE OR REPLACE FUNCTION public.trigger_notify_new_order()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
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
    -- Use is_admin and is_master_admin flags instead of role_type
    FOR v_admin_user IN 
        SELECT id, 
               CASE 
                   WHEN is_master_admin THEN 'Master Admin'
                   WHEN is_admin THEN 'Admin'
                   ELSE 'User'
               END as role_type
        FROM users
        WHERE status = 'active'
        AND (is_admin = true OR is_master_admin = true)
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
    
    -- Skip push notification queue (notification_queue table doesn't exist)
    -- TODO: Implement push notification system if needed
    
    RETURN NEW;
END;
$function$;
