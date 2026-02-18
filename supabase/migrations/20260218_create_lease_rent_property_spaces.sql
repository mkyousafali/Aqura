-- ============================================
-- lease_rent_properties table
-- Stores property definitions for the Lease and Rent module
-- ============================================

CREATE TABLE IF NOT EXISTS lease_rent_properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_en VARCHAR(255) NOT NULL,
  name_ar VARCHAR(255) NOT NULL,
  location_en VARCHAR(500),
  location_ar VARCHAR(500),
  is_leased BOOLEAN DEFAULT false,
  is_rented BOOLEAN DEFAULT false,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lease_rent_properties_created_by ON lease_rent_properties(created_by);
CREATE INDEX IF NOT EXISTS idx_lease_rent_properties_is_leased ON lease_rent_properties(is_leased);
CREATE INDEX IF NOT EXISTS idx_lease_rent_properties_is_rented ON lease_rent_properties(is_rented);

CREATE OR REPLACE FUNCTION update_lease_rent_properties_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lease_rent_properties_timestamp_update
BEFORE UPDATE ON lease_rent_properties
FOR EACH ROW
EXECUTE FUNCTION update_lease_rent_properties_timestamp();

ALTER TABLE lease_rent_properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to lease_rent_properties"
  ON lease_rent_properties
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON lease_rent_properties TO authenticated;
GRANT ALL ON lease_rent_properties TO service_role;
GRANT ALL ON lease_rent_properties TO anon;

-- Insert one example record
INSERT INTO lease_rent_properties (name_en, name_ar, location_en, location_ar, is_leased, is_rented)
VALUES ('Main Office Building', 'مبنى المكتب الرئيسي', 'Riyadh, King Fahd Road', 'الرياض، طريق الملك فهد', true, false);

-- ============================================
-- lease_rent_property_spaces table
-- Stores spaces within properties (references lease_rent_properties)
-- ============================================

CREATE TABLE IF NOT EXISTS lease_rent_property_spaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES lease_rent_properties(id) ON DELETE CASCADE,
  space_number VARCHAR(100) NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lease_rent_property_spaces_property_id ON lease_rent_property_spaces(property_id);
CREATE INDEX IF NOT EXISTS idx_lease_rent_property_spaces_created_by ON lease_rent_property_spaces(created_by);

-- Prevent duplicate space numbers for the same property
ALTER TABLE lease_rent_property_spaces
ADD CONSTRAINT unique_property_space_number UNIQUE (property_id, space_number);

CREATE OR REPLACE FUNCTION update_lease_rent_property_spaces_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lease_rent_property_spaces_timestamp_update
BEFORE UPDATE ON lease_rent_property_spaces
FOR EACH ROW
EXECUTE FUNCTION update_lease_rent_property_spaces_timestamp();

ALTER TABLE lease_rent_property_spaces ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to lease_rent_property_spaces"
  ON lease_rent_property_spaces
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON lease_rent_property_spaces TO authenticated;
GRANT ALL ON lease_rent_property_spaces TO service_role;
GRANT ALL ON lease_rent_property_spaces TO anon;

-- Insert example record linked to the property above
INSERT INTO lease_rent_property_spaces (property_id, space_number)
VALUES (
  (SELECT id FROM lease_rent_properties WHERE name_en = 'Main Office Building' LIMIT 1),
  'A-101'
);
