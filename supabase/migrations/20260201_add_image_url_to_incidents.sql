-- Add image_url column to incidents table for storing uploaded incident images
ALTER TABLE incidents ADD COLUMN image_url TEXT;

-- Add comment to explain the column
COMMENT ON COLUMN incidents.image_url IS 'URL of the uploaded incident image stored in documents bucket';

-- Add index for faster queries if filtering by image presence
CREATE INDEX idx_incidents_image_url ON incidents(image_url) WHERE image_url IS NOT NULL;
