-- Fix deleted_bundle_offers table - change original_offer_id from UUID to INTEGER
-- Run this in Supabase SQL Editor

-- Drop the existing table (if it exists and has no important data)
DROP TABLE IF EXISTS deleted_bundle_offers CASCADE;

-- Recreate with correct data types
CREATE TABLE deleted_bundle_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_offer_id INTEGER NOT NULL,
  offer_data JSONB NOT NULL,
  bundles_data JSONB NOT NULL,
  deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_by UUID REFERENCES users(id),
  deletion_reason TEXT,
  CONSTRAINT deleted_bundle_offers_original_offer_id_key UNIQUE(original_offer_id)
);

-- Add indexes for better query performance
CREATE INDEX idx_deleted_bundle_offers_deleted_at 
  ON deleted_bundle_offers(deleted_at DESC);

CREATE INDEX idx_deleted_bundle_offers_deleted_by 
  ON deleted_bundle_offers(deleted_by);

CREATE INDEX idx_deleted_bundle_offers_original_id
  ON deleted_bundle_offers(original_offer_id);

-- Add table comment
COMMENT ON TABLE deleted_bundle_offers IS 'Archive table for deleted bundle offers - allows recovery and audit trail';

-- Add column comments
COMMENT ON COLUMN deleted_bundle_offers.original_offer_id IS 'The original offer ID from offers table (INTEGER)';
COMMENT ON COLUMN deleted_bundle_offers.offer_data IS 'Complete offer data as JSON';
COMMENT ON COLUMN deleted_bundle_offers.bundles_data IS 'Array of bundle data as JSON';
COMMENT ON COLUMN deleted_bundle_offers.deleted_by IS 'User who deleted the offer';
COMMENT ON COLUMN deleted_bundle_offers.deletion_reason IS 'Optional reason for deletion';

-- Enable Row Level Security
ALTER TABLE deleted_bundle_offers ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read deleted offers
CREATE POLICY "Allow authenticated users to view deleted offers"
  ON deleted_bundle_offers
  FOR SELECT
  TO authenticated
  USING (true);

-- Policy: Allow authenticated users to insert (delete offers)
CREATE POLICY "Allow authenticated users to archive offers"
  ON deleted_bundle_offers
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policy: Only allow admins to permanently delete from archive (optional)
CREATE POLICY "Only admins can delete from archive"
  ON deleted_bundle_offers
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role_type IN ('Admin', 'Master Admin')
    )
  );
