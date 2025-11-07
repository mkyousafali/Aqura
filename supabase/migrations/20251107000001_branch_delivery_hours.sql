-- ================================================================
-- MIGRATION: Branch-Specific Delivery Hours
-- Created: 2025-11-07
-- Description: Add delivery operating hours to branches table
-- ================================================================

-- Add delivery hours columns to branches table
DO $$ 
BEGIN
    -- Minimum order amount per branch
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'minimum_order_amount') THEN
        ALTER TABLE public.branches ADD COLUMN minimum_order_amount numeric(10,2) DEFAULT 15.00;
    END IF;
    
    -- 24/7 service toggle
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'is_24_hours') THEN
        ALTER TABLE public.branches ADD COLUMN is_24_hours boolean DEFAULT true;
    END IF;
    
    -- Operating start time
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'operating_start_time') THEN
        ALTER TABLE public.branches ADD COLUMN operating_start_time time;
    END IF;
    
    -- Operating end time
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'operating_end_time') THEN
        ALTER TABLE public.branches ADD COLUMN operating_end_time time;
    END IF;
    
    -- Display messages
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'delivery_message_ar') THEN
        ALTER TABLE public.branches ADD COLUMN delivery_message_ar text;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'delivery_message_en') THEN
        ALTER TABLE public.branches ADD COLUMN delivery_message_en text;
    END IF;
END $$;

-- Add comments
COMMENT ON COLUMN public.branches.minimum_order_amount IS 'Minimum order amount for this branch (SAR)';
COMMENT ON COLUMN public.branches.is_24_hours IS 'Whether delivery service is available 24/7 for this branch';
COMMENT ON COLUMN public.branches.operating_start_time IS 'Delivery service start time (if not 24/7)';
COMMENT ON COLUMN public.branches.operating_end_time IS 'Delivery service end time (if not 24/7)';
COMMENT ON COLUMN public.branches.delivery_message_ar IS 'Custom delivery message in Arabic for this branch';
COMMENT ON COLUMN public.branches.delivery_message_en IS 'Custom delivery message in English for this branch';

-- Update existing branches with default values
UPDATE public.branches 
SET 
    minimum_order_amount = COALESCE(minimum_order_amount, 15.00),
    is_24_hours = COALESCE(is_24_hours, true),
    delivery_message_ar = COALESCE(delivery_message_ar, 'التوصيل متاح على مدار الساعة'),
    delivery_message_en = COALESCE(delivery_message_en, 'Delivery available 24/7')
WHERE minimum_order_amount IS NULL OR delivery_message_ar IS NULL;

-- ================================================================
-- Create function to get branch delivery settings
-- ================================================================

-- Drop existing function if it exists with different signature
DROP FUNCTION IF EXISTS public.get_branch_delivery_settings(uuid);
DROP FUNCTION IF EXISTS public.get_branch_delivery_settings(bigint);

CREATE OR REPLACE FUNCTION public.get_branch_delivery_settings(p_branch_id bigint)
RETURNS TABLE (
    branch_id bigint,
    branch_name_en text,
    branch_name_ar text,
    minimum_order_amount numeric,
    is_24_hours boolean,
    operating_start_time time,
    operating_end_time time,
    delivery_service_enabled boolean,
    pickup_service_enabled boolean,
    delivery_message_ar text,
    delivery_message_en text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.name_en::text,
        b.name_ar::text,
        COALESCE(b.minimum_order_amount, 15.00)::numeric,
        COALESCE(b.is_24_hours, true)::boolean,
        b.operating_start_time,
        b.operating_end_time,
        COALESCE(b.delivery_service_enabled, true)::boolean,
        COALESCE(b.pickup_service_enabled, true)::boolean,
        COALESCE(b.delivery_message_ar, 'التوصيل متاح على مدار الساعة')::text,
        COALESCE(b.delivery_message_en, 'Delivery available 24/7')::text
    FROM public.branches b
    WHERE b.id = p_branch_id
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_branch_delivery_settings(bigint) IS 
'Get delivery settings for a specific branch including operating hours and service availability';

-- ================================================================
-- Create function to get all branches delivery settings
-- ================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_all_branches_delivery_settings();

CREATE OR REPLACE FUNCTION public.get_all_branches_delivery_settings()
RETURNS TABLE (
    branch_id bigint,
    branch_name_en text,
    branch_name_ar text,
    minimum_order_amount numeric,
    is_24_hours boolean,
    operating_start_time time,
    operating_end_time time,
    delivery_service_enabled boolean,
    pickup_service_enabled boolean,
    delivery_message_ar text,
    delivery_message_en text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.name_en::text,
        b.name_ar::text,
        COALESCE(b.minimum_order_amount, 15.00)::numeric,
        COALESCE(b.is_24_hours, true)::boolean,
        b.operating_start_time,
        b.operating_end_time,
        COALESCE(b.delivery_service_enabled, true)::boolean,
        COALESCE(b.pickup_service_enabled, true)::boolean,
        COALESCE(b.delivery_message_ar, 'التوصيل متاح على مدار الساعة')::text,
        COALESCE(b.delivery_message_en, 'Delivery available 24/7')::text
    FROM public.branches b
    ORDER BY b.name_en;
END;
$$;

COMMENT ON FUNCTION public.get_all_branches_delivery_settings() IS 
'Get delivery settings for all branches';

-- ================================================================
-- MIGRATION COMPLETE
-- ================================================================
