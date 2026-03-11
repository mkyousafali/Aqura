-- Create approver_branch_access table
-- Junction table: Maps approvers to branches they can access
-- Used when visibility_type = 'branch_specific' (1 branch) or 'multiple_branches' (multiple)

CREATE TABLE IF NOT EXISTS public.approver_branch_access (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  -- Ensure no duplicate assignments
  UNIQUE(user_id, branch_id),
  CONSTRAINT approver_branch_access_active_check CHECK (is_active = true OR is_active = false)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_approver_branch_access_user_id ON public.approver_branch_access(user_id);
CREATE INDEX IF NOT EXISTS idx_approver_branch_access_branch_id ON public.approver_branch_access(branch_id);
CREATE INDEX IF NOT EXISTS idx_approver_branch_access_active ON public.approver_branch_access(is_active) 
WHERE (is_active = true);
CREATE INDEX IF NOT EXISTS idx_approver_branch_access_user_branch ON public.approver_branch_access(user_id, branch_id);
