-- ============================================
-- FLYER TEMPLATE SYSTEM - COMPLETE MIGRATION
-- Created: 2025-11-25
-- Description: Complete flyer template system with storage, RLS, and functions
-- ============================================

-- ============================================
-- 1. CREATE STORAGE BUCKET
-- ============================================

-- Create storage bucket for flyer template images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'flyer-templates',
  'flyer-templates',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 2. CREATE MAIN TABLE: flyer_templates
-- ============================================

CREATE TABLE IF NOT EXISTS flyer_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Template metadata
  name VARCHAR(255) NOT NULL,
  description TEXT,
  
  -- Template images (stored in storage bucket)
  first_page_image_url TEXT NOT NULL,
  sub_page_image_urls TEXT[] NOT NULL DEFAULT '{}',
  
  -- Field configurations (JSONB for flexibility)
  first_page_configuration JSONB NOT NULL DEFAULT '[]',
  sub_page_configurations JSONB NOT NULL DEFAULT '[]',
  
  -- Template dimensions metadata
  metadata JSONB DEFAULT '{"first_page_width": 794, "first_page_height": 1123, "sub_page_width": 794, "sub_page_height": 1123}',
  
  -- Status and categorization
  is_active BOOLEAN DEFAULT true,
  is_default BOOLEAN DEFAULT false,
  category VARCHAR(100),
  tags TEXT[] DEFAULT '{}',
  
  -- Usage tracking
  usage_count INTEGER DEFAULT 0,
  last_used_at TIMESTAMP WITH TIME ZONE,
  
  -- Audit fields
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE,
  
  -- Constraints
  CONSTRAINT flyer_templates_name_unique UNIQUE (name),
  CONSTRAINT flyer_templates_sub_page_images_match_configs CHECK (
    array_length(sub_page_image_urls, 1) = jsonb_array_length(sub_page_configurations)
    OR (sub_page_image_urls = '{}' AND sub_page_configurations = '[]')
  )
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_flyer_templates_is_active ON flyer_templates(is_active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_flyer_templates_is_default ON flyer_templates(is_default) WHERE is_default = true AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_flyer_templates_category ON flyer_templates(category) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_flyer_templates_created_by ON flyer_templates(created_by);
CREATE INDEX IF NOT EXISTS idx_flyer_templates_created_at ON flyer_templates(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_flyer_templates_tags ON flyer_templates USING gin(tags);

-- Add comments for documentation
COMMENT ON TABLE flyer_templates IS 'Stores flyer template designs with product field configurations';
COMMENT ON COLUMN flyer_templates.first_page_image_url IS 'Storage URL for the first page template image';
COMMENT ON COLUMN flyer_templates.sub_page_image_urls IS 'Array of storage URLs for unlimited sub-page template images';
COMMENT ON COLUMN flyer_templates.first_page_configuration IS 'JSONB array of product field configurations for first page';
COMMENT ON COLUMN flyer_templates.sub_page_configurations IS 'JSONB 2D array - each element contains field configurations for a sub-page';
COMMENT ON COLUMN flyer_templates.metadata IS 'Template dimensions and additional metadata';

-- ============================================
-- 3. CREATE TRIGGER: Auto-update updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_flyer_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_flyer_templates_updated_at
  BEFORE UPDATE ON flyer_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_flyer_templates_updated_at();

-- ============================================
-- 4. CREATE TRIGGER: Enforce single default template
-- ============================================

CREATE OR REPLACE FUNCTION ensure_single_default_flyer_template()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_default = true THEN
    -- Unset all other default templates
    UPDATE flyer_templates 
    SET is_default = false 
    WHERE id != NEW.id 
      AND is_default = true 
      AND deleted_at IS NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ensure_single_default_flyer_template
  BEFORE INSERT OR UPDATE OF is_default ON flyer_templates
  FOR EACH ROW
  WHEN (NEW.is_default = true)
  EXECUTE FUNCTION ensure_single_default_flyer_template();

-- ============================================
-- 5. CREATE TRIGGER: Increment usage count
-- ============================================

CREATE OR REPLACE FUNCTION increment_flyer_template_usage()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE flyer_templates
  SET 
    usage_count = usage_count + 1,
    last_used_at = now()
  WHERE id = NEW.template_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This trigger will be created on flyer_instances table when it's created
-- (flyer_instances is the table that uses templates to generate actual flyers)

-- ============================================
-- 6. HELPER FUNCTIONS
-- ============================================

-- Function to get active templates
CREATE OR REPLACE FUNCTION get_active_flyer_templates()
RETURNS TABLE (
  id UUID,
  name VARCHAR,
  description TEXT,
  first_page_image_url TEXT,
  sub_page_image_urls TEXT[],
  first_page_configuration JSONB,
  sub_page_configurations JSONB,
  metadata JSONB,
  is_default BOOLEAN,
  category VARCHAR,
  tags TEXT[],
  usage_count INTEGER,
  last_used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.name,
    t.description,
    t.first_page_image_url,
    t.sub_page_image_urls,
    t.first_page_configuration,
    t.sub_page_configurations,
    t.metadata,
    t.is_default,
    t.category,
    t.tags,
    t.usage_count,
    t.last_used_at,
    t.created_at
  FROM flyer_templates t
  WHERE t.is_active = true 
    AND t.deleted_at IS NULL
  ORDER BY 
    t.is_default DESC,
    t.usage_count DESC,
    t.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get default template
CREATE OR REPLACE FUNCTION get_default_flyer_template()
RETURNS TABLE (
  id UUID,
  name VARCHAR,
  description TEXT,
  first_page_image_url TEXT,
  sub_page_image_urls TEXT[],
  first_page_configuration JSONB,
  sub_page_configurations JSONB,
  metadata JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.name,
    t.description,
    t.first_page_image_url,
    t.sub_page_image_urls,
    t.first_page_configuration,
    t.sub_page_configurations,
    t.metadata
  FROM flyer_templates t
  WHERE t.is_default = true 
    AND t.is_active = true 
    AND t.deleted_at IS NULL
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete template
CREATE OR REPLACE FUNCTION soft_delete_flyer_template(template_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  is_default_template BOOLEAN;
BEGIN
  -- Check if it's the default template
  SELECT is_default INTO is_default_template
  FROM flyer_templates
  WHERE id = template_id;
  
  -- Prevent deletion of default template
  IF is_default_template = true THEN
    RAISE EXCEPTION 'Cannot delete the default template. Please set another template as default first.';
  END IF;
  
  -- Soft delete
  UPDATE flyer_templates
  SET 
    deleted_at = now(),
    is_active = false
  WHERE id = template_id
    AND deleted_at IS NULL;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to duplicate template
CREATE OR REPLACE FUNCTION duplicate_flyer_template(
  template_id UUID,
  new_name VARCHAR,
  user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_template_id UUID;
  template_record RECORD;
BEGIN
  -- Get the original template
  SELECT * INTO template_record
  FROM flyer_templates
  WHERE id = template_id
    AND deleted_at IS NULL;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Template not found';
  END IF;
  
  -- Create duplicate
  INSERT INTO flyer_templates (
    name,
    description,
    first_page_image_url,
    sub_page_image_urls,
    first_page_configuration,
    sub_page_configurations,
    metadata,
    is_active,
    is_default,
    category,
    tags,
    created_by,
    updated_by
  ) VALUES (
    new_name,
    'Copy of: ' || COALESCE(template_record.description, template_record.name),
    template_record.first_page_image_url,
    template_record.sub_page_image_urls,
    template_record.first_page_configuration,
    template_record.sub_page_configurations,
    template_record.metadata,
    true,
    false, -- Duplicates are never default
    template_record.category,
    template_record.tags,
    user_id,
    user_id
  )
  RETURNING id INTO new_template_id;
  
  RETURN new_template_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate template configuration
CREATE OR REPLACE FUNCTION validate_flyer_template_configuration(config JSONB)
RETURNS BOOLEAN AS $$
DECLARE
  field JSONB;
  required_keys TEXT[] := ARRAY['id', 'number', 'x', 'y', 'width', 'height', 'fields'];
BEGIN
  -- Check if config is an array
  IF jsonb_typeof(config) != 'array' THEN
    RAISE EXCEPTION 'Configuration must be a JSON array';
  END IF;
  
  -- Validate each field
  FOR field IN SELECT * FROM jsonb_array_elements(config)
  LOOP
    -- Check required keys exist
    IF NOT (field ?& required_keys) THEN
      RAISE EXCEPTION 'Field missing required keys. Required: %', required_keys;
    END IF;
    
    -- Validate data types
    IF jsonb_typeof(field->'fields') != 'array' THEN
      RAISE EXCEPTION 'Field "fields" must be an array';
    END IF;
    
    -- Validate numeric ranges
    IF (field->>'width')::int <= 0 OR (field->>'height')::int <= 0 THEN
      RAISE EXCEPTION 'Field width and height must be positive';
    END IF;
  END LOOP;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS
ALTER TABLE flyer_templates ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view active templates
CREATE POLICY "Users can view active flyer templates"
  ON flyer_templates
  FOR SELECT
  TO authenticated
  USING (
    is_active = true 
    AND deleted_at IS NULL
  );

-- Policy: Admins can view all templates (including deleted)
CREATE POLICY "Admins can view all flyer templates"
  ON flyer_templates
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role_type IN ('Admin', 'Master Admin')
    )
  );

-- Policy: Admins can insert templates
CREATE POLICY "Admins can insert flyer templates"
  ON flyer_templates
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role_type IN ('Admin', 'Master Admin')
    )
  );

-- Policy: Admins can update templates
CREATE POLICY "Admins can update flyer templates"
  ON flyer_templates
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role_type IN ('Admin', 'Master Admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role_type IN ('Admin', 'Master Admin')
    )
  );

-- Policy: Admins can delete templates
CREATE POLICY "Admins can delete flyer templates"
  ON flyer_templates
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role_type IN ('Admin', 'Master Admin')
    )
  );

