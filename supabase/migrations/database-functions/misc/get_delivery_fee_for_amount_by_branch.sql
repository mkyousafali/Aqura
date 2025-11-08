-- ================================================================
-- Function: get_delivery_fee_for_amount_by_branch
-- Description: Calculate delivery fee for an order amount within branch-specific tiers.
--              Falls back to global tiers if branch has no specific tiers.
-- Parameters:
--   - p_branch_id: bigint - Branch ID (nullable)
--   - p_order_amount: numeric - Order/cart total
-- Returns: numeric delivery fee
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_delivery_fee_for_amount_by_branch(
    p_branch_id bigint,
    p_order_amount numeric
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_fee numeric;
BEGIN
    -- Attempt branch-specific tier match
    SELECT t.delivery_fee INTO v_fee
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND t.branch_id = p_branch_id
      AND t.min_order_amount <= p_order_amount
      AND (t.max_order_amount IS NULL OR t.max_order_amount >= p_order_amount)
    ORDER BY t.min_order_amount DESC
    LIMIT 1;

    -- Fallback to global tiers if no branch-specific fee found
    IF v_fee IS NULL THEN
        SELECT t.delivery_fee INTO v_fee
        FROM public.delivery_fee_tiers t
        WHERE t.is_active = true
          AND t.branch_id IS NULL
          AND t.min_order_amount <= p_order_amount
          AND (t.max_order_amount IS NULL OR t.max_order_amount >= p_order_amount)
        ORDER BY t.min_order_amount DESC
        LIMIT 1;
    END IF;

    RETURN COALESCE(v_fee, 0);
END;
$$;

COMMENT ON FUNCTION public.get_delivery_fee_for_amount_by_branch(bigint, numeric) IS 'Calculate delivery fee for order amount using branch tiers or global fallback';

-- Example usage:
-- SELECT public.get_delivery_fee_for_amount_by_branch(3, 275.00);
-- SELECT public.get_delivery_fee_for_amount_by_branch(NULL, 120.00);
