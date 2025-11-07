-- ================================================================
-- Function: get_branch_delivery_settings
-- Description: Get delivery settings for a specific branch
-- Parameters:
--   - p_branch_id: bigint - The branch ID
-- Returns: Record with branch delivery configuration with separate timings
-- ================================================================

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

COMMENT ON FUNCTION public.get_branch_delivery_settings(bigint) IS 
'Get delivery settings for a specific branch with separate timings for delivery and pickup';

-- ================================================================
-- Function: get_all_branches_delivery_settings
-- Description: Get delivery settings for all branches
-- Returns: Table with all branches delivery configuration with separate timings
-- ================================================================

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

COMMENT ON FUNCTION public.get_all_branches_delivery_settings() IS 
'Get delivery settings for all branches with separate timings for delivery and pickup';

-- Example usage:
-- SELECT * FROM get_branch_delivery_settings(1);
-- SELECT * FROM get_all_branches_delivery_settings();
