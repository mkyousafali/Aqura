-- Create lease_rent_lease_parties table
-- Stores lease party records for the Lease and Rent module

CREATE TABLE IF NOT EXISTS lease_rent_lease_parties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES lease_rent_properties(id) ON DELETE CASCADE,
  property_space_id UUID REFERENCES lease_rent_property_spaces(id) ON DELETE SET NULL,
  party_name_en VARCHAR(255) NOT NULL,
  party_name_ar VARCHAR(255) NOT NULL,
  shop_name VARCHAR(255),
  contact_number VARCHAR(50),
  email VARCHAR(255),
  contract_start_date DATE,
  contract_end_date DATE,
  is_open_contract BOOLEAN DEFAULT false,
  lease_amount_contract NUMERIC(12,2) DEFAULT 0,
  lease_amount_outside_contract NUMERIC(12,2) DEFAULT 0,
  utility_charges NUMERIC(12,2) DEFAULT 0,
  security_charges NUMERIC(12,2) DEFAULT 0,
  other_charges JSONB DEFAULT '[]'::jsonb,
  payment_mode VARCHAR(20) DEFAULT 'cash',
  collection_incharge_id TEXT,
  payment_period VARCHAR(30) DEFAULT 'monthly',
  payment_specific_date INTEGER,
  payment_end_of_month BOOLEAN DEFAULT false,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_lrlp_property_id ON lease_rent_lease_parties(property_id);
CREATE INDEX IF NOT EXISTS idx_lrlp_property_space_id ON lease_rent_lease_parties(property_space_id);
CREATE INDEX IF NOT EXISTS idx_lrlp_collection_incharge ON lease_rent_lease_parties(collection_incharge_id);
CREATE INDEX IF NOT EXISTS idx_lrlp_payment_mode ON lease_rent_lease_parties(payment_mode);
CREATE INDEX IF NOT EXISTS idx_lrlp_contract_dates ON lease_rent_lease_parties(contract_start_date, contract_end_date);

-- Auto-update trigger
CREATE OR REPLACE FUNCTION update_lease_rent_lease_parties_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lease_rent_lease_parties_timestamp_update
BEFORE UPDATE ON lease_rent_lease_parties
FOR EACH ROW
EXECUTE FUNCTION update_lease_rent_lease_parties_timestamp();

-- Enable RLS
ALTER TABLE lease_rent_lease_parties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to lease_rent_lease_parties"
  ON lease_rent_lease_parties
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON lease_rent_lease_parties TO authenticated;
GRANT ALL ON lease_rent_lease_parties TO service_role;
GRANT ALL ON lease_rent_lease_parties TO anon;
