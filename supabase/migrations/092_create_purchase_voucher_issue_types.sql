-- Purchase Voucher Issue Types Table
CREATE TABLE IF NOT EXISTS purchase_voucher_issue_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type_name VARCHAR NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_issue_types_name ON purchase_voucher_issue_types(type_name);

-- Enable RLS (Row Level Security)
ALTER TABLE purchase_voucher_issue_types ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "pv_issue_types_authenticated_all" ON purchase_voucher_issue_types;
DROP POLICY IF EXISTS "pv_issue_types_service_role_all" ON purchase_voucher_issue_types;

-- Simple RLS Policies - Allow all operations
CREATE POLICY "pv_issue_types_authenticated_all" ON purchase_voucher_issue_types
  FOR ALL
  USING (true);

CREATE POLICY "pv_issue_types_service_role_all" ON purchase_voucher_issue_types
  FOR ALL
  USING (true);

-- Grant permissions to authenticated users
GRANT ALL ON purchase_voucher_issue_types TO authenticated;

-- Grant full permissions to service_role
GRANT ALL ON purchase_voucher_issue_types TO service_role;

-- Grant permissions to anon (anonymous users)
GRANT ALL ON purchase_voucher_issue_types TO anon;

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_issue_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS issue_types_updated_at_trigger ON purchase_voucher_issue_types;

CREATE TRIGGER issue_types_updated_at_trigger
BEFORE UPDATE ON purchase_voucher_issue_types
FOR EACH ROW
EXECUTE FUNCTION update_issue_types_updated_at();

-- Insert default issue types
INSERT INTO purchase_voucher_issue_types (type_name, description)
VALUES 
  ('gift', 'Issued as a gift'),
  ('sales', 'Issued for sales'),
  ('give', 'Issued to give away')
ON CONFLICT (type_name) DO NOTHING;
