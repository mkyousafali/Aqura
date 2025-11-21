-- =====================================================
-- Order Management Functions Migration
-- Created: 2025-11-20
-- Description: Creates database functions for order management operations
-- =====================================================

-- Function: Generate unique order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS VARCHAR AS $$
DECLARE
    new_order_number VARCHAR(50);
    counter INTEGER;
BEGIN
    -- Format: ORD-YYYYMMDD-XXXX
    SELECT COUNT(*) + 1 INTO counter
    FROM orders
    WHERE DATE(created_at) = CURRENT_DATE;
    
    new_order_number := 'ORD-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(counter::TEXT, 4, '0');
    
    RETURN new_order_number;
END;
$$ LANGUAGE plpgsql;

-- Function: Create customer order
CREATE OR REPLACE FUNCTION create_customer_order(
    p_customer_id UUID,
    p_branch_id BIGINT,
    p_selected_location JSONB,
    p_fulfillment_method VARCHAR,
    p_payment_method VARCHAR,
    p_subtotal_amount DECIMAL,
    p_delivery_fee DECIMAL,
    p_discount_amount DECIMAL,
    p_tax_amount DECIMAL,
    p_total_amount DECIMAL,
    p_total_items INTEGER,
    p_total_quantity INTEGER,
    p_customer_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
    order_id UUID,
    order_number VARCHAR,
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_order_id UUID;
    v_order_number VARCHAR(50);
    v_customer_name VARCHAR(255);
    v_customer_phone VARCHAR(20);
    v_customer_whatsapp VARCHAR(20);
BEGIN
    -- Get customer information
    SELECT name, whatsapp_number, whatsapp_number
    INTO v_customer_name, v_customer_phone, v_customer_whatsapp
    FROM customers
    WHERE id = p_customer_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL::UUID, NULL::VARCHAR, FALSE, 'Customer not found';
        RETURN;
    END IF;
    
    -- Generate order number
    v_order_number := generate_order_number();
    
    -- Create order
    INSERT INTO orders (
        order_number,
        customer_id,
        customer_name,
        customer_phone,
        customer_whatsapp,
        branch_id,
        selected_location,
        order_status,
        fulfillment_method,
        subtotal_amount,
        delivery_fee,
        discount_amount,
        tax_amount,
        total_amount,
        payment_method,
        payment_status,
        total_items,
        total_quantity,
        customer_notes
    ) VALUES (
        v_order_number,
        p_customer_id,
        v_customer_name,
        v_customer_phone,
        v_customer_whatsapp,
        p_branch_id,
        p_selected_location,
        'new',
        p_fulfillment_method,
        p_subtotal_amount,
        p_delivery_fee,
        p_discount_amount,
        p_tax_amount,
        p_total_amount,
        p_payment_method,
        'pending',
        p_total_items,
        p_total_quantity,
        p_customer_notes
    )
    RETURNING id INTO v_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        to_status,
        notes
    ) VALUES (
        v_order_id,
        'created',
        'new',
        'Order created by customer'
    );
    
    RETURN QUERY SELECT v_order_id, v_order_number, TRUE, 'Order created successfully';
END;
$$ LANGUAGE plpgsql;

-- Function: Accept order
CREATE OR REPLACE FUNCTION accept_order(
    p_order_id UUID,
    p_user_id UUID
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_current_status VARCHAR(50);
    v_user_name VARCHAR(255);
BEGIN
    -- Get current status
    SELECT order_status INTO v_current_status
    FROM orders
    WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Order not found';
        RETURN;
    END IF;
    
    IF v_current_status != 'new' THEN
        RETURN QUERY SELECT FALSE, 'Order can only be accepted from new status';
        RETURN;
    END IF;
    
    -- Get user name
    SELECT username INTO v_user_name
    FROM users
    WHERE id = p_user_id;
    
    -- Update order
    UPDATE orders
    SET order_status = 'accepted',
        accepted_at = NOW(),
        updated_at = NOW(),
        updated_by = p_user_id
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        from_status,
        to_status,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'status_changed',
        'new',
        'accepted',
        p_user_id,
        v_user_name,
        'Order accepted'
    );
    
    RETURN QUERY SELECT TRUE, 'Order accepted successfully';
END;
$$ LANGUAGE plpgsql;

-- Function: Assign picker
CREATE OR REPLACE FUNCTION assign_order_picker(
    p_order_id UUID,
    p_picker_id UUID,
    p_assigned_by UUID
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_picker_name VARCHAR(255);
    v_assigned_by_name VARCHAR(255);
BEGIN
    -- Get picker name
    SELECT username INTO v_picker_name
    FROM users
    WHERE id = p_picker_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Picker not found';
        RETURN;
    END IF;
    
    -- Get assigner name
    SELECT username INTO v_assigned_by_name
    FROM users
    WHERE id = p_assigned_by;
    
    -- Update order
    UPDATE orders
    SET picker_id = p_picker_id,
        picker_assigned_at = NOW(),
        order_status = CASE 
            WHEN order_status = 'accepted' THEN 'in_picking'
            ELSE order_status
        END,
        updated_at = NOW(),
        updated_by = p_assigned_by
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        assigned_user_id,
        assigned_user_name,
        assignment_type,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'assigned_picker',
        p_picker_id,
        v_picker_name,
        'picker',
        p_assigned_by,
        v_assigned_by_name,
        'Picker assigned to order'
    );
    
    RETURN QUERY SELECT TRUE, 'Picker assigned successfully';
