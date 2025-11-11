-- ============================================
-- Fix RLS Policy for offer_products Table
-- ============================================
-- Issue: Frontend cannot read offer_products when editing offers
-- Solution: Add RLS policy to allow Admin/Master Admin read access
-- ============================================

-- Drop existing policies if any (cleanup)
DROP POLICY IF EXISTS "offer_products_select_policy" ON offer_products;
DROP POLICY IF EXISTS "offer_products_insert_policy" ON offer_products;
DROP POLICY IF EXISTS "offer_products_update_policy" ON offer_products;
DROP POLICY IF EXISTS "offer_products_delete_policy" ON offer_products;

-- Enable RLS on offer_products table
ALTER TABLE offer_products ENABLE ROW LEVEL SECURITY;

-- SELECT policy: Admin and Master Admin can view all offer products
CREATE POLICY "offer_products_select_policy" ON offer_products
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

-- INSERT policy: Admin and Master Admin can add products to offers
CREATE POLICY "offer_products_insert_policy" ON offer_products
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

-- UPDATE policy: Admin and Master Admin can update offer products
CREATE POLICY "offer_products_update_policy" ON offer_products
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

-- DELETE policy: Admin and Master Admin can remove products from offers
CREATE POLICY "offer_products_delete_policy" ON offer_products
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

-- ============================================
-- Same fix for offer_bundles table
-- ============================================

DROP POLICY IF EXISTS "offer_bundles_select_policy" ON offer_bundles;
DROP POLICY IF EXISTS "offer_bundles_insert_policy" ON offer_bundles;
DROP POLICY IF EXISTS "offer_bundles_update_policy" ON offer_bundles;
DROP POLICY IF EXISTS "offer_bundles_delete_policy" ON offer_bundles;

ALTER TABLE offer_bundles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "offer_bundles_select_policy" ON offer_bundles
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

CREATE POLICY "offer_bundles_insert_policy" ON offer_bundles
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

CREATE POLICY "offer_bundles_update_policy" ON offer_bundles
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

CREATE POLICY "offer_bundles_delete_policy" ON offer_bundles
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

-- ============================================
-- Verification Query
-- ============================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename IN ('offer_products', 'offer_bundles')
ORDER BY tablename, policyname;
