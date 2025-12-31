-- Product Units Table Schema
CREATE TABLE IF NOT EXISTS product_units (
  id VARCHAR PRIMARY KEY,
  name_en VARCHAR NOT NULL,
  name_ar VARCHAR NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID
);
