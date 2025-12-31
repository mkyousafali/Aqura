-- Customer Access Code History Table Schema
CREATE TABLE IF NOT EXISTS customer_access_code_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL,
  old_access_code VARCHAR,
  new_access_code VARCHAR NOT NULL,
  generated_by UUID NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
