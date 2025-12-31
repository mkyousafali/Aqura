-- Requesters Table Schema
CREATE TABLE IF NOT EXISTS requesters (
  id INTEGER PRIMARY KEY DEFAULT nextval('requesters_id_seq'),
  name VARCHAR NOT NULL,
  email VARCHAR,
  phone VARCHAR,
  address TEXT,
  city VARCHAR,
  postal_code VARCHAR,
  country VARCHAR,
  contact_person VARCHAR,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
