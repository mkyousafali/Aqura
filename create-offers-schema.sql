-- ============================================
-- Offer System Database Schema
-- ============================================
-- Created: 2025-11-11
-- Purpose: Complete offer management system for Aqura customer app
-- Tables: 5 (offers, offer_products, offer_bundles, customer_offers, offer_usage_logs)
-- Features:
--   - 6 Offer Types (product, bundle, customer, cart, bogo, min_purchase)
--   - Branch-Specific & Global Offers (branch_id nullable)
--   - Service Type Targeting (delivery/pickup/both)
--   - Bilingual Support (Arabic/English)
--   - Priority & Stacking Rules
--   - Usage Tracking & Analytics
-- ============================================
--
-- IMPORTANT: Entity Type Clarification
-- ============================================
-- This system references THREE DIFFERENT entity types:
--
-- 1. USERS (users table - UUID id):
--    - Admin/Manager staff who use the DESKTOP admin interface
--    - Create and manage offers from desktop windows
--    - Examples: Admin creating offers, Manager assigning customer offers
--    - Referenced in: offers.created_by, customer_offers.assigned_by
--
-- 2. EMPLOYEES (hr_employees table - UUID id):
--    - Company staff/workers tracked in HR system
--    - NOT directly related to offer system
--    - Different from "users" - employees may not have admin access
--
-- 3. CUSTOMERS (customers table - UUID id):
--    - End users who use the CUSTOMER MOBILE APP
--    - Browse products, receive offers, place orders
--    - Examples: Mobile app users shopping and using offers
--    - Referenced in: customer_offers.customer_id, offer_usage_logs.customer_id
--
-- Summary: users = admin staff, employees = HR staff, customers = app shoppers
-- ============================================

-- ============================================
-- Table 1: offers
-- Main offers table with all offer configurations
-- ============================================
CREATE TABLE IF NOT EXISTS offers (
    id SERIAL PRIMARY KEY,
    
    -- Offer Type (6 types)
    type VARCHAR(20) NOT NULL CHECK (type IN ('product', 'bundle', 'customer', 'cart', 'bogo', 'min_purchase')),
    
    -- Bilingual Names & Descriptions
    name_ar VARCHAR(255) NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    description_ar TEXT,
    description_en TEXT,
    
    -- Discount Configuration
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10, 2) NOT NULL CHECK (discount_value > 0),
    
    -- BOGO Configuration (for BOGO type)
    bogo_buy_quantity INTEGER DEFAULT NULL,
    bogo_get_quantity INTEGER DEFAULT NULL,
    
    -- Validity Period
    start_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Status & Priority
    is_active BOOLEAN DEFAULT true,
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    
    -- Conditions
    min_quantity INTEGER DEFAULT NULL,
    min_amount DECIMAL(10, 2) DEFAULT NULL,
    max_uses_per_customer INTEGER DEFAULT NULL,
    max_total_uses INTEGER DEFAULT NULL,
    current_total_uses INTEGER DEFAULT 0,
    
    -- Branch Relation (nullable for all-branch offers)
    branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
    
    -- Service Type Targeting
    service_type VARCHAR(20) DEFAULT 'both' CHECK (service_type IN ('delivery', 'pickup', 'both')),
    
    -- Visibility Settings
    show_on_product_page BOOLEAN DEFAULT true,
    show_in_carousel BOOLEAN DEFAULT false,
    send_push_notification BOOLEAN DEFAULT false,
    
    -- Allow Stacking
    allow_stacking BOOLEAN DEFAULT false,
    
    -- Audit Fields
    created_by UUID REFERENCES users(id) ON DELETE SET NULL, -- Admin/Manager who created this offer (NOT employees, NOT customers)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Validation: end_date must be after start_date
    CONSTRAINT valid_date_range CHECK (end_date > start_date),
    
    -- Validation: BOGO requires buy/get quantities
    CONSTRAINT bogo_quantities_required CHECK (
        (type = 'bogo' AND bogo_buy_quantity IS NOT NULL AND bogo_get_quantity IS NOT NULL) OR
        (type != 'bogo')
    )
);

