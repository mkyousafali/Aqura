-- Enable RLS on approver_visibility_config with permissive policy

ALTER TABLE public.approver_visibility_config ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow all access to approver_visibility_config" ON public.approver_visibility_config;

-- Create permissive policy for all operations (matching app pattern)
CREATE POLICY "Allow all access to approver_visibility_config"
  ON public.approver_visibility_config
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to all roles (critical for upsert operations)
GRANT ALL ON public.approver_visibility_config TO anon;
GRANT ALL ON public.approver_visibility_config TO authenticated;
GRANT ALL ON public.approver_visibility_config TO service_role;

-- Grant access to the sequence for ID generation
GRANT ALL ON public.approver_visibility_config_id_seq TO anon;
GRANT ALL ON public.approver_visibility_config_id_seq TO authenticated;
GRANT ALL ON public.approver_visibility_config_id_seq TO service_role;
