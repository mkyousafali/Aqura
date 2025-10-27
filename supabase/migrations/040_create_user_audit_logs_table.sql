-- Create user_audit_logs table
CREATE TABLE IF NOT EXISTS public.user_audit_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID,
  target_user_id UUID,
  action VARCHAR(255) NOT NULL,
  table_name VARCHAR(255),
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  performed_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id)
);

-- Indexes for user_audit_logs
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_id ON public.user_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_target_user_id ON public.user_audit_logs(target_user_id);
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_record_id ON public.user_audit_logs(record_id);
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_created_at ON public.user_audit_logs(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.user_audit_logs ENABLE ROW LEVEL SECURITY;