-- Indexes for offers table
CREATE INDEX idx_offers_type ON offers(type);
CREATE INDEX idx_offers_is_active ON offers(is_active);
CREATE INDEX idx_offers_branch_id ON offers(branch_id);
CREATE INDEX idx_offers_service_type ON offers(service_type);
CREATE INDEX idx_offers_date_range ON offers(start_date, end_date);
CREATE INDEX idx_offers_priority ON offers(priority DESC);

-- Updated_at trigger for offers
CREATE OR REPLACE FUNCTION update_offers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_offers_updated_at
    BEFORE UPDATE ON offers
    FOR EACH ROW
    EXECUTE FUNCTION update_offers_updated_at();

-- ============================================
-- Table 2: offer_products
-- Junction table linking offers to specific products/units
-- ============================================
CREATE TABLE IF NOT EXISTS offer_products (
    id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE, -- Product from inventory (UUID)
    unit_id UUID REFERENCES product_units(id) ON DELETE CASCADE, -- Product unit (UUID)
    
    -- For bundle offers: quantity required
    required_quantity INTEGER DEFAULT 1,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Unique constraint: one offer-product-unit combination
    CONSTRAINT unique_offer_product_unit UNIQUE(offer_id, product_id, unit_id)
);

-- Indexes for offer_products
CREATE INDEX idx_offer_products_offer_id ON offer_products(offer_id);
CREATE INDEX idx_offer_products_product_id ON offer_products(product_id);
CREATE INDEX idx_offer_products_unit_id ON offer_products(unit_id);

