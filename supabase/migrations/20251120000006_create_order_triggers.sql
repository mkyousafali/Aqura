-- =====================================================
-- Order Management Triggers Migration
-- Created: 2025-11-20
-- Description: Creates triggers for order status changes, audit logging, and notifications
-- =====================================================

-- Trigger Function: Auto-create audit log on order status change
CREATE OR REPLACE FUNCTION trigger_order_status_audit()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if status actually changed
    IF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
        INSERT INTO order_audit_logs (
            order_id,
            action_type,
            from_status,
            to_status,
            performed_by,
            notes
        ) VALUES (
            NEW.id,
            'status_changed',
            OLD.order_status,
            NEW.order_status,
            NEW.updated_by,
            'Status changed from ' || OLD.order_status || ' to ' || NEW.order_status
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger Function: Notify admins when new order created
CREATE OR REPLACE FUNCTION trigger_notify_new_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert notification for admins
    -- Note: This assumes a notifications table exists for in-app notifications
    -- Actual push notifications would be handled by the application layer
    
    INSERT INTO notifications (
        title,
        message,
        type,
        data,
        created_by
    ) VALUES (
        'New Order Received',
        'Order ' || NEW.order_number || ' from ' || NEW.customer_name,
        'order_new',
        jsonb_build_object(
            'order_id', NEW.id,
            'order_number', NEW.order_number,
            'customer_name', NEW.customer_name,
            'total_amount', NEW.total_amount,
            'branch_id', NEW.branch_id
        ),
        NEW.customer_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger Function: Update order item counts
CREATE OR REPLACE FUNCTION trigger_update_order_totals()
RETURNS TRIGGER AS $$
BEGIN
    -- Recalculate total items and quantities when order_items change
    UPDATE orders
    SET total_items = (
            SELECT COUNT(*)
            FROM order_items
            WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
        ),
        total_quantity = (
            SELECT COALESCE(SUM(quantity), 0)
            FROM order_items
            WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
        ),
        updated_at = NOW()
    WHERE id = COALESCE(NEW.order_id, OLD.order_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger Function: Log offer usage when order is created
CREATE OR REPLACE FUNCTION trigger_log_order_offer_usage()
RETURNS TRIGGER AS $$
BEGIN
    -- Update offer_usage_logs with order_id for items that have offers
    UPDATE offer_usage_logs
    SET order_id = NEW.order_id
    WHERE offer_id IN (
        SELECT offer_id
        FROM order_items
        WHERE order_id = NEW.order_id
        AND has_offer = TRUE
        AND offer_id IS NOT NULL
    )
    AND order_id IS NULL
    AND customer_id = (
        SELECT customer_id FROM orders WHERE id = NEW.order_id
    )
    AND created_at >= (
        SELECT created_at FROM orders WHERE id = NEW.order_id
    ) - INTERVAL '1 minute';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create Triggers
-- Trigger: Update updated_at timestamp (already exists, just ensuring it's applied)
DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Trigger: Auto-audit on status change
DROP TRIGGER IF EXISTS trigger_order_status_change_audit ON orders;
CREATE TRIGGER trigger_order_status_change_audit
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
    EXECUTE FUNCTION trigger_order_status_audit();

-- Trigger: Notify on new order
DROP TRIGGER IF EXISTS trigger_new_order_notification ON orders;
CREATE TRIGGER trigger_new_order_notification
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION trigger_notify_new_order();

-- Trigger: Update order totals when items change
DROP TRIGGER IF EXISTS trigger_order_items_insert_totals ON order_items;
CREATE TRIGGER trigger_order_items_insert_totals
    AFTER INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_order_totals();

DROP TRIGGER IF EXISTS trigger_order_items_update_totals ON order_items;
CREATE TRIGGER trigger_order_items_update_totals
    AFTER UPDATE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_order_totals();

DROP TRIGGER IF EXISTS trigger_order_items_delete_totals ON order_items;
CREATE TRIGGER trigger_order_items_delete_totals
    AFTER DELETE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_order_totals();

-- Trigger: Link offer usage to orders
DROP TRIGGER IF EXISTS trigger_link_offer_usage_to_order ON order_items;
CREATE TRIGGER trigger_link_offer_usage_to_order
    AFTER INSERT ON order_items
    FOR EACH ROW
    WHEN (NEW.has_offer = TRUE AND NEW.offer_id IS NOT NULL)
    EXECUTE FUNCTION trigger_log_order_offer_usage();

-- Add comments
COMMENT ON FUNCTION trigger_order_status_audit() IS 'Automatically creates audit log when order status changes';
COMMENT ON FUNCTION trigger_notify_new_order() IS 'Sends notification to admins when new order is created';
COMMENT ON FUNCTION trigger_update_order_totals() IS 'Recalculates order item counts when order_items change';
COMMENT ON FUNCTION trigger_log_order_offer_usage() IS 'Links offer usage logs to orders for tracking';
