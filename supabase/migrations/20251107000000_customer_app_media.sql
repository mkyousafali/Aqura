-- Customer App Media Management System
-- Tables for managing videos and images displayed on customer home page

-- Drop existing objects if they exist (for re-running migration)
DROP TRIGGER IF EXISTS track_media_activation ON customer_app_media;
DROP TRIGGER IF EXISTS update_customer_app_media_timestamp ON customer_app_media;
DROP FUNCTION IF EXISTS track_media_activation();
DROP FUNCTION IF EXISTS update_customer_app_media_timestamp();
DROP FUNCTION IF EXISTS deactivate_expired_media();
DROP FUNCTION IF EXISTS get_active_customer_media();
DROP TABLE IF EXISTS customer_app_media CASCADE;

-- Create storage bucket for customer app media (public access)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'customer-app-media',
    'customer-app-media',
    true,
    52428800, -- 50MB limit
    ARRAY['video/mp4', 'video/webm', 'video/quicktime', 'image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['video/mp4', 'video/webm', 'video/quicktime', 'image/jpeg', 'image/png', 'image/webp'];

-- Drop existing storage policies
DROP POLICY IF EXISTS "Public read access for customer app media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload customer app media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update customer app media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete customer app media" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads to customer-app-media" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated updates to customer-app-media" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes from customer-app-media" ON storage.objects;
DROP POLICY IF EXISTS "Allow public reads from customer-app-media" ON storage.objects;

-- Create storage policy for public read access
CREATE POLICY "Allow public reads from customer-app-media"
ON storage.objects FOR SELECT
USING (bucket_id = 'customer-app-media');

-- Create storage policy for authenticated users to upload
CREATE POLICY "Allow authenticated uploads to customer-app-media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'customer-app-media');

-- Create storage policy for authenticated users to update
CREATE POLICY "Allow authenticated updates to customer-app-media"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'customer-app-media')
WITH CHECK (bucket_id = 'customer-app-media');

-- Create storage policy for authenticated users to delete
CREATE POLICY "Allow authenticated deletes from customer-app-media"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'customer-app-media');

-- Create customer_app_media table
CREATE TABLE customer_app_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Media type and identification
    media_type VARCHAR(10) NOT NULL CHECK (media_type IN ('video', 'image')),
    slot_number INTEGER NOT NULL CHECK (slot_number >= 1 AND slot_number <= 6),
    
    -- Content details
    title_en VARCHAR(255) NOT NULL,
    title_ar VARCHAR(255) NOT NULL,
    description_en TEXT,
    description_ar TEXT,
    
    -- File information
    file_url TEXT NOT NULL,
    file_size BIGINT, -- in bytes
    file_type VARCHAR(50), -- e.g., 'video/mp4', 'image/jpeg'
    duration INTEGER, -- for videos, in seconds
    
    -- Display settings
    is_active BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    
    -- Expiry management
    is_infinite BOOLEAN DEFAULT false,
    expiry_date TIMESTAMPTZ,
    
    -- Metadata
    uploaded_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    activated_at TIMESTAMPTZ,
    deactivated_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT unique_slot_per_type UNIQUE (media_type, slot_number),
    CONSTRAINT expiry_required_unless_infinite CHECK (
        is_infinite = true OR expiry_date IS NOT NULL
    )
);

-- Create indexes for performance
CREATE INDEX idx_customer_app_media_active ON customer_app_media(is_active) WHERE is_active = true;
CREATE INDEX idx_customer_app_media_type ON customer_app_media(media_type);
CREATE INDEX idx_customer_app_media_expiry ON customer_app_media(expiry_date) WHERE expiry_date IS NOT NULL;
CREATE INDEX idx_customer_app_media_display_order ON customer_app_media(display_order);

-- Create function to get active media for customer home page
CREATE OR REPLACE FUNCTION get_active_customer_media()
RETURNS TABLE (
    id UUID,
    media_type VARCHAR(10),
    slot_number INTEGER,
    title_en VARCHAR(255),
    title_ar VARCHAR(255),
    file_url TEXT,
    duration INTEGER,
    display_order INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cam.id,
        cam.media_type,
        cam.slot_number,
        cam.title_en,
        cam.title_ar,
        cam.file_url,
        cam.duration,
        cam.display_order
    FROM customer_app_media cam
    WHERE cam.is_active = true
      AND (
          cam.is_infinite = true 
          OR cam.expiry_date > NOW()
      )
    ORDER BY cam.display_order ASC, cam.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to auto-deactivate expired media
CREATE OR REPLACE FUNCTION deactivate_expired_media()
RETURNS void AS $$
BEGIN
    UPDATE customer_app_media
    SET 
        is_active = false,
        deactivated_at = NOW(),
        updated_at = NOW()
    WHERE 
        is_active = true
        AND is_infinite = false
        AND expiry_date <= NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_customer_app_media_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
CREATE TRIGGER update_customer_app_media_timestamp
    BEFORE UPDATE ON customer_app_media
    FOR EACH ROW
    EXECUTE FUNCTION update_customer_app_media_timestamp();

-- Create trigger to track activation/deactivation
CREATE OR REPLACE FUNCTION track_media_activation()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_active = true AND (OLD.is_active IS NULL OR OLD.is_active = false) THEN
        NEW.activated_at = NOW();
    END IF;
    
    IF NEW.is_active = false AND OLD.is_active = true THEN
        NEW.deactivated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER track_media_activation
    BEFORE UPDATE ON customer_app_media
    FOR EACH ROW
    EXECUTE FUNCTION track_media_activation();

-- Grant permissions
GRANT SELECT ON customer_app_media TO authenticated;
GRANT INSERT, UPDATE, DELETE ON customer_app_media TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_customer_media() TO authenticated;
GRANT EXECUTE ON FUNCTION deactivate_expired_media() TO authenticated;

-- Insert comment for documentation
COMMENT ON TABLE customer_app_media IS 'Stores videos and images displayed on customer home page with expiry management';
COMMENT ON FUNCTION get_active_customer_media() IS 'Returns all active non-expired media for customer home page display';
COMMENT ON FUNCTION deactivate_expired_media() IS 'Automatically deactivates media that has passed its expiry date';
