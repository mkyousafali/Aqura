-- Purchase Voucher Table Schema
-- ID format: PV + book_number (e.g., PV001, PV002, etc.)

CREATE TABLE IF NOT EXISTS purchase_vouchers (
  id VARCHAR PRIMARY KEY,
  book_number VARCHAR NOT NULL UNIQUE,
  serial_start INTEGER NOT NULL,
  serial_end INTEGER NOT NULL,
  voucher_count INTEGER NOT NULL,
  per_voucher_value NUMERIC NOT NULL,
  total_value NUMERIC NOT NULL,
  status VARCHAR DEFAULT 'active',
  created_by UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Purchase Voucher Items Table (individual vouchers within a book)
CREATE TABLE IF NOT EXISTS purchase_voucher_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_voucher_id VARCHAR NOT NULL REFERENCES purchase_vouchers(id),
  serial_number INTEGER NOT NULL,
  value NUMERIC NOT NULL,
  status VARCHAR DEFAULT 'stocked',
  stock INTEGER DEFAULT 1,
  issued_date TIMESTAMP WITH TIME ZONE,
  closed_date TIMESTAMP WITH TIME ZONE,
  remarks TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(purchase_voucher_id, serial_number)
);

-- Create sequence for auto-incrementing book numbers
CREATE SEQUENCE IF NOT EXISTS purchase_vouchers_book_seq START WITH 1 INCREMENT BY 1;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_purchase_vouchers_status ON purchase_vouchers(status);
CREATE INDEX IF NOT EXISTS idx_purchase_vouchers_created_at ON purchase_vouchers(created_at);
CREATE INDEX IF NOT EXISTS idx_purchase_voucher_items_pv_id ON purchase_voucher_items(purchase_voucher_id);
CREATE INDEX IF NOT EXISTS idx_purchase_voucher_items_status ON purchase_voucher_items(status);

-- Enable RLS (Row Level Security)
ALTER TABLE purchase_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_voucher_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "pv_authenticated_all" ON purchase_vouchers;
DROP POLICY IF EXISTS "pv_service_role_all" ON purchase_vouchers;
DROP POLICY IF EXISTS "pvi_authenticated_all" ON purchase_voucher_items;
DROP POLICY IF EXISTS "pvi_service_role_all" ON purchase_voucher_items;
DROP POLICY IF EXISTS "Allow all operations" ON purchase_vouchers;
DROP POLICY IF EXISTS "Service role full access" ON purchase_vouchers;
DROP POLICY IF EXISTS "Allow all operations" ON purchase_voucher_items;
DROP POLICY IF EXISTS "Service role full access" ON purchase_voucher_items;

-- Simple RLS Policies - Allow authenticated users all operations
CREATE POLICY "pv_authenticated_all" ON purchase_vouchers
  FOR ALL
  USING (true);

CREATE POLICY "pv_service_role_all" ON purchase_vouchers
  FOR ALL
  USING (true);

-- Simple RLS Policies for items
CREATE POLICY "pvi_authenticated_all" ON purchase_voucher_items
  FOR ALL
  USING (true);

CREATE POLICY "pvi_service_role_all" ON purchase_voucher_items
  FOR ALL
  USING (true);

-- Grant permissions to authenticated users
GRANT ALL ON purchase_vouchers TO authenticated;
GRANT ALL ON purchase_voucher_items TO authenticated;

-- Grant full permissions to service_role
GRANT ALL ON purchase_vouchers TO service_role;
GRANT ALL ON purchase_voucher_items TO service_role;

-- Grant permissions to anon (anonymous users)
GRANT ALL ON purchase_vouchers TO anon;
GRANT ALL ON purchase_voucher_items TO anon;

-- Create function to automatically update updated_at timestamp for purchase_vouchers
CREATE OR REPLACE FUNCTION update_purchase_vouchers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create function to automatically update updated_at timestamp for purchase_voucher_items
CREATE OR REPLACE FUNCTION update_purchase_voucher_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop triggers if exist and recreate for purchase_vouchers
DROP TRIGGER IF EXISTS purchase_vouchers_updated_at_trigger ON purchase_vouchers;

CREATE TRIGGER purchase_vouchers_updated_at_trigger
BEFORE UPDATE ON purchase_vouchers
FOR EACH ROW
EXECUTE FUNCTION update_purchase_vouchers_updated_at();

-- Drop triggers if exist and recreate for purchase_voucher_items
DROP TRIGGER IF EXISTS purchase_voucher_items_updated_at_trigger ON purchase_voucher_items;

CREATE TRIGGER purchase_voucher_items_updated_at_trigger
BEFORE UPDATE ON purchase_voucher_items
FOR EACH ROW
EXECUTE FUNCTION update_purchase_voucher_items_updated_at();
