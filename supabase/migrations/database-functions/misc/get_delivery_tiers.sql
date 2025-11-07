-- ================================================================
-- Function: get_all_delivery_tiers
-- Description: Get all active delivery fee tiers ordered by tier_order
-- Returns: Table of delivery tier information
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_all_delivery_tiers()
RETURNS TABLE (
    id uuid,
    min_order_amount numeric,
    max_order_amount numeric,
    delivery_fee numeric,
    tier_order integer,
    is_active boolean,
    description_en text,
    description_ar text
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.min_order_amount,
        t.max_order_amount,
        t.delivery_fee,
        t.tier_order,
        t.is_active,
        t.description_en,
        t.description_ar
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
    ORDER BY t.tier_order ASC;
END;
$$;

COMMENT ON FUNCTION public.get_all_delivery_tiers() IS 
'Get all active delivery fee tiers ordered for display';

-- ================================================================
-- Function: get_next_delivery_tier
-- Description: Get the next tier that would reduce delivery fee
-- Parameters:
--   - current_amount: numeric - Current cart total
-- Returns: Record with next tier information
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_next_delivery_tier(current_amount numeric)
RETURNS TABLE (
    next_tier_min_amount numeric,
    next_tier_delivery_fee numeric,
    amount_needed numeric,
    potential_savings numeric,
    description_en text,
    description_ar text
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    current_fee numeric;
BEGIN
    -- Get current delivery fee
    current_fee := public.get_delivery_fee_for_amount(current_amount);
    
    -- Find next better tier
    RETURN QUERY
    SELECT 
        t.min_order_amount,
        t.delivery_fee,
        (t.min_order_amount - current_amount) as amount_needed,
        (current_fee - t.delivery_fee) as potential_savings,
        t.description_en,
        t.description_ar
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND t.min_order_amount > current_amount
      AND t.delivery_fee < current_fee
    ORDER BY t.min_order_amount ASC
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_next_delivery_tier(numeric) IS 
'Get the next tier that would reduce delivery fee with amount needed to reach it';

-- Example usage:
-- SELECT * FROM get_next_delivery_tier(250.00);
