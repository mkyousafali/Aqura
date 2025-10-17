-- =============================================
-- Create certificates storage bucket for clearance certificates
-- =============================================

-- Create the certificates bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'certificates',
  'certificates',
  true,
  10485760, -- 10MB limit
  '["image/jpeg","image/png","image/webp","application/pdf"]'
)
ON CONFLICT (id) DO NOTHING;

-- Add RLS policies for the certificates bucket
CREATE POLICY "Authenticated users can view certificates" ON storage.objects
FOR SELECT USING (
  bucket_id = 'certificates' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Authenticated users can upload certificates" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'certificates' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can update their own certificates" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'certificates' AND
  auth.uid()::text = (storage.foldername(name))[1] OR
  auth.role() = 'service_role'
);

CREATE POLICY "Users can delete their own certificates" ON storage.objects
FOR DELETE USING (
  bucket_id = 'certificates' AND
  auth.uid()::text = (storage.foldername(name))[1] OR
  auth.role() = 'service_role'
);

-- Add comment
COMMENT ON TABLE storage.buckets IS 'Storage bucket for clearance certificates and other system-generated certificates';