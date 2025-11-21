-- =====================================================
-- Order Management RLS Policies Migration
-- Created: 2025-11-20
-- Updated: 2025-11-20 - Added comprehensive role support
-- Description: Row Level Security policies for orders, order_items, and order_audit_logs
-- =====================================================

-- Enable RLS on all order tables
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_audit_logs ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- HELPER FUNCTION: Check if user has admin/management access
-- =====================================================
CREATE OR REPLACE FUNCTION has_order_management_access(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users u
        LEFT JOIN user_roles ur ON u.position_id::text = ur.role_code
        WHERE u.id = user_id
        AND (
            u.role_type IN ('Admin', 'Master Admin')
            OR ur.role_code IN (
                'CEO',
                'OPERATIONS_MANAGER',
                'BRANCH_MANAGER',
                'CUSTOMER_SERVICE_SUPERVISOR',
                'NIGHT_SUPERVISORS',
                'IT_SYSTEMS_MANAGER'
            )
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- HELPER FUNCTION: Check if user is delivery staff
-- =====================================================
CREATE OR REPLACE FUNCTION is_delivery_staff(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users u
        LEFT JOIN user_roles ur ON u.position_id::text = ur.role_code
        WHERE u.id = user_id
        AND ur.role_code IN ('DELIVERY_STAFF', 'DRIVER')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- ORDERS TABLE POLICIES
-- =====================================================

-- Policy: Customers can view their own orders
CREATE POLICY "customers_view_own_orders" ON orders
    FOR SELECT
    USING (
        auth.uid() = customer_id
        OR
        has_order_management_access(auth.uid())
        OR
        is_delivery_staff(auth.uid())
    );

-- Policy: Customers can create orders
CREATE POLICY "customers_create_orders" ON orders
    FOR INSERT
    WITH CHECK (
        auth.uid() = customer_id
    );

-- Policy: Management can view all orders
CREATE POLICY "management_view_all_orders" ON orders
    FOR SELECT
    USING (
        has_order_management_access(auth.uid())
        OR
        picker_id = auth.uid()
        OR
        delivery_person_id = auth.uid()
    );

-- Policy: Management can update orders
CREATE POLICY "management_update_orders" ON orders
    FOR UPDATE
    USING (
        has_order_management_access(auth.uid())
    );

-- Policy: Pickers can view assigned orders
CREATE POLICY "pickers_view_assigned_orders" ON orders
    FOR SELECT
    USING (
        picker_id = auth.uid()
        OR
        has_order_management_access(auth.uid())
    );

-- Policy: Delivery personnel can view assigned orders
CREATE POLICY "delivery_view_assigned_orders" ON orders
    FOR SELECT
    USING (
        delivery_person_id = auth.uid()
        OR
        is_delivery_staff(auth.uid())
        OR
        has_order_management_access(auth.uid())
    );

-- Policy: Pickers can update their assigned orders (limited fields)
CREATE POLICY "pickers_update_assigned_orders" ON orders
    FOR UPDATE
    USING (
        picker_id = auth.uid()
    )
    WITH CHECK (
        picker_id = auth.uid()
        AND order_status IN ('in_picking', 'ready')
    );

-- Policy: Delivery personnel can update their assigned orders (limited fields)
CREATE POLICY "delivery_update_assigned_orders" ON orders
    FOR UPDATE
    USING (
        delivery_person_id = auth.uid()
        OR
        is_delivery_staff(auth.uid())
    )
    WITH CHECK (
        (delivery_person_id = auth.uid() OR is_delivery_staff(auth.uid()))
        AND order_status IN ('out_for_delivery', 'delivered')
    );

-- =====================================================
-- ORDER_ITEMS TABLE POLICIES
-- =====================================================

-- Policy: Users can view order items for orders they can see
CREATE POLICY "users_view_order_items" ON order_items
    FOR SELECT
    USING (
        order_id IN (
            SELECT id FROM orders
            WHERE customer_id = auth.uid()
            OR picker_id = auth.uid()
            OR delivery_person_id = auth.uid()
            OR has_order_management_access(auth.uid())
            OR is_delivery_staff(auth.uid())
        )
    );

-- Policy: System can insert order items (via functions)
CREATE POLICY "system_insert_order_items" ON order_items
    FOR INSERT
    WITH CHECK (
        order_id IN (
            SELECT id FROM orders
            WHERE customer_id = auth.uid()
            OR has_order_management_access(auth.uid())
        )
    );

-- Policy: Management can update order items
CREATE POLICY "management_update_order_items" ON order_items
    FOR UPDATE
    USING (
        has_order_management_access(auth.uid())
    );

-- Policy: Management can delete order items
CREATE POLICY "management_delete_order_items" ON order_items
    FOR DELETE
    USING (
        has_order_management_access(auth.uid())
    );

-- =====================================================
-- ORDER_AUDIT_LOGS TABLE POLICIES
-- =====================================================

-- Policy: Users can view audit logs for their orders
CREATE POLICY "users_view_order_audit_logs" ON order_audit_logs
    FOR SELECT
    USING (
        order_id IN (
            SELECT id FROM orders
            WHERE customer_id = auth.uid()
            OR picker_id = auth.uid()
            OR delivery_person_id = auth.uid()
            OR has_order_management_access(auth.uid())
            OR is_delivery_staff(auth.uid())
        )
    );

-- Policy: System can insert audit logs (via triggers and functions)
CREATE POLICY "system_insert_audit_logs" ON order_audit_logs
    FOR INSERT
    WITH CHECK (true); -- Audit logs are created automatically

-- Policy: Management can view all audit logs
CREATE POLICY "management_view_all_audit_logs" ON order_audit_logs
    FOR SELECT
    USING (
        has_order_management_access(auth.uid())
    );

-- =====================================================
-- SERVICE ROLE BYPASS (for backend operations)
-- =====================================================

-- Service role can do everything (already granted in table creation)
-- No additional policies needed as service_role bypasses RLS

-- Add comments
COMMENT ON FUNCTION has_order_management_access IS 'Check if user has management-level access to orders (Admin, Master Admin, CEO, Operations Manager, Branch Manager, Customer Service Supervisor, Night Supervisors, IT Systems Manager)';
COMMENT ON FUNCTION is_delivery_staff IS 'Check if user is delivery staff (Delivery Staff, Driver)';
COMMENT ON POLICY "customers_view_own_orders" ON orders IS 'Customers can view their own orders, management and delivery staff can view all';
COMMENT ON POLICY "management_view_all_orders" ON orders IS 'Management, pickers, and delivery staff can view orders';
COMMENT ON POLICY "pickers_view_assigned_orders" ON orders IS 'Pickers can view orders assigned to them';
COMMENT ON POLICY "delivery_view_assigned_orders" ON orders IS 'Delivery personnel can view their assigned orders';
COMMENT ON POLICY "users_view_order_items" ON order_items IS 'Users can view items for orders they have access to';
COMMENT ON POLICY "users_view_order_audit_logs" ON order_audit_logs IS 'Users can view audit logs for their orders';
