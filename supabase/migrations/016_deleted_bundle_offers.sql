-- Deleted Bundle Offers Table Schema
CREATE TABLE IF NOT EXISTS deleted_bundle_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_offer_id INTEGER NOT NULL,
  offer_data JSONB NOT NULL,
  bundles_data JSONB NOT NULL,
  deleted_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_by UUID,
  deletion_reason TEXT
);
