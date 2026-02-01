-- Enable RLS on incident_types table with permissive policy

-- Enable RLS (Row Level Security)
ALTER TABLE public.incident_types ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to incident_types" ON public.incident_types;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to incident_types"
  ON public.incident_types
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON public.incident_types TO authenticated;
GRANT ALL ON public.incident_types TO service_role;
GRANT ALL ON public.incident_types TO anon;

-- Grant execute on functions if any
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;
