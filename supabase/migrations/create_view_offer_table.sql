-- Create view_offer table schema
CREATE TABLE IF NOT EXISTS public.view_offer (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_name VARCHAR(255) NOT NULL,
  branch_id BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  start_time TIME WITHOUT TIME ZONE NOT NULL,
  end_date DATE NOT NULL,
  end_time TIME WITHOUT TIME ZONE NOT NULL,
  file_url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index on branch_id for faster queries
CREATE INDEX IF NOT EXISTS idx_view_offer_branch_id ON public.view_offer(branch_id);

-- Create index on date and time range for faster filtering
CREATE INDEX IF NOT EXISTS idx_view_offer_datetime ON public.view_offer(start_date, start_time, end_date, end_time);

-- Enable Row Level Security (RLS)
ALTER TABLE public.view_offer ENABLE ROW LEVEL SECURITY;

-- Create single permissive policy for all operations (matching branches table pattern)
DROP POLICY IF EXISTS "Enable all access for view_offer" ON public.view_offer;
CREATE POLICY "Enable all access for view_offer"
  ON public.view_offer
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant permissions to all roles (matching branches table)
GRANT INSERT, SELECT, UPDATE, DELETE ON public.view_offer TO anon;
GRANT INSERT, SELECT, UPDATE, DELETE ON public.view_offer TO authenticated;
GRANT INSERT, SELECT, UPDATE, DELETE ON public.view_offer TO service_role;

-- ============================================
-- STORAGE BUCKET SETUP
-- ============================================

-- Create storage bucket for offer files (accepts any file type)
INSERT INTO storage.buckets (id, name, public)
VALUES ('offer-pdfs', 'offer-pdfs', true)
ON CONFLICT (id) DO NOTHING;

-- Create single permissive policy for storage (matching simple pattern)
DROP POLICY IF EXISTS "Enable all access to offer-pdfs" ON storage.objects;
CREATE POLICY "Enable all access to offer-pdfs"
ON storage.objects
FOR ALL
USING (bucket_id = 'offer-pdfs')
WITH CHECK (bucket_id = 'offer-pdfs');

-- Grant permissions to all roles
GRANT INSERT, SELECT, UPDATE, DELETE ON storage.objects TO anon;
GRANT INSERT, SELECT, UPDATE, DELETE ON storage.objects TO authenticated;
GRANT INSERT, SELECT, UPDATE, DELETE ON storage.objects TO service_role;
