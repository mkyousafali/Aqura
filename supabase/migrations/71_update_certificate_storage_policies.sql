-- =============================================
-- Update Certificate Storage Policies
-- Make storage policies more permissive for certificate uploads
-- =============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can upload certificates" ON storage.objects;
DROP POLICY IF EXISTS "Users can view certificates" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their certificates" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their certificates" ON storage.objects;

-- Create more permissive policies for certificates bucket
CREATE POLICY "Allow certificate uploads" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'clearance-certificates'
);

CREATE POLICY "Allow certificate viewing" ON storage.objects
FOR SELECT USING (
    bucket_id = 'clearance-certificates'
);

CREATE POLICY "Allow certificate updates" ON storage.objects
FOR UPDATE USING (
    bucket_id = 'clearance-certificates'
);

CREATE POLICY "Allow certificate deletion" ON storage.objects
FOR DELETE USING (
    bucket_id = 'clearance-certificates'
);

-- Also ensure the bucket settings are correct
UPDATE storage.buckets 
SET 
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'application/pdf']
WHERE id = 'clearance-certificates';