-- Create approver_visibility_config table
-- Stores visibility scope configuration for each leave approver
-- visibility_type options: 'global', 'branch_specific', 'multiple_branches'

CREATE TABLE IF NOT EXISTS public.approver_visibility_config (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  visibility_type VARCHAR(50) NOT NULL DEFAULT 'global',
  CONSTRAINT approver_visibility_type_check CHECK (
    visibility_type IN ('global', 'branch_specific', 'multiple_branches')
  ),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_approver_visibility_user_id ON public.approver_visibility_config(user_id);
CREATE INDEX IF NOT EXISTS idx_approver_visibility_type ON public.approver_visibility_config(visibility_type);
CREATE INDEX IF NOT EXISTS idx_approver_visibility_active ON public.approver_visibility_config(is_active) 
WHERE (is_active = true);

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_approver_visibility_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER approver_visibility_config_timestamp_update
BEFORE UPDATE ON public.approver_visibility_config
FOR EACH ROW
EXECUTE FUNCTION update_approver_visibility_config_timestamp();
