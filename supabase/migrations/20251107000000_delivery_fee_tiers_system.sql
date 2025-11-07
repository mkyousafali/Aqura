-- ================================================================
-- MIGRATION: Multi-Tier Delivery Fee System
-- Created: 2025-11-07
-- Description: Creates delivery fee tiers system with branch-level service controls
-- ================================================================

-- ================================================================
-- TABLE: delivery_fee_tiers
-- Purpose: Store multiple delivery fee tiers based on order amounts
-- ================================================================

CREATE TABLE IF NOT EXISTS public.delivery_fee_tiers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    min_order_amount numeric(10,2) NOT NULL,
    max_order_amount numeric(10,2),  -- NULL means unlimited/maximum tier
    delivery_fee numeric(10,2) NOT NULL,
    tier_order integer NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    description_en text,
    description_ar text,
    created_by uuid REFERENCES public.users(id),
    updated_by uuid REFERENCES public.users(id),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    -- Ensure no overlapping ranges
    CONSTRAINT check_min_max_order CHECK (max_order_amount IS NULL OR max_order_amount > min_order_amount),
    CONSTRAINT check_delivery_fee_positive CHECK (delivery_fee >= 0),
    CONSTRAINT check_min_amount_positive CHECK (min_order_amount >= 0)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_delivery_tiers_order_amount 
    ON public.delivery_fee_tiers(min_order_amount, max_order_amount);
CREATE INDEX IF NOT EXISTS idx_delivery_tiers_active 
    ON public.delivery_fee_tiers(is_active);
CREATE INDEX IF NOT EXISTS idx_delivery_tiers_order 
    ON public.delivery_fee_tiers(tier_order);

COMMENT ON TABLE public.delivery_fee_tiers IS 'Multi-tier delivery fee structure based on order amounts';
COMMENT ON COLUMN public.delivery_fee_tiers.min_order_amount IS 'Minimum order amount for this tier (SAR)';
COMMENT ON COLUMN public.delivery_fee_tiers.max_order_amount IS 'Maximum order amount for this tier, NULL for unlimited';
COMMENT ON COLUMN public.delivery_fee_tiers.delivery_fee IS 'Delivery fee charged for orders in this tier (SAR)';
COMMENT ON COLUMN public.delivery_fee_tiers.tier_order IS 'Display order for admin interface';

-- ================================================================
-- TABLE: delivery_service_settings
-- Purpose: Global delivery service configuration
-- ================================================================

CREATE TABLE IF NOT EXISTS public.delivery_service_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    minimum_order_amount numeric(10,2) NOT NULL DEFAULT 15.00,
    is_24_hours boolean NOT NULL DEFAULT true,
    operating_start_time time,
    operating_end_time time,
    is_active boolean NOT NULL DEFAULT true,
    display_message_ar text DEFAULT 'التوصيل متاح على مدار الساعة (24/7)',
    display_message_en text DEFAULT 'Delivery available 24/7',
    updated_by uuid REFERENCES public.users(id),
    updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    
    -- Ensure only one settings record exists
    CONSTRAINT delivery_settings_singleton CHECK (id = '00000000-0000-0000-0000-000000000001'::uuid)
);

COMMENT ON TABLE public.delivery_service_settings IS 'Global delivery service configuration settings';
COMMENT ON COLUMN public.delivery_service_settings.minimum_order_amount IS 'Minimum order amount to place any order (SAR)';

-- ================================================================
-- ALTER TABLE: branches
-- Purpose: Add delivery and pickup service toggles per branch
-- ================================================================

-- Add columns if they don't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'delivery_service_enabled') THEN
        ALTER TABLE public.branches ADD COLUMN delivery_service_enabled boolean NOT NULL DEFAULT true;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'pickup_service_enabled') THEN
        ALTER TABLE public.branches ADD COLUMN pickup_service_enabled boolean NOT NULL DEFAULT true;
    END IF;
END $$;

COMMENT ON COLUMN public.branches.delivery_service_enabled IS 'Enable/disable delivery service for this branch';
COMMENT ON COLUMN public.branches.pickup_service_enabled IS 'Enable/disable store pickup service for this branch';

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.delivery_fee_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_service_settings ENABLE ROW LEVEL SECURITY;

-- Policies for delivery_fee_tiers
CREATE POLICY "delivery_tiers_select_all" ON public.delivery_fee_tiers
    FOR SELECT USING (true);

CREATE POLICY "delivery_tiers_admin_all" ON public.delivery_fee_tiers
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND role_type IN ('Master Admin', 'Admin')
        )
    );

-- Policies for delivery_service_settings
CREATE POLICY "delivery_settings_select_all" ON public.delivery_service_settings
    FOR SELECT USING (true);

CREATE POLICY "delivery_settings_admin_all" ON public.delivery_service_settings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND role_type IN ('Master Admin', 'Admin')
        )
    );

-- ================================================================
-- TRIGGERS
-- ================================================================

-- Trigger for updated_at on delivery_fee_tiers
CREATE OR REPLACE FUNCTION update_delivery_tiers_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_delivery_tiers_timestamp
    BEFORE UPDATE ON public.delivery_fee_tiers
    FOR EACH ROW
    EXECUTE FUNCTION update_delivery_tiers_timestamp();

-- Trigger for updated_at on delivery_service_settings
CREATE TRIGGER trigger_update_delivery_settings_timestamp
    BEFORE UPDATE ON public.delivery_service_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_delivery_tiers_timestamp();

-- ================================================================
-- INSERT DEFAULT DATA
-- ================================================================

-- Insert singleton settings record
INSERT INTO public.delivery_service_settings (id, minimum_order_amount, is_24_hours)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 15.00, true)
ON CONFLICT (id) DO NOTHING;

-- Insert default delivery fee tiers
INSERT INTO public.delivery_fee_tiers (min_order_amount, max_order_amount, delivery_fee, tier_order, description_en, description_ar) VALUES
    (0.00, 49.99, 999.99, 1, 'Minimum order not met', 'لم يتم الوصول للحد الأدنى'),
    (50.00, 99.99, 25.00, 2, 'Orders 50-99.99 SAR', 'طلبات 50-99.99 ر.س'),
    (100.00, 199.99, 20.00, 3, 'Orders 100-199.99 SAR', 'طلبات 100-199.99 ر.س'),
    (200.00, 299.99, 15.00, 4, 'Orders 200-299.99 SAR', 'طلبات 200-299.99 ر.س'),
    (300.00, 399.99, 10.00, 5, 'Orders 300-399.99 SAR', 'طلبات 300-399.99 ر.س'),
    (400.00, 499.99, 5.00, 6, 'Orders 400-499.99 SAR', 'طلبات 400-499.99 ر.س'),
    (500.00, NULL, 0.00, 7, 'Free delivery for 500+ SAR', 'توصيل مجاني للطلبات 500+ ر.س')
ON CONFLICT DO NOTHING;

-- ================================================================
-- MIGRATION COMPLETE
-- ================================================================

COMMENT ON TABLE public.delivery_fee_tiers IS 'Multi-tier delivery fee system - Migration 20251107000000';
