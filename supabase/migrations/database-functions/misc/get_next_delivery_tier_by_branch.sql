-- ================================================================
-- Function: get_next_delivery_tier_by_branch
-- Description: For a given branch and current order amount, find the next tier
--              (branch-specific first, else global) that reduces the delivery fee.
-- Parameters:
--   - p_branch_id: bigint (nullable)
--   - p_current_amount: numeric
-- Returns: next tier info with amount needed and potential savings
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_next_delivery_tier_by_branch(
    p_branch_id bigint,
    p_current_amount numeric
)
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
    v_current_fee numeric;
BEGIN
    -- Determine current fee (branch-specific or global fallback)
    v_current_fee := public.get_delivery_fee_for_amount_by_branch(p_branch_id, p_current_amount);

    -- Search for next better tier within branch-specific tiers first
    RETURN QUERY
    SELECT 
        t.min_order_amount,
        t.delivery_fee,
        (t.min_order_amount - p_current_amount) AS amount_needed,
        (v_current_fee - t.delivery_fee) AS potential_savings,
        t.description_en,
        t.description_ar
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND ((p_branch_id IS NOT NULL AND t.branch_id = p_branch_id) OR (p_branch_id IS NULL AND t.branch_id IS NULL))
      AND t.min_order_amount > p_current_amount
      AND t.delivery_fee < v_current_fee
    ORDER BY t.min_order_amount ASC
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_next_delivery_tier_by_branch(bigint, numeric) IS 'Get next tier for branch/global reducing delivery fee with savings info';

-- Example usage:
-- SELECT * FROM public.get_next_delivery_tier_by_branch(2, 180.00);
-- SELECT * FROM public.get_next_delivery_tier_by_branch(NULL, 180.00);
