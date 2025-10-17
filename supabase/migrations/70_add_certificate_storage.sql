-- =============================================
-- Add Certificate Storage Support
-- Add certificate URL column and storage bucket
-- =============================================

-- Add certificate_url column to receiving_records table
ALTER TABLE receiving_records 
ADD COLUMN certificate_url TEXT NULL;

-- Add certificate_generated_at timestamp
ALTER TABLE receiving_records 
ADD COLUMN certificate_generated_at TIMESTAMPTZ NULL;

-- Add certificate_file_name for tracking
ALTER TABLE receiving_records 
ADD COLUMN certificate_file_name TEXT NULL;

-- Create storage bucket for certificates if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'clearance-certificates',
    'clearance-certificates',
    true,
    10485760, -- 10MB limit
    ARRAY['image/png', 'image/jpeg', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for the certificates bucket
CREATE POLICY "Users can upload certificates" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'clearance-certificates' AND
    auth.uid() IS NOT NULL
);

CREATE POLICY "Users can view certificates" ON storage.objects
FOR SELECT USING (
    bucket_id = 'clearance-certificates'
);

CREATE POLICY "Users can update their certificates" ON storage.objects
FOR UPDATE USING (
    bucket_id = 'clearance-certificates' AND
    auth.uid() IS NOT NULL
);

CREATE POLICY "Users can delete their certificates" ON storage.objects
FOR DELETE USING (
    bucket_id = 'clearance-certificates' AND
    auth.uid() IS NOT NULL
);

-- Add comment for documentation
COMMENT ON COLUMN receiving_records.certificate_url IS 'Public URL to the generated clearance certificate image';
COMMENT ON COLUMN receiving_records.certificate_generated_at IS 'Timestamp when certificate was generated and saved';
COMMENT ON COLUMN receiving_records.certificate_file_name IS 'Original filename of the certificate in storage';