-- Offer Usage Logs Table Schema
CREATE TABLE IF NOT EXISTS offer_usage_logs (
  id INTEGER PRIMARY KEY DEFAULT nextval('offer_usage_logs_id_seq'),
  offer_id INTEGER NOT NULL,
  customer_id UUID,
  order_id INTEGER,
  discount_applied NUMERIC NOT NULL,
  original_amount NUMERIC NOT NULL,
  final_amount NUMERIC NOT NULL,
  cart_items JSONB,
  used_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  session_id VARCHAR,
  device_type VARCHAR
);
