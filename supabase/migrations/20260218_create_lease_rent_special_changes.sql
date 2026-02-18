-- Special Changes table for tracking amount modifications to rent/lease parties
-- Used by Lease/Rent Special Changes feature and future transaction management & reports

CREATE TABLE IF NOT EXISTS lease_rent_special_changes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    party_type VARCHAR(10) NOT NULL CHECK (party_type IN ('rent', 'lease')),
    party_id UUID NOT NULL,
    field_name VARCHAR(50) NOT NULL,
    old_value DECIMAL(12,2) DEFAULT 0,
    new_value DECIMAL(12,2) NOT NULL,
    effective_from DATE NOT NULL,
    effective_until DATE,
    till_end_of_contract BOOLEAN DEFAULT false,
    payment_period VARCHAR(20) DEFAULT 'monthly',
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- Index for fast lookups by party
CREATE INDEX idx_special_changes_party ON lease_rent_special_changes(party_type, party_id);
CREATE INDEX idx_special_changes_dates ON lease_rent_special_changes(effective_from, effective_until);

-- RLS
ALTER TABLE lease_rent_special_changes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated users" ON lease_rent_special_changes;
DROP POLICY IF EXISTS "allow_all_authenticated" ON lease_rent_special_changes;
DROP POLICY IF EXISTS "Allow all access to lease_rent_special_changes" ON lease_rent_special_changes;

CREATE POLICY "Allow all access to lease_rent_special_changes"
  ON lease_rent_special_changes
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON lease_rent_special_changes TO authenticated;
GRANT ALL ON lease_rent_special_changes TO service_role;
GRANT ALL ON lease_rent_special_changes TO anon;
