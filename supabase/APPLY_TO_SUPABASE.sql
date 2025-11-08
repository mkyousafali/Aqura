-- ================================================================
-- COMBINED MIGRATION: Branch-specific Delivery Fee Tiers
-- Created: 2025-11-08
-- Instructions: Copy this entire file and paste into Supabase SQL Editor, then run
-- ================================================================

-- ================================================================
-- STEP 1: Add branch_id column to delivery_fee_tiers
-- ================================================================

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
CREATE UNIQUE INDEX IF NOT EXISTS ux_delivery_tiers_scope_order
    ON public.delivery_fee_tiers(COALESCE(branch_id, -1), tier_order);

COMMENT ON COLUMN public.delivery_fee_tiers.branch_id IS 'When NULL, tier is global. When set, tier applies only to this branch.';

-- ================================================================
-- STEP 2: Create get_delivery_tiers_by_branch function
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_delivery_tiers_by_branch(p_branch_id bigint)
RETURNS TABLE (
    id uuid,
    branch_id bigint,
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
    -- Strictly branch-specific tiers; if branch_id is NULL, return empty set
    IF p_branch_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        t.id,
        t.branch_id,
        t.min_order_amount,
        t.max_order_amount,
        t.delivery_fee,
        t.tier_order,
        t.is_active,
        t.description_en,
        t.description_ar
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND t.branch_id = p_branch_id
    ORDER BY t.tier_order ASC;
END;
$$;

COMMENT ON FUNCTION public.get_delivery_tiers_by_branch(bigint) IS 'Get active delivery fee tiers for a specific branch only';

-- ================================================================
-- STEP 3: Create get_delivery_fee_for_amount_by_branch function
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
    -- Require a branch id; without it, no fee can be determined
    IF p_branch_id IS NULL THEN
        RETURN 0;
    END IF;

    -- Attempt branch-specific tier match
    SELECT t.delivery_fee INTO v_fee
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND t.branch_id = p_branch_id
      AND t.min_order_amount <= p_order_amount
      AND (t.max_order_amount IS NULL OR t.max_order_amount >= p_order_amount)
    ORDER BY t.min_order_amount DESC
    LIMIT 1;

    RETURN COALESCE(v_fee, 0);
END;
$$;

COMMENT ON FUNCTION public.get_delivery_fee_for_amount_by_branch(bigint, numeric) IS 'Calculate delivery fee for order amount using branch tiers only';

-- ================================================================
-- STEP 4: Create get_next_delivery_tier_by_branch function
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
    -- Require branch id
    IF p_branch_id IS NULL THEN
        RETURN; -- empty set
    END IF;

    v_current_fee := public.get_delivery_fee_for_amount_by_branch(p_branch_id, p_current_amount);

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
      AND t.branch_id = p_branch_id
      AND t.min_order_amount > p_current_amount
      AND t.delivery_fee < v_current_fee
    ORDER BY t.min_order_amount ASC
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_next_delivery_tier_by_branch(bigint, numeric) IS 'Get next tier for branch reducing delivery fee with savings info';

-- ================================================================
-- STEP 5: Copy existing tiers to all branches
-- ================================================================

DO $$
DECLARE
    branch_record RECORD;
    tier_record RECORD;
BEGIN
    -- Loop through all branches
    FOR branch_record IN SELECT id FROM public.branches LOOP
        -- Loop through all existing global tiers (where branch_id is NULL)
        FOR tier_record IN 
            SELECT min_order_amount, max_order_amount, delivery_fee, tier_order, 
                   description_en, description_ar, is_active
            FROM public.delivery_fee_tiers 
            WHERE branch_id IS NULL 
            ORDER BY tier_order ASC
        LOOP
            -- Insert tier for this branch
            INSERT INTO public.delivery_fee_tiers (
                branch_id,
                min_order_amount,
                max_order_amount,
                delivery_fee,
                tier_order,
                description_en,
                description_ar,
                is_active
            ) VALUES (
                branch_record.id,
                tier_record.min_order_amount,
                tier_record.max_order_amount,
                tier_record.delivery_fee,
                tier_record.tier_order,
                tier_record.description_en,
                tier_record.description_ar,
                tier_record.is_active
            )
            ON CONFLICT DO NOTHING;
        END LOOP;
        
        RAISE NOTICE 'Copied tiers to branch ID: %', branch_record.id;
    END LOOP;
END $$;

-- ================================================================
-- MIGRATION COMPLETE - Branch-specific delivery fee tiers ready!
-- All branches now have their own copy of the tiers!
-- ================================================================
