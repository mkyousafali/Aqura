-- ================================================================
-- Function: get_delivery_fee_for_amount
-- Description: Calculate delivery fee based on order amount and active tiers
-- Parameters:
--   - order_amount: numeric - The cart/order total amount
-- Returns: numeric - The delivery fee for the given amount
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_delivery_fee_for_amount(order_amount numeric)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    calculated_fee numeric;
BEGIN
    -- Find the appropriate tier for the given order amount
    SELECT delivery_fee INTO calculated_fee
    FROM public.delivery_fee_tiers
    WHERE is_active = true
      AND min_order_amount <= order_amount
      AND (max_order_amount IS NULL OR max_order_amount >= order_amount)
    ORDER BY min_order_amount DESC
    LIMIT 1;
    
    -- If no tier found, return 0 (shouldn't happen with proper setup)
    RETURN COALESCE(calculated_fee, 0);
END;
$$;

COMMENT ON FUNCTION public.get_delivery_fee_for_amount(numeric) IS 
'Calculate delivery fee based on order amount using active tier structure';

-- Example usage:
-- SELECT get_delivery_fee_for_amount(250.00); -- Returns 15.00
-- SELECT get_delivery_fee_for_amount(550.00); -- Returns 0.00 (free delivery)
