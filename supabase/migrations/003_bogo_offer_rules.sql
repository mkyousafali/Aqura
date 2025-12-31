-- BOGO Offer Rules Table Schema
CREATE TABLE IF NOT EXISTS bogo_offer_rules (
  id INTEGER PRIMARY KEY DEFAULT nextval('bogo_offer_rules_id_seq'),
  offer_id INTEGER NOT NULL,
  buy_product_id VARCHAR NOT NULL,
  buy_quantity INTEGER NOT NULL,
  get_product_id VARCHAR NOT NULL,
  get_quantity INTEGER NOT NULL,
  discount_type VARCHAR NOT NULL,
  discount_value NUMERIC DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
