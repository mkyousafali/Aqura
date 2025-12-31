-- Flyer Offer Products Table Schema
CREATE TABLE IF NOT EXISTS flyer_offer_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id UUID NOT NULL,
  product_barcode TEXT NOT NULL,
  cost NUMERIC,
  sales_price NUMERIC,
  offer_price NUMERIC,
  profit_amount NUMERIC,
  profit_percent NUMERIC,
  profit_after_offer NUMERIC,
  decrease_amount NUMERIC,
  offer_qty INTEGER NOT NULL DEFAULT 1,
  limit_qty INTEGER,
  free_qty INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);
