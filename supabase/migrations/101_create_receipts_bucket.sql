-- Create storage bucket for purchase voucher receipts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'purchase-voucher-receipts',
  'purchase-voucher-receipts',
  true,
  5242880, -- 5MB limit
  ARRAY['image/png', 'image/jpeg']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload receipts
CREATE POLICY "Authenticated users can upload receipts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'purchase-voucher-receipts');

-- Allow authenticated users to read receipts
CREATE POLICY "Authenticated users can read receipts"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'purchase-voucher-receipts');

-- Allow public read access for receipts
CREATE POLICY "Public can view receipts"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'purchase-voucher-receipts');

-- Add receipt_url column to purchase_voucher_items if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchase_voucher_items' 
        AND column_name = 'receipt_url'
    ) THEN
        ALTER TABLE purchase_voucher_items ADD COLUMN receipt_url TEXT;
    END IF;
END $$;
