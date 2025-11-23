-- =====================================================
-- Flyer Master: Row Level Security Policies
-- Created: 2025-11-23
-- Description: Creates RLS policies for flyer tables
-- =====================================================

-- Enable Row Level Security on all flyer tables
ALTER TABLE public.flyer_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flyer_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flyer_offer_products ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- FLYER_PRODUCTS POLICIES
-- =====================================================

-- Policy: Allow public read access to flyer products
CREATE POLICY "flyer_products_select_policy"
ON public.flyer_products
FOR SELECT
TO public
USING (true);

-- Policy: Allow authenticated users to insert flyer products
CREATE POLICY "flyer_products_insert_policy"
ON public.flyer_products
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update flyer products
CREATE POLICY "flyer_products_update_policy"
ON public.flyer_products
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to delete flyer products
CREATE POLICY "flyer_products_delete_policy"
ON public.flyer_products
FOR DELETE
TO authenticated
USING (true);

-- =====================================================
-- FLYER_OFFERS POLICIES
-- =====================================================

-- Policy: Allow public read access to active flyer offers
CREATE POLICY "flyer_offers_select_policy"
ON public.flyer_offers
FOR SELECT
TO public
USING (is_active = true);

-- Policy: Allow authenticated users to view all flyer offers
CREATE POLICY "flyer_offers_select_all_policy"
ON public.flyer_offers
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert flyer offers
CREATE POLICY "flyer_offers_insert_policy"
ON public.flyer_offers
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update flyer offers
CREATE POLICY "flyer_offers_update_policy"
ON public.flyer_offers
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to delete flyer offers
CREATE POLICY "flyer_offers_delete_policy"
ON public.flyer_offers
FOR DELETE
TO authenticated
USING (true);

-- =====================================================
-- FLYER_OFFER_PRODUCTS POLICIES
-- =====================================================

-- Policy: Allow public read access to flyer offer products
CREATE POLICY "flyer_offer_products_select_policy"
ON public.flyer_offer_products
FOR SELECT
TO public
USING (true);

-- Policy: Allow authenticated users to insert flyer offer products
CREATE POLICY "flyer_offer_products_insert_policy"
ON public.flyer_offer_products
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update flyer offer products
CREATE POLICY "flyer_offer_products_update_policy"
ON public.flyer_offer_products
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to delete flyer offer products
CREATE POLICY "flyer_offer_products_delete_policy"
ON public.flyer_offer_products
FOR DELETE
TO authenticated
USING (true);

-- Add comments
COMMENT ON POLICY "flyer_products_select_policy" ON public.flyer_products IS 'Allows public read access to all flyer products';
COMMENT ON POLICY "flyer_offers_select_policy" ON public.flyer_offers IS 'Allows public read access to active flyer offers only';
COMMENT ON POLICY "flyer_offers_select_all_policy" ON public.flyer_offers IS 'Allows authenticated users to view all flyer offers including inactive';
COMMENT ON POLICY "flyer_offer_products_select_policy" ON public.flyer_offer_products IS 'Allows public read access to flyer offer products';
