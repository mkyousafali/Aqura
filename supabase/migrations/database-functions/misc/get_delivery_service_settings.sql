-- ================================================================
-- Function: get_delivery_service_settings
-- Description: Get global delivery service configuration
-- Returns: Record with delivery service settings
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_delivery_service_settings()
RETURNS TABLE (
    minimum_order_amount numeric,
    is_24_hours boolean,
    operating_start_time time,
    operating_end_time time,
    is_active boolean,
    display_message_ar text,
    display_message_en text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.minimum_order_amount,
        s.is_24_hours,
        s.operating_start_time,
        s.operating_end_time,
        s.is_active,
        s.display_message_ar,
        s.display_message_en
    FROM public.delivery_service_settings s
    WHERE s.id = '00000000-0000-0000-0000-000000000001'::uuid
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_delivery_service_settings() IS 
'Get global delivery service configuration settings';

-- ================================================================
-- Function: get_branch_service_availability
-- Description: Check if delivery/pickup services are enabled for a branch
-- Parameters:
--   - branch_id: uuid - The branch ID to check
-- Returns: Record with service availability flags
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_branch_service_availability(branch_id uuid)
RETURNS TABLE (
    delivery_enabled boolean,
    pickup_enabled boolean,
    branch_name_en text,
    branch_name_ar text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.delivery_service_enabled,
        b.pickup_service_enabled,
        b.name_en,
        b.name_ar
    FROM public.branches b
    WHERE b.id = branch_id
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_branch_service_availability(uuid) IS 
'Check delivery and pickup service availability for a specific branch';

-- Example usage:
-- SELECT * FROM get_branch_service_availability('branch-uuid-here');
