-- Create task_images table for managing image attachments for tasks
-- This table stores metadata and references for images attached to tasks

-- Create the task_images table
CREATE TABLE IF NOT EXISTS public.task_images (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL,
    file_name TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    file_type TEXT NOT NULL,
    file_url TEXT NOT NULL,
    image_type TEXT NOT NULL,
    uploaded_by TEXT NOT NULL,
    uploaded_by_name TEXT NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    image_width INTEGER NULL,
    image_height INTEGER NULL,
    file_path TEXT NULL,
    attachment_type TEXT NULL DEFAULT 'task_creation'::text,
    
    CONSTRAINT task_images_pkey PRIMARY KEY (id),
    CONSTRAINT task_images_task_id_fkey 
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT task_images_attachment_type_check 
        CHECK (attachment_type = ANY (ARRAY['task_creation'::text, 'task_completion'::text]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_task_images_task_id 
ON public.task_images USING btree (task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_uploaded_by 
ON public.task_images USING btree (uploaded_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_image_type 
ON public.task_images USING btree (image_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_attachment_type 
ON public.task_images USING btree (attachment_type) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_task_images_file_type 
ON public.task_images (file_type);

CREATE INDEX IF NOT EXISTS idx_task_images_created_at 
ON public.task_images (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_images_file_size 
ON public.task_images (file_size);

CREATE INDEX IF NOT EXISTS idx_task_images_file_name 
ON public.task_images (file_name);

CREATE INDEX IF NOT EXISTS idx_task_images_file_url 
ON public.task_images (file_url);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_task_images_task_type 
ON public.task_images (task_id, attachment_type);

CREATE INDEX IF NOT EXISTS idx_task_images_uploaded_by_date 
ON public.task_images (uploaded_by, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_images_type_date 
ON public.task_images (image_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_images_dimensions 
ON public.task_images (image_width, image_height);

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_task_images_creation_images 
ON public.task_images (created_at DESC) 
WHERE attachment_type = 'task_creation';

CREATE INDEX IF NOT EXISTS idx_task_images_completion_images 
ON public.task_images (created_at DESC) 
WHERE attachment_type = 'task_completion';

CREATE INDEX IF NOT EXISTS idx_task_images_large_files 
ON public.task_images (file_size DESC) 
WHERE file_size > 1048576; -- Files larger than 1MB

CREATE INDEX IF NOT EXISTS idx_task_images_with_dimensions 
ON public.task_images (image_width, image_height) 
WHERE image_width IS NOT NULL AND image_height IS NOT NULL;

-- Create text search index for file names
CREATE INDEX IF NOT EXISTS idx_task_images_file_name_search 
ON public.task_images USING gin (to_tsvector('english', file_name));

-- Add updated_at column and trigger
ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_task_images_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_task_images_updated_at 
BEFORE UPDATE ON task_images 
FOR EACH ROW 
EXECUTE FUNCTION update_task_images_updated_at();

-- Add additional validation constraints
ALTER TABLE public.task_images 
ADD CONSTRAINT chk_file_name_not_empty 
CHECK (TRIM(file_name) != '');

ALTER TABLE public.task_images 
ADD CONSTRAINT chk_file_url_not_empty 
CHECK (TRIM(file_url) != '');

ALTER TABLE public.task_images 
ADD CONSTRAINT chk_file_size_positive 
CHECK (file_size > 0);

ALTER TABLE public.task_images 
ADD CONSTRAINT chk_file_size_reasonable 
CHECK (file_size <= 104857600); -- Max 100MB

ALTER TABLE public.task_images 
ADD CONSTRAINT chk_image_dimensions_positive 
CHECK ((image_width IS NULL OR image_width > 0) AND (image_height IS NULL OR image_height > 0));

ALTER TABLE public.task_images 
ADD CONSTRAINT chk_image_dimensions_reasonable 
CHECK ((image_width IS NULL OR image_width <= 20000) AND (image_height IS NULL OR image_height <= 20000));

-- Add additional columns for enhanced functionality
ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS alt_text TEXT;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS description TEXT;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS location_coordinates POINT;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS location_address TEXT;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS camera_info JSONB DEFAULT '{}';

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS exif_data JSONB DEFAULT '{}';

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS processing_status VARCHAR(50) DEFAULT 'completed';

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS file_hash VARCHAR(64);

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS deleted_by TEXT;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS storage_bucket VARCHAR(100) DEFAULT 'task-images';

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS compression_quality INTEGER;

ALTER TABLE public.task_images 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

-- Add validation for new columns
ALTER TABLE public.task_images 
ADD CONSTRAINT chk_sort_order_non_negative 
CHECK (sort_order >= 0);

ALTER TABLE public.task_images 
ADD CONSTRAINT chk_processing_status_valid 
CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed'));

ALTER TABLE public.task_images 
ADD CONSTRAINT chk_compression_quality_valid 
CHECK (compression_quality IS NULL OR (compression_quality >= 1 AND compression_quality <= 100));

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_task_images_thumbnail_url 
ON public.task_images (thumbnail_url);

CREATE INDEX IF NOT EXISTS idx_task_images_is_primary 
ON public.task_images (is_primary) 
WHERE is_primary = true;

CREATE INDEX IF NOT EXISTS idx_task_images_sort_order 
ON public.task_images (task_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_task_images_location 
ON public.task_images USING gist (location_coordinates);

CREATE INDEX IF NOT EXISTS idx_task_images_processing_status 
ON public.task_images (processing_status);

CREATE INDEX IF NOT EXISTS idx_task_images_file_hash 
ON public.task_images (file_hash);

CREATE INDEX IF NOT EXISTS idx_task_images_deleted 
ON public.task_images (is_deleted, deleted_at);

CREATE INDEX IF NOT EXISTS idx_task_images_storage_bucket 
ON public.task_images (storage_bucket);

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_task_images_camera_info 
ON public.task_images USING gin (camera_info);

CREATE INDEX IF NOT EXISTS idx_task_images_exif_data 
ON public.task_images USING gin (exif_data);

CREATE INDEX IF NOT EXISTS idx_task_images_metadata 
ON public.task_images USING gin (metadata);

-- Create unique constraint for file hash to prevent duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_task_images_hash_unique 
ON public.task_images (file_hash) 
WHERE file_hash IS NOT NULL AND is_deleted = false;

-- Add table and column comments
COMMENT ON TABLE public.task_images IS 'Image attachments for tasks with comprehensive metadata and processing capabilities';
COMMENT ON COLUMN public.task_images.id IS 'Unique identifier for the image record';
COMMENT ON COLUMN public.task_images.task_id IS 'Reference to the task';
COMMENT ON COLUMN public.task_images.file_name IS 'Original filename of the image';
COMMENT ON COLUMN public.task_images.file_size IS 'Size of the image file in bytes';
COMMENT ON COLUMN public.task_images.file_type IS 'MIME type of the image file';
COMMENT ON COLUMN public.task_images.file_url IS 'URL to access the image';
COMMENT ON COLUMN public.task_images.image_type IS 'Type/category of the image';
COMMENT ON COLUMN public.task_images.uploaded_by IS 'User who uploaded the image';
COMMENT ON COLUMN public.task_images.uploaded_by_name IS 'Name of the user who uploaded the image';
COMMENT ON COLUMN public.task_images.image_width IS 'Width of the image in pixels';
COMMENT ON COLUMN public.task_images.image_height IS 'Height of the image in pixels';
COMMENT ON COLUMN public.task_images.file_path IS 'Storage path of the image file';
COMMENT ON COLUMN public.task_images.attachment_type IS 'When the image was attached (creation/completion)';
COMMENT ON COLUMN public.task_images.thumbnail_url IS 'URL to the thumbnail version';
COMMENT ON COLUMN public.task_images.alt_text IS 'Alternative text for accessibility';
COMMENT ON COLUMN public.task_images.description IS 'Description of the image content';
COMMENT ON COLUMN public.task_images.is_primary IS 'Whether this is the primary image for the task';
COMMENT ON COLUMN public.task_images.sort_order IS 'Display order of the image';
COMMENT ON COLUMN public.task_images.location_coordinates IS 'GPS coordinates where image was taken';
COMMENT ON COLUMN public.task_images.location_address IS 'Address where image was taken';
COMMENT ON COLUMN public.task_images.camera_info IS 'Camera/device information as JSON';
COMMENT ON COLUMN public.task_images.exif_data IS 'EXIF metadata from the image';
COMMENT ON COLUMN public.task_images.processing_status IS 'Current processing status of the image';
COMMENT ON COLUMN public.task_images.file_hash IS 'Hash of the file content for deduplication';
COMMENT ON COLUMN public.task_images.is_deleted IS 'Soft delete flag';
COMMENT ON COLUMN public.task_images.deleted_at IS 'When the image was soft deleted';
COMMENT ON COLUMN public.task_images.deleted_by IS 'User who deleted the image';
COMMENT ON COLUMN public.task_images.storage_bucket IS 'Storage bucket name';
COMMENT ON COLUMN public.task_images.compression_quality IS 'Compression quality used (1-100)';
COMMENT ON COLUMN public.task_images.metadata IS 'Additional metadata as JSON';
COMMENT ON COLUMN public.task_images.created_at IS 'When the image was uploaded';
COMMENT ON COLUMN public.task_images.updated_at IS 'When the image record was last updated';

-- Create view for active images with task details
CREATE OR REPLACE VIEW task_images_active AS
SELECT 
    ti.id,
    ti.task_id,
    t.name as task_name,
    t.description as task_description,
    ti.file_name,
    ti.file_size,
    ti.file_type,
    ti.file_url,
    ti.thumbnail_url,
    ti.image_type,
    ti.uploaded_by,
    ti.uploaded_by_name,
    ti.image_width,
    ti.image_height,
    ti.file_path,
    ti.attachment_type,
    ti.alt_text,
    ti.description,
    ti.is_primary,
    ti.sort_order,
    ti.location_coordinates,
    ti.location_address,
    ti.camera_info,
    ti.exif_data,
    ti.processing_status,
    ti.file_hash,
    ti.storage_bucket,
    ti.compression_quality,
    ti.metadata,
    ti.created_at,
    ti.updated_at,
    ROUND(ti.file_size / 1024.0, 2) as file_size_kb,
    ROUND(ti.file_size / 1048576.0, 2) as file_size_mb,
    CASE 
        WHEN ti.image_width IS NOT NULL AND ti.image_height IS NOT NULL 
        THEN ti.image_width * ti.image_height
        ELSE NULL
    END as total_pixels
FROM task_images ti
LEFT JOIN tasks t ON ti.task_id = t.id
WHERE ti.is_deleted = false
ORDER BY ti.task_id, ti.sort_order, ti.created_at;

-- Create function to upload a task image
CREATE OR REPLACE FUNCTION upload_task_image(
    task_id_param UUID,
    file_name_param TEXT,
    file_size_param BIGINT,
    file_type_param TEXT,
    file_url_param TEXT,
    image_type_param TEXT,
    uploaded_by_param TEXT,
    uploaded_by_name_param TEXT DEFAULT NULL,
    attachment_type_param TEXT DEFAULT 'task_creation',
    image_width_param INTEGER DEFAULT NULL,
    image_height_param INTEGER DEFAULT NULL,
    file_path_param TEXT DEFAULT NULL,
    thumbnail_url_param TEXT DEFAULT NULL,
    alt_text_param TEXT DEFAULT NULL,
    description_param TEXT DEFAULT NULL,
    is_primary_param BOOLEAN DEFAULT false,
    location_coords POINT DEFAULT NULL,
    location_addr TEXT DEFAULT NULL,
    camera_info_param JSONB DEFAULT '{}',
    exif_data_param JSONB DEFAULT '{}',
    file_hash_param VARCHAR DEFAULT NULL,
    storage_bucket_param VARCHAR DEFAULT 'task-images',
    compression_quality_param INTEGER DEFAULT NULL,
    metadata_param JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    image_id UUID;
    max_sort_order INTEGER;
BEGIN
    -- Get the next sort order for this task
    SELECT COALESCE(MAX(sort_order), -1) + 1 INTO max_sort_order
    FROM task_images 
    WHERE task_id = task_id_param AND is_deleted = false;
    
    -- If this is set as primary, unset other primary images for this task
    IF is_primary_param THEN
        UPDATE task_images 
        SET is_primary = false,
            updated_at = now()
        WHERE task_id = task_id_param AND is_deleted = false;
    END IF;
    
    INSERT INTO task_images (
        task_id,
        file_name,
        file_size,
        file_type,
        file_url,
        image_type,
        uploaded_by,
        uploaded_by_name,
        attachment_type,
        image_width,
        image_height,
        file_path,
        thumbnail_url,
        alt_text,
        description,
        is_primary,
        sort_order,
        location_coordinates,
        location_address,
        camera_info,
        exif_data,
        file_hash,
        storage_bucket,
        compression_quality,
        metadata
    ) VALUES (
        task_id_param,
        file_name_param,
        file_size_param,
        file_type_param,
        file_url_param,
        image_type_param,
        uploaded_by_param,
        uploaded_by_name_param,
        attachment_type_param,
        image_width_param,
        image_height_param,
        file_path_param,
        thumbnail_url_param,
        alt_text_param,
        description_param,
        is_primary_param,
        max_sort_order,
        location_coords,
        location_addr,
        camera_info_param,
        exif_data_param,
        file_hash_param,
        storage_bucket_param,
        compression_quality_param,
        metadata_param
    ) RETURNING id INTO image_id;
    
    RETURN image_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to soft delete an image
CREATE OR REPLACE FUNCTION delete_task_image(
    image_id UUID,
    deleted_by_param TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE task_images 
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = deleted_by_param,
        updated_at = now()
    WHERE id = image_id AND is_deleted = false;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to set primary image
CREATE OR REPLACE FUNCTION set_primary_image(
    image_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    task_id_var UUID;
BEGIN
    -- Get task_id for the image
    SELECT task_id INTO task_id_var 
    FROM task_images 
    WHERE id = image_id AND is_deleted = false;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    -- Unset all primary images for this task
    UPDATE task_images 
    SET is_primary = false,
        updated_at = now()
    WHERE task_id = task_id_var AND is_deleted = false;
    
    -- Set this image as primary
    UPDATE task_images 
    SET is_primary = true,
        updated_at = now()
    WHERE id = image_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to reorder images
CREATE OR REPLACE FUNCTION reorder_task_images(
    task_id_param UUID,
    image_order UUID[]
)
RETURNS BOOLEAN AS $$
DECLARE
    i INTEGER;
BEGIN
    -- Update sort order based on array position
    FOR i IN 1..array_length(image_order, 1) LOOP
        UPDATE task_images 
        SET sort_order = i - 1,
            updated_at = now()
        WHERE id = image_order[i] 
          AND task_id = task_id_param 
          AND is_deleted = false;
    END LOOP;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Create function to get task image statistics
CREATE OR REPLACE FUNCTION get_task_image_statistics(task_id_param UUID)
RETURNS TABLE(
    total_images BIGINT,
    creation_images BIGINT,
    completion_images BIGINT,
    total_size BIGINT,
    avg_image_size BIGINT,
    max_image_size BIGINT,
    primary_image_id UUID,
    latest_upload_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_images,
        COUNT(*) FILTER (WHERE attachment_type = 'task_creation') as creation_images,
        COUNT(*) FILTER (WHERE attachment_type = 'task_completion') as completion_images,
        COALESCE(SUM(file_size), 0) as total_size,
        COALESCE(AVG(file_size)::BIGINT, 0) as avg_image_size,
        COALESCE(MAX(file_size), 0) as max_image_size,
        (SELECT id FROM task_images WHERE task_id = task_id_param AND is_primary = true AND is_deleted = false LIMIT 1) as primary_image_id,
        MAX(created_at) as latest_upload_at
    FROM task_images
    WHERE task_id = task_id_param AND is_deleted = false;
END;
$$ LANGUAGE plpgsql;

-- Create function to get duplicate images
CREATE OR REPLACE FUNCTION get_duplicate_images()
RETURNS TABLE(
    file_hash VARCHAR,
    image_count BIGINT,
    total_size BIGINT,
    image_ids UUID[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ti.file_hash,
        COUNT(*) as image_count,
        SUM(ti.file_size) as total_size,
        ARRAY_AGG(ti.id) as image_ids
    FROM task_images ti
    WHERE ti.file_hash IS NOT NULL 
      AND ti.is_deleted = false
    GROUP BY ti.file_hash
    HAVING COUNT(*) > 1
    ORDER BY COUNT(*) DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get images by type
CREATE OR REPLACE FUNCTION get_images_by_type(
    task_id_param UUID DEFAULT NULL,
    image_type_param TEXT DEFAULT NULL,
    attachment_type_param TEXT DEFAULT NULL,
    include_deleted BOOLEAN DEFAULT false
)
RETURNS TABLE(
    image_id UUID,
    file_name TEXT,
    file_url TEXT,
    thumbnail_url TEXT,
    file_size BIGINT,
    image_width INTEGER,
    image_height INTEGER,
    is_primary BOOLEAN,
    uploaded_by TEXT,
    uploaded_by_name TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ti.id,
        ti.file_name,
        ti.file_url,
        ti.thumbnail_url,
        ti.file_size,
        ti.image_width,
        ti.image_height,
        ti.is_primary,
        ti.uploaded_by,
        ti.uploaded_by_name,
        ti.created_at
    FROM task_images ti
    WHERE (task_id_param IS NULL OR ti.task_id = task_id_param)
      AND (image_type_param IS NULL OR ti.image_type = image_type_param)
      AND (attachment_type_param IS NULL OR ti.attachment_type = attachment_type_param)
      AND (include_deleted = true OR ti.is_deleted = false)
    ORDER BY ti.sort_order, ti.created_at;
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup orphaned images
CREATE OR REPLACE FUNCTION cleanup_orphaned_images()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    UPDATE task_images 
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = 'system_cleanup'
    WHERE task_id NOT IN (SELECT id FROM tasks)
      AND is_deleted = false;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'task_images table created with comprehensive image management and processing features';