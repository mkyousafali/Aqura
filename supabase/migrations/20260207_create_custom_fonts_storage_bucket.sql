-- Create custom-fonts storage bucket for shelf paper font files
-- Supports TTF, OTF, WOFF, WOFF2 font formats

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'custom-fonts',
  'custom-fonts',
  true,
  10485760,  -- 10MB limit
  ARRAY['font/ttf', 'font/otf', 'font/woff', 'font/woff2', 'application/x-font-ttf', 'application/x-font-otf', 'application/font-woff', 'application/font-woff2', 'application/octet-stream']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS policies for custom-fonts bucket
CREATE POLICY "Allow public read access to custom-fonts"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'custom-fonts');

CREATE POLICY "Allow authenticated upload to custom-fonts"
  ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'custom-fonts');

CREATE POLICY "Allow authenticated delete from custom-fonts"
  ON storage.objects
  FOR DELETE
  USING (bucket_id = 'custom-fonts');

CREATE POLICY "Allow anon upload to custom-fonts"
  ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'custom-fonts');

CREATE POLICY "Allow anon delete from custom-fonts"
  ON storage.objects
  FOR DELETE
  USING (bucket_id = 'custom-fonts');
