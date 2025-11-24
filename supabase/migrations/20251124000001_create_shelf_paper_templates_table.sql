-- Create storage bucket for shelf paper template images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'shelf-paper-templates',
  'shelf-paper-templates',
  true,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for shelf-paper-templates bucket
DROP POLICY IF EXISTS "Allow public read access to template images" ON storage.objects;
CREATE POLICY "Allow public read access to template images"
ON storage.objects FOR SELECT
USING (bucket_id = 'shelf-paper-templates');

DROP POLICY IF EXISTS "Allow authenticated users to upload template images" ON storage.objects;
CREATE POLICY "Allow authenticated users to upload template images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'shelf-paper-templates' 
  AND auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Allow users to update their own template images" ON storage.objects;
CREATE POLICY "Allow users to update their own template images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'shelf-paper-templates'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Allow users to delete their own template images" ON storage.objects;
CREATE POLICY "Allow users to delete their own template images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'shelf-paper-templates'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Create shelf_paper_templates table for storing template designs
CREATE TABLE IF NOT EXISTS shelf_paper_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  template_image_url TEXT NOT NULL,
  field_configuration JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active BOOLEAN NOT NULL DEFAULT true
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_shelf_paper_templates_created_by ON shelf_paper_templates(created_by);
CREATE INDEX IF NOT EXISTS idx_shelf_paper_templates_is_active ON shelf_paper_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_shelf_paper_templates_created_at ON shelf_paper_templates(created_at DESC);

-- Add updated_at trigger
DROP TRIGGER IF EXISTS update_shelf_paper_templates_updated_at ON shelf_paper_templates;
CREATE TRIGGER update_shelf_paper_templates_updated_at
  BEFORE UPDATE ON shelf_paper_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Add RLS policies
ALTER TABLE shelf_paper_templates ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read all active templates
DROP POLICY IF EXISTS "Users can view active templates" ON shelf_paper_templates;
CREATE POLICY "Users can view active templates"
  ON shelf_paper_templates
  FOR SELECT
  USING (is_active = true);

-- Allow authenticated users to create templates
DROP POLICY IF EXISTS "Users can create templates" ON shelf_paper_templates;
CREATE POLICY "Users can create templates"
  ON shelf_paper_templates
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Allow users to update their own templates
DROP POLICY IF EXISTS "Users can update own templates" ON shelf_paper_templates;
CREATE POLICY "Users can update own templates"
  ON shelf_paper_templates
  FOR UPDATE
  USING (created_by = auth.uid());

-- Allow users to delete their own templates
DROP POLICY IF EXISTS "Users can delete own templates" ON shelf_paper_templates;
CREATE POLICY "Users can delete own templates"
  ON shelf_paper_templates
  FOR DELETE
  USING (created_by = auth.uid());

-- Add comment
COMMENT ON TABLE shelf_paper_templates IS 'Stores shelf paper template designs with field configurations';
