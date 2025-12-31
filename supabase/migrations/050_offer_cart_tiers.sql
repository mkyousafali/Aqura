-- Offer Cart Tiers Table Schema
CREATE TABLE IF NOT EXISTS offer_cart_tiers (
  id INTEGER PRIMARY KEY DEFAULT nextval('offer_cart_tiers_id_seq'),
  offer_id INTEGER NOT NULL,
  tier_number INTEGER NOT NULL,
  min_amount NUMERIC NOT NULL,
  max_amount NUMERIC,
  discount_type VARCHAR NOT NULL,
  discount_value NUMERIC NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
