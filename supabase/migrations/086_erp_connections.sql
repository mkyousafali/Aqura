-- ERP Connections Table Schema
CREATE TABLE IF NOT EXISTS erp_connections (
  id INTEGER PRIMARY KEY DEFAULT nextval('erp_connections_id_seq'),
  erp_system_name VARCHAR NOT NULL,
  connection_url VARCHAR NOT NULL,
  api_key VARCHAR NOT NULL,
  api_secret VARCHAR,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_sync_at TIMESTAMP WITH TIME ZONE,
  sync_frequency VARCHAR NOT NULL DEFAULT 'daily',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
