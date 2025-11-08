-- ================================================================
-- MIGRATION: Branch-specific Delivery Fee Tiers
-- Created: 2025-11-08
-- Description: Adds branch_id to delivery_fee_tiers and indexes for branch-aware queries
-- ================================================================

-- Add branch_id column to delivery_fee_tiers if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'delivery_fee_tiers' 
          AND column_name = 'branch_id'
    ) THEN
        ALTER TABLE public.delivery_fee_tiers
        ADD COLUMN branch_id bigint REFERENCES public.branches(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Indexes for branch-aware lookups
CREATE INDEX IF NOT EXISTS idx_delivery_tiers_branch_order_amount 
    ON public.delivery_fee_tiers(branch_id, min_order_amount, max_order_amount)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_delivery_tiers_branch_order 
    ON public.delivery_fee_tiers(branch_id, tier_order);

-- Optional: ensure tier_order uniqueness within scope (branch or global)
-- Note: This does not enforce range non-overlap; UI/validation should handle.
CREATE UNIQUE INDEX IF NOT EXISTS ux_delivery_tiers_scope_order
    ON public.delivery_fee_tiers(COALESCE(branch_id, -1), tier_order);

COMMENT ON COLUMN public.delivery_fee_tiers.branch_id IS 'When NULL, tier is global. When set, tier applies only to this branch.';

-- ================================================================
-- MIGRATION COMPLETE
-- ================================================================