-- ============================================
-- 8. STORAGE POLICIES
-- ============================================

-- Policy: Authenticated users can view flyer template images
CREATE POLICY "Authenticated users can view flyer template images"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'flyer-templates');

-- Policy: Public access to flyer template images (for mobile app)
CREATE POLICY "Public can view flyer template images"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'flyer-templates');

-- Policy: Admins can upload flyer template images
CREATE POLICY "Admins can upload flyer template images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'flyer-templates'
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role_type IN ('Admin', 'Master Admin')
    )
  );

-- Policy: Admins can update flyer template images
CREATE POLICY "Admins can update flyer template images"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'flyer-templates'
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role_type IN ('Admin', 'Master Admin')
    )
  );

-- Policy: Admins can delete flyer template images
CREATE POLICY "Admins can delete flyer template images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'flyer-templates'
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role_type IN ('Admin', 'Master Admin')
    )
  );

-- ============================================
-- 9. SAMPLE DATA (Optional - for testing)
-- ============================================

-- Insert a default template (placeholder URLs - replace with actual uploaded images)
INSERT INTO flyer_templates (
  name,
  description,
  first_page_image_url,
  sub_page_image_urls,
  first_page_configuration,
  sub_page_configurations,
  metadata,
  is_default,
  category,
  tags
) VALUES (
  'Default A4 Template',
  'Standard A4 size flyer template with basic product fields',
  'https://placeholder.example.com/first-page.jpg', -- Replace with actual URL
  ARRAY['https://placeholder.example.com/sub-page.jpg'], -- Replace with actual URL
  '[]'::jsonb,
  '[[]]'::jsonb,
  '{"first_page_width": 794, "first_page_height": 1123, "sub_page_width": 794, "sub_page_height": 1123}'::jsonb,
  true,
  'standard',
  ARRAY['a4', 'default', 'basic']
) ON CONFLICT (name) DO NOTHING;

-- ============================================
-- 10. GRANT PERMISSIONS
-- ============================================

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_active_flyer_templates() TO authenticated;
GRANT EXECUTE ON FUNCTION get_default_flyer_template() TO authenticated;
GRANT EXECUTE ON FUNCTION soft_delete_flyer_template(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION duplicate_flyer_template(UUID, VARCHAR, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_flyer_template_configuration(JSONB) TO authenticated;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================

-- Verify migration
DO $$
BEGIN
  RAISE NOTICE '✅ Flyer template system migration completed successfully';
  RAISE NOTICE '📋 Table created: flyer_templates';
  RAISE NOTICE '🗄️ Storage bucket created: flyer-templates';
  RAISE NOTICE '🔒 RLS policies enabled';
  RAISE NOTICE '⚡ Helper functions created';
  RAISE NOTICE '🎯 Ready for template management';
END $$;
