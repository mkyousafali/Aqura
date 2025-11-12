-- ============================================================
-- Fix offer_products constraint to allow both percentage and price
-- This allows storing calculated offer price even for percentage offers
-- ============================================================

-- Drop the old constraint that enforces either/or
ALTER TABLE public.offer_products 
DROP CONSTRAINT IF EXISTS either_percentage_or_price;

-- Add new constraint that ensures at least ONE is set (but allows both)
ALTER TABLE public.offer_products 
ADD CONSTRAINT at_least_one_discount CHECK (
  offer_percentage IS NOT NULL OR offer_price IS NOT NULL
);

-- Add comment explaining the change
COMMENT ON CONSTRAINT at_least_one_discount ON public.offer_products IS 
  'Ensures at least one discount field is set. Both can be set for percentage offers (stores calculated price).';

-- ============================================================
-- Migration Complete!
-- ============================================================
-- Now you can save both offer_percentage and offer_price together
-- This is useful for:
-- 1. Displaying final price without recalculation
-- 2. Cart calculations using stored price
-- 3. Consistency across all offer types
-- ============================================================