-- ============================================
-- Table 3: offer_bundles
-- Bundle offer configurations with multiple products
-- ============================================
CREATE TABLE IF NOT EXISTS offer_bundles (
    id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
    
    -- Bundle Info
    bundle_name_ar VARCHAR(255) NOT NULL,
    bundle_name_en VARCHAR(255) NOT NULL,
    
    -- Required Products (JSON array of {product_id, unit_id, quantity})
    -- Example: [{"product_id": 1, "unit_id": 2, "quantity": 2}, {"product_id": 3, "unit_id": 4, "quantity": 1}]
    required_products JSONB NOT NULL,
    
    -- Bundle Discount
    discount_amount DECIMAL(10, 2) NOT NULL CHECK (discount_amount > 0),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for offer_bundles
CREATE INDEX idx_offer_bundles_offer_id ON offer_bundles(offer_id);

-- Validation trigger: Ensure offer type is 'bundle'
CREATE OR REPLACE FUNCTION validate_bundle_offer_type()
RETURNS TRIGGER AS $$
DECLARE
    v_offer_type VARCHAR;
BEGIN
    -- Get the offer type
    SELECT type INTO v_offer_type FROM offers WHERE id = NEW.offer_id;
    
    IF v_offer_type IS NULL THEN
        RAISE EXCEPTION 'Offer with id % does not exist', NEW.offer_id;
    END IF;
    
    IF v_offer_type != 'bundle' THEN
        RAISE EXCEPTION 'Offer with id % must be of type "bundle" but is "%"', NEW.offer_id, v_offer_type;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_bundle_offer_type
    BEFORE INSERT OR UPDATE ON offer_bundles
    FOR EACH ROW
    EXECUTE FUNCTION validate_bundle_offer_type();

-- Updated_at trigger for offer_bundles
CREATE TRIGGER trigger_update_offer_bundles_updated_at
    BEFORE UPDATE ON offer_bundles
    FOR EACH ROW
    EXECUTE FUNCTION update_offers_updated_at();

-- ============================================
-- Table 4: customer_offers
-- Customer-specific offer assignments
-- ============================================
CREATE TABLE IF NOT EXISTS customer_offers (
    id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Customer = mobile app user (UUID, NOT employees, NOT admin users)
    
    -- Usage Tracking
    is_used BOOLEAN DEFAULT false,
    used_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    usage_count INTEGER DEFAULT 0,
    
    -- Assignment Info
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL, -- Admin/Manager who assigned this offer (NOT employees, NOT customers)
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Expiry Override (optional, overrides offer's end_date for this customer)
    custom_expiry_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    
    -- Unique constraint: one offer per customer
    CONSTRAINT unique_customer_offer UNIQUE(offer_id, customer_id)
);

-- Indexes for customer_offers
CREATE INDEX idx_customer_offers_offer_id ON customer_offers(offer_id);
CREATE INDEX idx_customer_offers_customer_id ON customer_offers(customer_id);
CREATE INDEX idx_customer_offers_is_used ON customer_offers(is_used);

-- ============================================
-- Table 5: offer_usage_logs
-- Comprehensive logging of all offer applications
-- ============================================
CREATE TABLE IF NOT EXISTS offer_usage_logs (
    id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL, -- Customer = mobile app user who used the offer (UUID)
    order_id INTEGER DEFAULT NULL, -- Reference to orders table (to be created)
    
    -- Discount Applied
    discount_applied DECIMAL(10, 2) NOT NULL,
    original_amount DECIMAL(10, 2) NOT NULL,
    final_amount DECIMAL(10, 2) NOT NULL,
    
    -- Context
    cart_items JSONB DEFAULT NULL, -- Snapshot of cart at time of offer application
    
    -- Timestamps
    used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Session Info
    session_id VARCHAR(255) DEFAULT NULL,
    device_type VARCHAR(50) DEFAULT NULL
);

-- Indexes for offer_usage_logs
CREATE INDEX idx_offer_usage_logs_offer_id ON offer_usage_logs(offer_id);
CREATE INDEX idx_offer_usage_logs_customer_id ON offer_usage_logs(customer_id);
CREATE INDEX idx_offer_usage_logs_order_id ON offer_usage_logs(order_id);
CREATE INDEX idx_offer_usage_logs_used_at ON offer_usage_logs(used_at DESC);

-- ============================================
-- Helper Functions
-- ============================================

-- Function: Get active offers for a customer
CREATE OR REPLACE FUNCTION get_active_offers_for_customer(
    p_customer_id UUID,
    p_branch_id INTEGER DEFAULT NULL,
    p_service_type VARCHAR DEFAULT 'both'
)
RETURNS TABLE (
    offer_id INTEGER,
    offer_type VARCHAR,
    name_ar VARCHAR,
    name_en VARCHAR,
    discount_type VARCHAR,
    discount_value DECIMAL,
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    service_type VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.type,
        o.name_ar,
        o.name_en,
        o.discount_type,
        o.discount_value,
        o.start_date,
        o.end_date,
        o.service_type
    FROM offers o
    WHERE o.is_active = true
        AND NOW() BETWEEN o.start_date AND o.end_date
        AND (o.branch_id IS NULL OR o.branch_id = p_branch_id)
        AND (o.service_type = 'both' OR o.service_type = p_service_type)
        AND (
            -- General offers (not customer-specific)
            o.type != 'customer'
            OR
            -- Customer-specific offers assigned to this customer
            EXISTS (
                SELECT 1 FROM customer_offers co
                WHERE co.offer_id = o.id
                    AND co.customer_id = p_customer_id
                    AND co.is_used = false
            )
        )
        AND (
            -- Check max total uses not exceeded
            o.max_total_uses IS NULL OR o.current_total_uses < o.max_total_uses
        )
    ORDER BY o.priority DESC, o.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function: Check if customer is eligible for offer
CREATE OR REPLACE FUNCTION check_offer_eligibility(
    p_offer_id INTEGER,
    p_customer_id UUID,
    p_cart_total DECIMAL DEFAULT 0,
    p_cart_quantity INTEGER DEFAULT 0
)
RETURNS BOOLEAN AS $$
DECLARE
    v_offer RECORD;
    v_customer_usage_count INTEGER;
BEGIN
    -- Get offer details
    SELECT * INTO v_offer FROM offers WHERE id = p_offer_id;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    -- Check if offer is active
    IF v_offer.is_active = false THEN
        RETURN false;
    END IF;
    
    -- Check date range
    IF NOW() NOT BETWEEN v_offer.start_date AND v_offer.end_date THEN
        RETURN false;
    END IF;
    
    -- Check minimum amount
    IF v_offer.min_amount IS NOT NULL AND p_cart_total < v_offer.min_amount THEN
        RETURN false;
    END IF;
    
    -- Check minimum quantity
    IF v_offer.min_quantity IS NOT NULL AND p_cart_quantity < v_offer.min_quantity THEN
        RETURN false;
    END IF;
    
    -- Check max uses per customer
    IF v_offer.max_uses_per_customer IS NOT NULL THEN
        SELECT COUNT(*) INTO v_customer_usage_count
        FROM offer_usage_logs
        WHERE offer_id = p_offer_id AND customer_id = p_customer_id;
        
        IF v_customer_usage_count >= v_offer.max_uses_per_customer THEN
            RETURN false;
        END IF;
    END IF;
    
    -- Check max total uses
    IF v_offer.max_total_uses IS NOT NULL AND v_offer.current_total_uses >= v_offer.max_total_uses THEN
        RETURN false;
    END IF;
    
    -- If customer-specific, check assignment
    IF v_offer.type = 'customer' THEN
        IF NOT EXISTS (
            SELECT 1 FROM customer_offers
            WHERE offer_id = p_offer_id AND customer_id = p_customer_id
        ) THEN
            RETURN false;
        END IF;
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function: Log offer usage and increment counters
CREATE OR REPLACE FUNCTION log_offer_usage(
    p_offer_id INTEGER,
    p_customer_id UUID,
    p_order_id INTEGER,
    p_discount_applied DECIMAL,
    p_original_amount DECIMAL,
    p_final_amount DECIMAL,
    p_cart_items JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_log_id INTEGER;
BEGIN
    -- Insert usage log
    INSERT INTO offer_usage_logs (
        offer_id, customer_id, order_id,
        discount_applied, original_amount, final_amount,
        cart_items
    ) VALUES (
        p_offer_id, p_customer_id, p_order_id,
        p_discount_applied, p_original_amount, p_final_amount,
        p_cart_items
    ) RETURNING id INTO v_log_id;
    
    -- Increment offer usage counter
    UPDATE offers
    SET current_total_uses = current_total_uses + 1
    WHERE id = p_offer_id;
    
    -- Update customer_offers if customer-specific
    UPDATE customer_offers
    SET is_used = true,
        used_at = NOW(),
        usage_count = usage_count + 1
    WHERE offer_id = p_offer_id AND customer_id = p_customer_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Row Level Security (RLS) Policies
-- ============================================

-- Enable RLS on all offer tables
ALTER TABLE offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_usage_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Admin and Master Admin users can do everything
-- Note: Aqura uses position-based permissions, checked at application level
CREATE POLICY admin_all_offers ON offers FOR ALL USING (
    auth.uid() IN (SELECT id FROM users WHERE status = 'active' AND role_type IN ('Admin', 'Master Admin'))
);

CREATE POLICY admin_all_offer_products ON offer_products FOR ALL USING (
    auth.uid() IN (SELECT id FROM users WHERE status = 'active' AND role_type IN ('Admin', 'Master Admin'))
);

CREATE POLICY admin_all_offer_bundles ON offer_bundles FOR ALL USING (
    auth.uid() IN (SELECT id FROM users WHERE status = 'active' AND role_type IN ('Admin', 'Master Admin'))
);

CREATE POLICY admin_all_customer_offers ON customer_offers FOR ALL USING (
    auth.uid() IN (SELECT id FROM users WHERE status = 'active' AND role_type IN ('Admin', 'Master Admin'))
);

CREATE POLICY admin_all_offer_usage_logs ON offer_usage_logs FOR ALL USING (
    auth.uid() IN (SELECT id FROM users WHERE status = 'active' AND role_type IN ('Admin', 'Master Admin'))
);

-- Policy: Customers can view active offers
CREATE POLICY customer_view_active_offers ON offers FOR SELECT USING (
    is_active = true
    AND NOW() BETWEEN start_date AND end_date
);

-- Policy: Customers can view their assigned offers
CREATE POLICY customer_view_own_offers ON customer_offers FOR SELECT USING (
    customer_id = auth.uid()
);

-- ============================================
-- End of Schema
-- ============================================

COMMENT ON TABLE offers IS 'Main offers table with all offer configurations and rules';
COMMENT ON TABLE offer_products IS 'Links offers to specific products/units';
COMMENT ON TABLE offer_bundles IS 'Bundle offer configurations with multiple products';
COMMENT ON TABLE customer_offers IS 'Customer-specific offer assignments and tracking';
COMMENT ON TABLE offer_usage_logs IS 'Comprehensive logging of all offer applications';
