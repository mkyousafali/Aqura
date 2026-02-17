-- Create default_incident_users table
-- Maps users to incident types as default handlers
-- These users get tasks + notifications regardless of branch when an incident of that type is reported

CREATE TABLE IF NOT EXISTS public.default_incident_users (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    incident_type_id text NOT NULL,
    created_at timestamptz DEFAULT now(),
    created_by uuid REFERENCES public.users(id),
    UNIQUE(user_id, incident_type_id)
);

-- Enable RLS
ALTER TABLE public.default_incident_users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow authenticated read" ON public.default_incident_users;
DROP POLICY IF EXISTS "Allow authenticated insert" ON public.default_incident_users;
DROP POLICY IF EXISTS "Allow authenticated delete" ON public.default_incident_users;
DROP POLICY IF EXISTS "Allow all access to default_incident_users" ON public.default_incident_users;

-- Simple permissive policy for all operations (matching app pattern)
CREATE POLICY "Allow all access to default_incident_users"
  ON public.default_incident_users
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON public.default_incident_users TO authenticated;
GRANT ALL ON public.default_incident_users TO service_role;
GRANT ALL ON public.default_incident_users TO anon;

-- Index for fast lookup by incident type and user
CREATE INDEX IF NOT EXISTS idx_default_incident_users_type ON public.default_incident_users(incident_type_id);
CREATE INDEX IF NOT EXISTS idx_default_incident_users_user ON public.default_incident_users(user_id);
