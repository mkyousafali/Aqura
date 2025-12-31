-- ERP Daily Sales Table Schema
CREATE TABLE IF NOT EXISTS erp_daily_sales (
  id INTEGER PRIMARY KEY DEFAULT nextval('erp_daily_sales_id_seq'),
  erp_connection_id INTEGER NOT NULL,
  sale_date DATE NOT NULL,
  total_sales NUMERIC NOT NULL,
  total_units_sold INTEGER NOT NULL,
  total_discount NUMERIC NOT NULL DEFAULT 0,
  payment_method_breakdown JSONB,
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
