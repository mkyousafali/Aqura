-- Migration 5: Update RLS Policies for Variation System
-- This migration updates Row Level Security policies for variation-related tables

-- Enable RLS on variation_audit_log
ALTER TABLE variation_audit_log ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own audit logs
CREATE POLICY "Users can view variation audit logs"
  ON variation_audit_log
  FOR SELECT
  USING (true); -- All authenticated users can view audit logs

-- Policy: Users can insert audit logs (system writes)
CREATE POLICY "System can insert variation audit logs"
  ON variation_audit_log
  FOR INSERT
  WITH CHECK (true);

-- Ensure flyer_products policies allow variation column access
-- Drop existing policies if they exist and recreate with variation support
DO $$
BEGIN
  -- Check if policies exist and drop them
  DROP POLICY IF EXISTS "Users can view flyer products" ON flyer_products;
  DROP POLICY IF EXISTS "Users can insert flyer products" ON flyer_products;
  DROP POLICY IF EXISTS "Users can update flyer products" ON flyer_products;
  DROP POLICY IF EXISTS "Users can delete flyer products" ON flyer_products;
END $$;

-- Recreate policies with full column access including variation columns
CREATE POLICY "Users can view flyer products"
  ON flyer_products
  FOR SELECT
  USING (true);

CREATE POLICY "Users can insert flyer products"
  ON flyer_products
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update flyer products"
  ON flyer_products
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Users can delete flyer products"
  ON flyer_products
  FOR DELETE
  USING (true);

-- Ensure offer_products policies allow variation column access
DO $$
BEGIN
  -- Check if policies exist and drop them
  DROP POLICY IF EXISTS "Users can view offer products" ON offer_products;
  DROP POLICY IF EXISTS "Users can insert offer products" ON offer_products;
  DROP POLICY IF EXISTS "Users can update offer products" ON offer_products;
  DROP POLICY IF EXISTS "Users can delete offer products" ON offer_products;
END $$;

-- Recreate policies with full column access including variation columns
CREATE POLICY "Users can view offer products"
  ON offer_products
  FOR SELECT
  USING (true);

CREATE POLICY "Users can insert offer products"
  ON offer_products
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update offer products"
  ON offer_products
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Users can delete offer products"
  ON offer_products
  FOR DELETE
  USING (true);

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON flyer_products TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON offer_products TO authenticated;
GRANT SELECT, INSERT ON variation_audit_log TO authenticated;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
