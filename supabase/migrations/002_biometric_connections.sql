-- Biometric Connections Table Schema
CREATE TABLE IF NOT EXISTS biometric_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id INTEGER NOT NULL,
  branch_name TEXT NOT NULL,
  server_ip TEXT NOT NULL,
  server_name TEXT,
  database_name TEXT NOT NULL,
  username TEXT NOT NULL,
  password TEXT NOT NULL,
  device_id TEXT NOT NULL,
  terminal_sn TEXT,
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMP WITH TIME ZONE,
  last_employee_sync_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  branch_location_code TEXT
);
