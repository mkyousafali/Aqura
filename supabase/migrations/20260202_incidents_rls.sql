-- Enable RLS on incidents table with permissive policy

-- Enable RLS (Row Level Security)
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to incidents" ON public.incidents;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to incidents"
  ON public.incidents
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON public.incidents TO authenticated;
GRANT ALL ON public.incidents TO service_role;
GRANT ALL ON public.incidents TO anon;

-- Grant execute on functions if any
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;

-- Grant type usage
GRANT USAGE ON TYPE public.resolution_status TO authenticated;
GRANT USAGE ON TYPE public.resolution_status TO service_role;
GRANT USAGE ON TYPE public.resolution_status TO anon;
