-- Create storage bucket for expense scheduler bills
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'expense-scheduler-bills',
  'expense-scheduler-bills',
  false,
  52428800, -- 50MB limit
  ARRAY[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for expense-scheduler-bills bucket

-- Policy: Allow authenticated users to upload bills
CREATE POLICY "Allow authenticated users to upload bills"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'expense-scheduler-bills'
);

-- Policy: Allow authenticated users to read bills
CREATE POLICY "Allow authenticated users to read bills"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'expense-scheduler-bills'
);

-- Policy: Allow authenticated users to update their own bills
CREATE POLICY "Allow authenticated users to update bills"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'expense-scheduler-bills'
)
WITH CHECK (
  bucket_id = 'expense-scheduler-bills'
);

-- Policy: Allow authenticated users to delete bills
CREATE POLICY "Allow authenticated users to delete bills"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'expense-scheduler-bills'
);

-- Policy: Service role has full access
CREATE POLICY "Service role has full access to expense scheduler bills"
ON storage.objects
FOR ALL
TO service_role
USING (
  bucket_id = 'expense-scheduler-bills'
)
WITH CHECK (
  bucket_id = 'expense-scheduler-bills'
);
