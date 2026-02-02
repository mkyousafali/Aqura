-- Change image_url column to attachments JSONB column for multiple file uploads
-- This migration converts the single image_url TEXT to attachments JSONB array

-- First, add the new attachments column
ALTER TABLE incidents 
ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::JSONB;

-- Migrate existing image_url data to attachments array
UPDATE incidents 
SET attachments = jsonb_build_array(
    jsonb_build_object(
        'url', image_url,
        'name', 'legacy-image',
        'type', 'image',
        'uploaded_at', NOW()
    )
)
WHERE image_url IS NOT NULL;

-- Drop the old image_url column
ALTER TABLE incidents DROP COLUMN IF EXISTS image_url;

-- Drop old index
DROP INDEX IF EXISTS idx_incidents_image_url;

-- Create GIN index for JSONB queries on attachments
CREATE INDEX IF NOT EXISTS idx_incidents_attachments 
ON public.incidents USING GIN (attachments);

-- Add comment to explain the column structure
COMMENT ON COLUMN incidents.attachments IS 'JSONB array of attachments: [{url, name, type, size, uploaded_at}, ...]';
