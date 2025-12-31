-- HR Fingerprint Transactions Table Schema
CREATE TABLE IF NOT EXISTS hr_fingerprint_transactions (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  employee_id VARCHAR NOT NULL,
  name VARCHAR,
  branch_id BIGINT NOT NULL,
  date DATE NOT NULL,
  time TIME WITHOUT TIME ZONE NOT NULL,
  status VARCHAR NOT NULL,
  device_id VARCHAR,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  location TEXT
);
