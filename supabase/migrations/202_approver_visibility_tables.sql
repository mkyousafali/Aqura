-- Create approver_visibility_config table
-- Stores the visibility scope configuration for each approver (globally or branch-specific)

CREATE TABLE IF NOT EXISTS public.approver_visibility_config (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  visibility_type VARCHAR(50) NOT NULL CHECK (visibility_type IN ('global', 'branch_specific', 'multiple_branches')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT approver_visibility_config_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.users (id) ON DELETE CASCADE,
  CONSTRAINT approver_visibility_config_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.users (id) ON DELETE SET NULL,
  CONSTRAINT approver_visibility_config_updated_by_fkey 
    FOREIGN KEY (updated_by) REFERENCES public.users (id) ON DELETE SET NULL
);

-- Create approver_branch_access table
-- Stores which branches an approver can access (used for 'branch_specific' and 'multiple_branches' modes)

CREATE TABLE IF NOT EXISTS public.approver_branch_access (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  branch_id BIGINT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT approver_branch_access_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.users (id) ON DELETE CASCADE,
  CONSTRAINT approver_branch_access_branch_id_fkey 
    FOREIGN KEY (branch_id) REFERENCES public.branches (id) ON DELETE CASCADE,
  CONSTRAINT approver_branch_access_unique 
    UNIQUE (user_id, branch_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_approver_visibility_config_user_id 
  ON public.approver_visibility_config (user_id);

CREATE INDEX IF NOT EXISTS idx_approver_visibility_config_visibility_type 
  ON public.approver_visibility_config (visibility_type) 
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_approver_branch_access_user_id 
  ON public.approver_branch_access (user_id);

CREATE INDEX IF NOT EXISTS idx_approver_branch_access_branch_id 
  ON public.approver_branch_access (branch_id);

CREATE INDEX IF NOT EXISTS idx_approver_branch_access_user_branch 
  ON public.approver_branch_access (user_id, branch_id) 
  WHERE is_active = true;

-- Create auto-update triggers for updated_at
CREATE OR REPLACE FUNCTION update_approver_visibility_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_approver_branch_access_timestamp()
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

CREATE TRIGGER approver_branch_access_timestamp_update
BEFORE UPDATE ON public.approver_branch_access
FOR EACH ROW
EXECUTE FUNCTION update_approver_branch_access_timestamp();
