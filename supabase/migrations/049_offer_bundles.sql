-- Offer Bundles Table Schema
CREATE TABLE IF NOT EXISTS offer_bundles (
  id INTEGER PRIMARY KEY DEFAULT nextval('offer_bundles_id_seq'),
  offer_id INTEGER NOT NULL,
  bundle_name_ar VARCHAR NOT NULL,
  bundle_name_en VARCHAR NOT NULL,
  required_products JSONB NOT NULL,
  discount_value NUMERIC NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  discount_type VARCHAR DEFAULT 'amount'
);
