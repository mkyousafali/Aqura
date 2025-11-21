-- =====================================================
-- Orders Table Migration
-- Created: 2025-11-20
-- Description: Creates orders table for customer order management
-- =====================================================

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Order Identification
    order_number VARCHAR(50) UNIQUE NOT NULL,
    
    -- Customer Information
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    customer_name VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    customer_whatsapp VARCHAR(20),
    
    -- Branch Information
    branch_id BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    
    -- Location (selected from customer's saved locations)
    selected_location JSONB NOT NULL,
    -- Structure: { name: string, url: string, lat: number, lng: number }
    
    -- Order Status
    order_status VARCHAR(50) NOT NULL DEFAULT 'new',
    -- Values: new, accepted, in_picking, ready, out_for_delivery, delivered, cancelled
    
    -- Fulfillment Method
    fulfillment_method VARCHAR(20) NOT NULL DEFAULT 'delivery',
    -- Values: delivery, pickup
    
    -- Order Amounts
    subtotal_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    delivery_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL,
    
    -- Payment Information
    payment_method VARCHAR(20) NOT NULL,
    -- Values: cash, card, online
    payment_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    -- Values: pending, paid, refunded
    payment_reference VARCHAR(100),
    
    -- Order Items Count
    total_items INTEGER NOT NULL DEFAULT 0,
    total_quantity INTEGER NOT NULL DEFAULT 0,
    
    -- Assignments
    picker_id UUID REFERENCES users(id) ON DELETE SET NULL,
    picker_assigned_at TIMESTAMPTZ,
    delivery_person_id UUID REFERENCES users(id) ON DELETE SET NULL,
    delivery_assigned_at TIMESTAMPTZ,
    
    -- Status Timestamps
    accepted_at TIMESTAMPTZ,
    ready_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    
    -- Cancellation
    cancelled_at TIMESTAMPTZ,
    cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
    cancellation_reason TEXT,
    
    -- Customer Notes
    customer_notes TEXT,
    
    -- Admin Notes
    admin_notes TEXT,
    
    -- Estimated Times
    estimated_pickup_time TIMESTAMPTZ,
    estimated_delivery_time TIMESTAMPTZ,
    
    -- Actual Times
    actual_pickup_time TIMESTAMPTZ,
    actual_delivery_time TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for better query performance
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_branch_id ON orders(branch_id);
CREATE INDEX idx_orders_order_status ON orders(order_status);
CREATE INDEX idx_orders_order_number ON orders(order_number);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_picker_id ON orders(picker_id);
CREATE INDEX idx_orders_delivery_person_id ON orders(delivery_person_id);
CREATE INDEX idx_orders_fulfillment_method ON orders(fulfillment_method);

-- Composite indexes for common queries
CREATE INDEX idx_orders_branch_status ON orders(branch_id, order_status);
CREATE INDEX idx_orders_customer_status ON orders(customer_id, order_status);
CREATE INDEX idx_orders_status_created ON orders(order_status, created_at DESC);

-- Create trigger to update updated_at timestamp
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Add table comment
COMMENT ON TABLE orders IS 'Customer orders from mobile app';
COMMENT ON COLUMN orders.order_number IS 'Unique order number displayed to customer (e.g., ORD-20251120-0001)';
COMMENT ON COLUMN orders.selected_location IS 'Customer delivery location snapshot from their saved locations';
COMMENT ON COLUMN orders.order_status IS 'Order workflow status: new, accepted, in_picking, ready, out_for_delivery, delivered, cancelled';
COMMENT ON COLUMN orders.fulfillment_method IS 'How customer will receive order: delivery or pickup';
COMMENT ON COLUMN orders.payment_method IS 'Payment method: cash, card, online';
COMMENT ON COLUMN orders.payment_status IS 'Payment tracking: pending, paid, refunded';

-- Grant permissions
GRANT SELECT, INSERT ON orders TO authenticated;
GRANT SELECT, INSERT, UPDATE ON orders TO service_role;
