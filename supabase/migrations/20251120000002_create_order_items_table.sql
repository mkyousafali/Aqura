-- =====================================================
-- Order Items Table Migration
-- Created: 2025-11-20
-- Description: Creates order_items table for storing individual order line items
-- =====================================================

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Order Reference
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    
    -- Product Information (snapshot at time of order)
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name_ar VARCHAR(255) NOT NULL,
    product_name_en VARCHAR(255) NOT NULL,
    product_sku VARCHAR(100),
    
    -- Unit Information (snapshot at time of order)
    unit_id UUID REFERENCES product_units(id) ON DELETE SET NULL,
    unit_name_ar VARCHAR(100),
    unit_name_en VARCHAR(100),
    unit_size VARCHAR(50),
    
    -- Quantity
    quantity INTEGER NOT NULL,
    
    -- Pricing (snapshot at time of order)
    unit_price DECIMAL(10, 2) NOT NULL,
    original_price DECIMAL(10, 2) NOT NULL,
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    final_price DECIMAL(10, 2) NOT NULL,
    line_total DECIMAL(10, 2) NOT NULL,
    
    -- Offer Information
    has_offer BOOLEAN NOT NULL DEFAULT FALSE,
    offer_id INTEGER REFERENCES offers(id) ON DELETE SET NULL,
    offer_name_ar VARCHAR(255),
    offer_name_en VARCHAR(255),
    offer_type VARCHAR(50),
    -- Values: percentage, special_price, bogo, bundle, cart_discount
    offer_discount_percentage DECIMAL(5, 2),
    offer_special_price DECIMAL(10, 2),
    
    -- Item Type
    item_type VARCHAR(20) NOT NULL DEFAULT 'regular',
    -- Values: regular, bundle_item, bogo_free, bogo_discounted
    
    -- Bundle Information (if part of a bundle)
    bundle_id UUID,
    bundle_name_ar VARCHAR(255),
    bundle_name_en VARCHAR(255),
    is_bundle_item BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- BOGO Information
    is_bogo_free BOOLEAN NOT NULL DEFAULT FALSE,
    bogo_group_id UUID,
    
    -- Tax
    tax_rate DECIMAL(5, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    
    -- Notes
    item_notes TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_order_items_offer_id ON order_items(offer_id);
CREATE INDEX idx_order_items_bundle_id ON order_items(bundle_id);
CREATE INDEX idx_order_items_item_type ON order_items(item_type);

-- Composite indexes
CREATE INDEX idx_order_items_order_product ON order_items(order_id, product_id);
CREATE INDEX idx_order_items_order_bundle ON order_items(order_id, bundle_id);

-- Add table comment
COMMENT ON TABLE order_items IS 'Individual line items within customer orders';
COMMENT ON COLUMN order_items.product_name_ar IS 'Product name snapshot in Arabic at time of order';
COMMENT ON COLUMN order_items.product_name_en IS 'Product name snapshot in English at time of order';
COMMENT ON COLUMN order_items.unit_price IS 'Price per unit at time of order';
COMMENT ON COLUMN order_items.final_price IS 'Price after applying discounts/offers';
COMMENT ON COLUMN order_items.line_total IS 'Total for this line (final_price * quantity)';
COMMENT ON COLUMN order_items.item_type IS 'Type of item: regular, bundle_item, bogo_free, bogo_discounted';
COMMENT ON COLUMN order_items.bundle_id IS 'Groups items that belong to the same bundle purchase';
COMMENT ON COLUMN order_items.bogo_group_id IS 'Groups items involved in the same BOGO offer';

-- Grant permissions
GRANT SELECT, INSERT ON order_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_items TO service_role;
