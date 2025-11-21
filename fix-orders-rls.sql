-- Fix Orders RLS Policies for Admin Access
-- This ensures Master Admin and Admin users can see all orders

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "admins_view_all_orders" ON orders;

-- Recreate the policy for admins
CREATE POLICY "admins_view_all_orders" ON orders
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.role_type IN ('Admin', 'Master Admin')
        )
    );

-- Grant full access to service role (for backend operations)
GRANT ALL ON orders TO service_role;
GRANT ALL ON order_items TO service_role;
GRANT ALL ON order_audit_logs TO service_role;

-- Grant read access to authenticated users (with RLS filtering)
GRANT SELECT ON orders TO authenticated;
GRANT SELECT ON order_items TO authenticated;
GRANT SELECT ON order_audit_logs TO authenticated;
