-- Add URL column to box_operations table for storing POS before closing image URLs
ALTER TABLE box_operations ADD COLUMN pos_before_url TEXT;

-- Add index for faster queries
CREATE INDEX idx_box_operations_pos_before_url ON box_operations(pos_before_url);

-- Add comment for documentation
COMMENT ON COLUMN box_operations.pos_before_url IS 'URL to the stored POS before closing image in pos-before storage bucket';
