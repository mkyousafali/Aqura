-- =====================================================
-- Biometric Connections Table Migration
-- Date: November 28, 2025
-- Purpose: Store biometric server configurations for attendance sync
-- =====================================================

-- Create biometric_connections table
CREATE TABLE IF NOT EXISTS biometric_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  branch_name TEXT NOT NULL,
  server_ip TEXT NOT NULL,
  server_name TEXT,
  database_name TEXT NOT NULL,
  username TEXT NOT NULL,
  password TEXT NOT NULL,
  device_id TEXT NOT NULL,
  terminal_sn TEXT,
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_employee_sync_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_branch_device UNIQUE(branch_id, device_id)
);

-- Add comment to table
COMMENT ON TABLE biometric_connections IS 'Stores biometric server connection configurations for ZKBioTime attendance sync';

-- Add comments to columns
COMMENT ON COLUMN biometric_connections.branch_id IS 'References branches.id - which Aqura branch this config belongs to';
COMMENT ON COLUMN biometric_connections.server_ip IS 'IP address of ZKBioTime SQL Server (e.g., 192.168.0.3)';
COMMENT ON COLUMN biometric_connections.server_name IS 'SQL Server instance name (e.g., SQLEXPRESS, WIN-D1D6EN8240A)';
COMMENT ON COLUMN biometric_connections.database_name IS 'ZKBioTime database name (e.g., Zkurbard)';
COMMENT ON COLUMN biometric_connections.terminal_sn IS 'Optional: Filter by specific terminal serial number (e.g., MFP3243700773)';
COMMENT ON COLUMN biometric_connections.device_id IS 'Computer name/ID running the sync app';
COMMENT ON COLUMN biometric_connections.last_sync_at IS 'Timestamp of last punch transaction sync';
COMMENT ON COLUMN biometric_connections.last_employee_sync_at IS 'Timestamp of last employee sync';

-- Enable Row Level Security
ALTER TABLE biometric_connections ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for re-running migration)
DROP POLICY IF EXISTS "Enable read for authenticated users" ON biometric_connections;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON biometric_connections;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON biometric_connections;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON biometric_connections;

-- Create RLS policies (allowing authenticated users full access)
CREATE POLICY "Enable read for authenticated users" ON biometric_connections
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Enable insert for authenticated users" ON biometric_connections
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update for authenticated users" ON biometric_connections
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete for authenticated users" ON biometric_connections
  FOR DELETE USING (auth.role() = 'authenticated');

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_biometric_connections_branch ON biometric_connections(branch_id);
CREATE INDEX IF NOT EXISTS idx_biometric_connections_active ON biometric_connections(is_active);
CREATE INDEX IF NOT EXISTS idx_biometric_connections_device ON biometric_connections(device_id);
CREATE INDEX IF NOT EXISTS idx_biometric_connections_terminal ON biometric_connections(terminal_sn);

-- =====================================================
-- Verification Queries
-- =====================================================

-- Check if table was created successfully
SELECT 
  table_name, 
  table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'biometric_connections';

-- Check table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'biometric_connections'
ORDER BY ordinal_position;

-- Check indexes
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'biometric_connections';

-- Check RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'biometric_connections';

-- =====================================================
-- Sample Test Insert (Optional - remove after testing)
-- =====================================================

/*
INSERT INTO biometric_connections (
  branch_id,
  branch_name,
  server_ip,
  server_name,
  database_name,
  username,
  password,
  device_id,
  terminal_sn
) VALUES (
  3,
  'Urban Market (Araidah)',
  '192.168.0.3',
  'WIN-D1D6EN8240A',
  'Zkurbard',
  'sa',
  'Polosys*123',
  'test-device-001',
  'MFP3243700773'
);

-- Verify insert
SELECT * FROM biometric_connections;

-- Clean up test data
DELETE FROM biometric_connections WHERE device_id = 'test-device-001';
*/

-- =====================================================
-- Migration Complete
-- =====================================================
