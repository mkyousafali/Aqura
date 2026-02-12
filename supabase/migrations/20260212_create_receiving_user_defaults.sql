-- Create receiving_user_defaults table
-- Stores the default branch for receiving per user
-- When a user sets a default branch, it will auto-select on StartReceiving mount

CREATE TABLE IF NOT EXISTS receiving_user_defaults (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  default_branch_id BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_receiving_user_defaults_user_id ON receiving_user_defaults(user_id);
CREATE INDEX IF NOT EXISTS idx_receiving_user_defaults_branch_id ON receiving_user_defaults(default_branch_id);

-- Auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_receiving_user_defaults_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER receiving_user_defaults_timestamp_update
BEFORE UPDATE ON receiving_user_defaults
FOR EACH ROW
EXECUTE FUNCTION update_receiving_user_defaults_timestamp();
