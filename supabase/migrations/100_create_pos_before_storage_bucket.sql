-- Create pos-before storage bucket
-- Run this in Supabase SQL Editor or via API

-- First, check if bucket exists, if not create it
INSERT INTO storage.buckets (id, name, public)
VALUES ('pos-before', 'pos-before', true)
ON CONFLICT (id) DO NOTHING;

-- Set up bucket policies for authenticated users
CREATE POLICY "Allow authenticated users to upload to pos-before" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'pos-before');

CREATE POLICY "Allow authenticated users to read pos-before" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'pos-before');

CREATE POLICY "Allow authenticated users to delete from pos-before" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'pos-before');
