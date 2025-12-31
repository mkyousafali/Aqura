-- Vendor Payment Schedule Table Schema
CREATE TABLE IF NOT EXISTS vendor_payment_schedule (
  id INTEGER PRIMARY KEY DEFAULT nextval('vendor_payment_schedule_id_seq'),
  vendor_id INTEGER NOT NULL,
  payment_due_date TIMESTAMP WITH TIME ZONE NOT NULL,
  payment_amount NUMERIC NOT NULL,
  payment_method VARCHAR,
  payment_status VARCHAR NOT NULL DEFAULT 'pending',
  payment_date TIMESTAMP WITH TIME ZONE,
  reference_number VARCHAR,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
