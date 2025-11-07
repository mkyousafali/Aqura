-- ================================================================
-- MIGRATION: Separate Service Timings for Pickup and Delivery
-- Created: 2025-11-07
-- Description: Add separate operating hours for pickup and delivery services
-- ================================================================

-- Add separate timing columns for delivery
DO $$ 
BEGIN
    -- Delivery 24/7 toggle
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'delivery_is_24_hours') THEN
        ALTER TABLE public.branches ADD COLUMN delivery_is_24_hours boolean DEFAULT true;
    END IF;
    
    -- Delivery operating hours
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'delivery_start_time') THEN
        ALTER TABLE public.branches ADD COLUMN delivery_start_time time;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'delivery_end_time') THEN
        ALTER TABLE public.branches ADD COLUMN delivery_end_time time;
    END IF;
    
    -- Pickup 24/7 toggle
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'pickup_is_24_hours') THEN
        ALTER TABLE public.branches ADD COLUMN pickup_is_24_hours boolean DEFAULT true;
    END IF;
    
    -- Pickup operating hours
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'pickup_start_time') THEN
        ALTER TABLE public.branches ADD COLUMN pickup_start_time time;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'branches' AND column_name = 'pickup_end_time') THEN
        ALTER TABLE public.branches ADD COLUMN pickup_end_time time;
    END IF;
END $$;

-- Add comments
COMMENT ON COLUMN public.branches.delivery_is_24_hours IS 'Whether delivery service is available 24/7';
COMMENT ON COLUMN public.branches.delivery_start_time IS 'Delivery service start time';
COMMENT ON COLUMN public.branches.delivery_end_time IS 'Delivery service end time';
COMMENT ON COLUMN public.branches.pickup_is_24_hours IS 'Whether pickup service is available 24/7';
COMMENT ON COLUMN public.branches.pickup_start_time IS 'Pickup service start time';
COMMENT ON COLUMN public.branches.pickup_end_time IS 'Pickup service end time';

-- Copy existing timing data to both services
UPDATE public.branches 
SET 
    delivery_is_24_hours = COALESCE(is_24_hours, true),
    delivery_start_time = operating_start_time,
    delivery_end_time = operating_end_time,
    pickup_is_24_hours = COALESCE(is_24_hours, true),
    pickup_start_time = operating_start_time,
    pickup_end_time = operating_end_time
WHERE delivery_is_24_hours IS NULL;

-- Update the functions to include separate timings
DROP FUNCTION IF EXISTS public.get_branch_delivery_settings(bigint);
DROP FUNCTION IF EXISTS public.get_all_branches_delivery_settings();

CREATE OR REPLACE FUNCTION public.get_branch_delivery_settings(p_branch_id bigint)
RETURNS TABLE (
    branch_id bigint,
    branch_name_en text,
    branch_name_ar text,
    minimum_order_amount numeric,
    delivery_service_enabled boolean,
    delivery_is_24_hours boolean,
    delivery_start_time time,
    delivery_end_time time,
    pickup_service_enabled boolean,
    pickup_is_24_hours boolean,
    pickup_start_time time,
    pickup_end_time time,
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
        COALESCE(b.delivery_service_enabled, true)::boolean,
        COALESCE(b.delivery_is_24_hours, true)::boolean,
        b.delivery_start_time,
        b.delivery_end_time,
        COALESCE(b.pickup_service_enabled, true)::boolean,
        COALESCE(b.pickup_is_24_hours, true)::boolean,
        b.pickup_start_time,
        b.pickup_end_time,
        COALESCE(b.delivery_message_ar, 'التوصيل متاح على مدار الساعة')::text,
        COALESCE(b.delivery_message_en, 'Delivery available 24/7')::text
    FROM public.branches b
    WHERE b.id = p_branch_id
    LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_all_branches_delivery_settings()
RETURNS TABLE (
    branch_id bigint,
    branch_name_en text,
    branch_name_ar text,
    minimum_order_amount numeric,
    delivery_service_enabled boolean,
    delivery_is_24_hours boolean,
    delivery_start_time time,
    delivery_end_time time,
    pickup_service_enabled boolean,
    pickup_is_24_hours boolean,
    pickup_start_time time,
    pickup_end_time time,
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
        COALESCE(b.delivery_service_enabled, true)::boolean,
        COALESCE(b.delivery_is_24_hours, true)::boolean,
        b.delivery_start_time,
        b.delivery_end_time,
        COALESCE(b.pickup_service_enabled, true)::boolean,
        COALESCE(b.pickup_is_24_hours, true)::boolean,
        b.pickup_start_time,
        b.pickup_end_time,
        COALESCE(b.delivery_message_ar, 'التوصيل متاح على مدار الساعة')::text,
        COALESCE(b.delivery_message_en, 'Delivery available 24/7')::text
    FROM public.branches b
    ORDER BY b.name_en;
END;
$$;

COMMENT ON FUNCTION public.get_branch_delivery_settings(bigint) IS 
'Get delivery settings for a specific branch with separate timings for delivery and pickup';

COMMENT ON FUNCTION public.get_all_branches_delivery_settings() IS 
'Get delivery settings for all branches with separate timings for delivery and pickup';

-- ================================================================
-- MIGRATION COMPLETE
-- ================================================================