END;
$$ LANGUAGE plpgsql;

-- Function: Assign delivery person
CREATE OR REPLACE FUNCTION assign_order_delivery(
    p_order_id UUID,
    p_delivery_person_id UUID,
    p_assigned_by UUID
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_delivery_name VARCHAR(255);
    v_assigned_by_name VARCHAR(255);
BEGIN
    -- Get delivery person name
    SELECT username INTO v_delivery_name
    FROM users
    WHERE id = p_delivery_person_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Delivery person not found';
        RETURN;
    END IF;
    
    -- Get assigner name
    SELECT username INTO v_assigned_by_name
    FROM users
    WHERE id = p_assigned_by;
    
    -- Update order
    UPDATE orders
    SET delivery_person_id = p_delivery_person_id,
        delivery_assigned_at = NOW(),
        order_status = CASE 
            WHEN order_status = 'ready' THEN 'out_for_delivery'
            ELSE order_status
        END,
        updated_at = NOW(),
        updated_by = p_assigned_by
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        assigned_user_id,
        assigned_user_name,
        assignment_type,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'assigned_delivery',
        p_delivery_person_id,
        v_delivery_name,
        'delivery',
        p_assigned_by,
        v_assigned_by_name,
        'Delivery person assigned to order'
    );
    
    RETURN QUERY SELECT TRUE, 'Delivery person assigned successfully';
END;
$$ LANGUAGE plpgsql;

-- Function: Update order status
CREATE OR REPLACE FUNCTION update_order_status(
    p_order_id UUID,
    p_new_status VARCHAR,
    p_user_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_current_status VARCHAR(50);
    v_user_name VARCHAR(255);
BEGIN
    -- Get current status
    SELECT order_status INTO v_current_status
    FROM orders
    WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Order not found';
        RETURN;
    END IF;
    
    -- Get user name
    SELECT username INTO v_user_name
    FROM users
    WHERE id = p_user_id;
    
    -- Update order with status-specific timestamps
    UPDATE orders
    SET order_status = p_new_status,
        ready_at = CASE WHEN p_new_status = 'ready' THEN NOW() ELSE ready_at END,
        delivered_at = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE delivered_at END,
        actual_delivery_time = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE actual_delivery_time END,
        payment_status = CASE WHEN p_new_status = 'delivered' AND payment_method = 'cash' THEN 'paid' ELSE payment_status END,
        updated_at = NOW(),
        updated_by = p_user_id
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        from_status,
        to_status,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'status_changed',
        v_current_status,
        p_new_status,
        p_user_id,
        v_user_name,
        COALESCE(p_notes, 'Status changed to ' || p_new_status)
    );
    
    RETURN QUERY SELECT TRUE, 'Order status updated successfully';
END;
$$ LANGUAGE plpgsql;

-- Function: Cancel order
CREATE OR REPLACE FUNCTION cancel_order(
    p_order_id UUID,
    p_user_id UUID,
    p_cancellation_reason TEXT
)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_current_status VARCHAR(50);
    v_user_name VARCHAR(255);
BEGIN
    -- Get current status
    SELECT order_status INTO v_current_status
    FROM orders
    WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Order not found';
        RETURN;
    END IF;
    
    IF v_current_status = 'delivered' THEN
        RETURN QUERY SELECT FALSE, 'Cannot cancel delivered order';
        RETURN;
    END IF;
    
    IF v_current_status = 'cancelled' THEN
        RETURN QUERY SELECT FALSE, 'Order is already cancelled';
        RETURN;
    END IF;
    
    -- Get user name
    SELECT username INTO v_user_name
    FROM users
    WHERE id = p_user_id;
    
    -- Update order
    UPDATE orders
    SET order_status = 'cancelled',
        cancelled_at = NOW(),
        cancelled_by = p_user_id,
        cancellation_reason = p_cancellation_reason,
        updated_at = NOW(),
        updated_by = p_user_id
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        from_status,
        to_status,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'cancelled',
        v_current_status,
        'cancelled',
        p_user_id,
        v_user_name,
        p_cancellation_reason
    );
    
    RETURN QUERY SELECT TRUE, 'Order cancelled successfully';
END;
$$ LANGUAGE plpgsql;

-- Add comments
COMMENT ON FUNCTION generate_order_number() IS 'Generates unique order number in format ORD-YYYYMMDD-XXXX';
COMMENT ON FUNCTION create_customer_order IS 'Creates new order from customer mobile app';
COMMENT ON FUNCTION accept_order IS 'Admin accepts a new order';
COMMENT ON FUNCTION assign_order_picker IS 'Assigns picker to order for preparation';
COMMENT ON FUNCTION assign_order_delivery IS 'Assigns delivery person to order';
COMMENT ON FUNCTION update_order_status IS 'Updates order status with audit trail';
COMMENT ON FUNCTION cancel_order IS 'Cancels order with reason';
