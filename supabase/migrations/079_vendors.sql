-- Vendors Table Schema
CREATE TABLE IF NOT EXISTS vendors (
  id INTEGER PRIMARY KEY DEFAULT nextval('vendors_id_seq'),
  vendor_name VARCHAR NOT NULL,
  vendor_code VARCHAR NOT NULL UNIQUE,
  contact_person VARCHAR,
  email VARCHAR,
  phone VARCHAR,
  address TEXT,
  city VARCHAR,
  postal_code VARCHAR,
  country VARCHAR,
  payment_terms VARCHAR,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
