-- =====================================================
-- Order Audit Logs Table Migration
-- Created: 2025-11-20
-- Description: Creates order_audit_logs table for tracking all order status changes
-- =====================================================

-- Create order_audit_logs table
CREATE TABLE IF NOT EXISTS order_audit_logs (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Order Reference
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    
    -- Action Information
    action_type VARCHAR(50) NOT NULL,
    -- Values: created, status_changed, assigned_picker, assigned_delivery, cancelled, payment_updated, notes_added, etc.
    
    -- Status Change Details
    from_status VARCHAR(50),
    to_status VARCHAR(50),
    
    -- User Information
    performed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    performed_by_name VARCHAR(255),
    performed_by_role VARCHAR(50),
    
    -- Assignment Details
    assigned_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_user_name VARCHAR(255),
    assignment_type VARCHAR(50),
    -- Values: picker, delivery
    
    -- Change Details
    field_name VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    
    -- Notes
    notes TEXT,
    
    -- IP and Device
    ip_address INET,
    user_agent TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_order_audit_logs_order_id ON order_audit_logs(order_id);
CREATE INDEX idx_order_audit_logs_action_type ON order_audit_logs(action_type);
CREATE INDEX idx_order_audit_logs_performed_by ON order_audit_logs(performed_by);
CREATE INDEX idx_order_audit_logs_created_at ON order_audit_logs(created_at DESC);
CREATE INDEX idx_order_audit_logs_assigned_user ON order_audit_logs(assigned_user_id);

-- Composite indexes
CREATE INDEX idx_order_audit_logs_order_created ON order_audit_logs(order_id, created_at DESC);
CREATE INDEX idx_order_audit_logs_order_action ON order_audit_logs(order_id, action_type);

-- Add table comment
COMMENT ON TABLE order_audit_logs IS 'Audit trail for all order changes and actions';
COMMENT ON COLUMN order_audit_logs.action_type IS 'Type of action: created, status_changed, assigned_picker, assigned_delivery, cancelled, etc.';
COMMENT ON COLUMN order_audit_logs.from_status IS 'Previous order status (for status_changed actions)';
COMMENT ON COLUMN order_audit_logs.to_status IS 'New order status (for status_changed actions)';
COMMENT ON COLUMN order_audit_logs.performed_by IS 'User who performed the action';
COMMENT ON COLUMN order_audit_logs.assigned_user_id IS 'User who was assigned (for assignment actions)';
COMMENT ON COLUMN order_audit_logs.assignment_type IS 'Type of assignment: picker or delivery';

-- Grant permissions
GRANT SELECT ON order_audit_logs TO authenticated;
GRANT SELECT, INSERT ON order_audit_logs TO service_role;
