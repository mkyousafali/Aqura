-- =====================================================
-- Table: task_images
-- Description: Task image management and storage system
-- This table manages image uploads associated with tasks including metadata and organization
-- =====================================================

-- Create enum types for task images
CREATE TYPE public.task_image_type_enum AS ENUM (
    'before',
    'during',
    'after',
    'evidence',
    'reference',
    'instruction',
    'completion_proof',
    'quality_check',
    'documentation',
    'other'
);

CREATE TYPE public.image_file_type_enum AS ENUM (
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/tiff',
    'image/svg+xml'
);

-- Create task_images table
CREATE TABLE public.task_images (
    -- Primary key with UUID generation
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Foreign key to tasks table
    task_id UUID NOT NULL,
    
    -- File metadata
    file_name TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    file_type TEXT NOT NULL,
    file_url TEXT NOT NULL,
    
    -- Image classification and metadata
    image_type TEXT NOT NULL,
    uploaded_by TEXT NOT NULL,
    uploaded_by_name TEXT NULL,
    
    -- Image dimensions
    image_width INTEGER NULL,
    image_height INTEGER NULL,
    
    -- Audit timestamp
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    -- Primary key constraint
    CONSTRAINT task_images_pkey PRIMARY KEY (id),
    
    -- Foreign key to tasks table with CASCADE delete
    CONSTRAINT task_images_task_id_fkey 
        FOREIGN KEY (task_id) 
        REFERENCES tasks (id) 
        ON DELETE CASCADE,
    
    -- Check constraints for data integrity
    CONSTRAINT chk_file_size_positive 
        CHECK (file_size > 0),
    
    -- Check constraint for valid image dimensions
    CONSTRAINT chk_image_dimensions_positive 
        CHECK (
            (image_width IS NULL OR image_width > 0) AND
            (image_height IS NULL OR image_height > 0)
        ),
    
    -- Check constraint for valid file types
    CONSTRAINT chk_file_type_valid 
        CHECK (file_type IN (
            'image/jpeg', 'image/png', 'image/gif', 'image/webp', 
            'image/bmp', 'image/tiff', 'image/svg+xml'
        )),
    
    -- Check constraint for valid image types
    CONSTRAINT chk_image_type_valid 
        CHECK (image_type IN (
            'before', 'during', 'after', 'evidence', 'reference', 
            'instruction', 'completion_proof', 'quality_check', 
            'documentation', 'other'
        )),
    
    -- Check constraint for file URL format
    CONSTRAINT chk_file_url_format 
        CHECK (file_url ~ '^https?://'),
    
    -- Check constraint for reasonable file size (max 50MB)
    CONSTRAINT chk_file_size_reasonable 
        CHECK (file_size <= 52428800)
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Primary lookup indexes
CREATE INDEX IF NOT EXISTS idx_task_images_task_id 
    ON public.task_images 
    USING btree (task_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_uploaded_by 
    ON public.task_images 
    USING btree (uploaded_by) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_image_type 
    ON public.task_images 
    USING btree (image_type) 
    TABLESPACE pg_default;

-- File metadata indexes
CREATE INDEX IF NOT EXISTS idx_task_images_file_type 
    ON public.task_images 
    USING btree (file_type) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_file_size 
    ON public.task_images 
    USING btree (file_size DESC) 
    TABLESPACE pg_default;

-- Temporal indexes
CREATE INDEX IF NOT EXISTS idx_task_images_created_at 
    ON public.task_images 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_task_images_task_type 
    ON public.task_images 
    USING btree (task_id, image_type, created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_user_timeline 
    ON public.task_images 
    USING btree (uploaded_by, created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_type_timeline 
    ON public.task_images 
    USING btree (image_type, created_at DESC) 
    TABLESPACE pg_default;

-- Image dimensions index for filtering
CREATE INDEX IF NOT EXISTS idx_task_images_dimensions 
    ON public.task_images 
    USING btree (image_width, image_height) 
    TABLESPACE pg_default
    WHERE image_width IS NOT NULL AND image_height IS NOT NULL;

-- File name search index (for partial matching)
CREATE INDEX IF NOT EXISTS idx_task_images_file_name_search 
    ON public.task_images 
    USING gin (to_tsvector('english', file_name)) 
    TABLESPACE pg_default;

-- Large files index for storage management
CREATE INDEX IF NOT EXISTS idx_task_images_large_files 
    ON public.task_images 
    USING btree (file_size DESC, created_at DESC) 
    TABLESPACE pg_default
    WHERE file_size > 10485760; -- Files larger than 10MB

-- =====================================================
-- Functions for Image Management
-- =====================================================

-- Function to upload task image
CREATE OR REPLACE FUNCTION upload_task_image(
    p_task_id UUID,
    p_file_name TEXT,
    p_file_size BIGINT,
    p_file_type TEXT,
    p_file_url TEXT,
    p_image_type TEXT,
    p_uploaded_by TEXT,
    p_uploaded_by_name TEXT DEFAULT NULL,
    p_image_width INTEGER DEFAULT NULL,
    p_image_height INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    image_id UUID;
BEGIN
    INSERT INTO public.task_images (
        task_id, file_name, file_size, file_type, file_url, 
        image_type, uploaded_by, uploaded_by_name, 
        image_width, image_height
    ) VALUES (
        p_task_id, p_file_name, p_file_size, p_file_type, p_file_url,
        p_image_type, p_uploaded_by, p_uploaded_by_name,
        p_image_width, p_image_height
    )
    RETURNING id INTO image_id;
    
    RETURN image_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get task images by type
CREATE OR REPLACE FUNCTION get_task_images_by_type(
    p_task_id UUID,
    p_image_type TEXT DEFAULT NULL
)
RETURNS TABLE (
    image_id UUID,
    file_name TEXT,
    file_size BIGINT,
    file_type TEXT,
    file_url TEXT,
    image_type TEXT,
    uploaded_by TEXT,
    uploaded_by_name TEXT,
    image_width INTEGER,
    image_height INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ti.id as image_id,
        ti.file_name,
        ti.file_size,
        ti.file_type,
        ti.file_url,
        ti.image_type,
        ti.uploaded_by,
        ti.uploaded_by_name,
        ti.image_width,
        ti.image_height,
        ti.created_at
    FROM public.task_images ti
    WHERE ti.task_id = p_task_id
      AND (p_image_type IS NULL OR ti.image_type = p_image_type)
    ORDER BY ti.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get image statistics for a task
CREATE OR REPLACE FUNCTION get_task_image_stats(p_task_id UUID)
RETURNS TABLE (
    total_images INTEGER,
    total_file_size BIGINT,
    avg_file_size BIGINT,
    image_types JSONB,
    earliest_upload TIMESTAMP WITH TIME ZONE,
    latest_upload TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_images,
        SUM(ti.file_size) as total_file_size,
        AVG(ti.file_size)::BIGINT as avg_file_size,
        jsonb_object_agg(ti.image_type, type_count) as image_types,
        MIN(ti.created_at) as earliest_upload,
        MAX(ti.created_at) as latest_upload
    FROM public.task_images ti
    LEFT JOIN (
        SELECT image_type, COUNT(*) as type_count
        FROM public.task_images
        WHERE task_id = p_task_id
        GROUP BY image_type
    ) type_counts ON ti.image_type = type_counts.image_type
    WHERE ti.task_id = p_task_id;
END;
$$ LANGUAGE plpgsql;

-- Function to delete task image
CREATE OR REPLACE FUNCTION delete_task_image(p_image_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    DELETE FROM public.task_images 
    WHERE id = p_image_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to update image metadata
CREATE OR REPLACE FUNCTION update_image_metadata(
    p_image_id UUID,
    p_image_width INTEGER DEFAULT NULL,
    p_image_height INTEGER DEFAULT NULL,
    p_image_type TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.task_images 
    SET image_width = COALESCE(p_image_width, image_width),
        image_height = COALESCE(p_image_height, image_height),
        image_type = COALESCE(p_image_type, image_type)
    WHERE id = p_image_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to get user upload statistics
CREATE OR REPLACE FUNCTION get_user_upload_stats(
    p_user_id TEXT,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
    total_uploads INTEGER,
    total_file_size BIGINT,
    avg_file_size BIGINT,
    most_common_type TEXT,
    uploads_by_type JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_uploads,
        SUM(ti.file_size) as total_file_size,
        AVG(ti.file_size)::BIGINT as avg_file_size,
        MODE() WITHIN GROUP (ORDER BY ti.image_type) as most_common_type,
        jsonb_object_agg(ti.image_type, type_count) as uploads_by_type
    FROM public.task_images ti
    LEFT JOIN (
        SELECT image_type, COUNT(*) as type_count
        FROM public.task_images
        WHERE uploaded_by = p_user_id
          AND (p_start_date IS NULL OR created_at >= p_start_date)
          AND (p_end_date IS NULL OR created_at <= p_end_date)
        GROUP BY image_type
    ) type_counts ON ti.image_type = type_counts.image_type
    WHERE ti.uploaded_by = p_user_id
      AND (p_start_date IS NULL OR ti.created_at >= p_start_date)
      AND (p_end_date IS NULL OR ti.created_at <= p_end_date);
END;
$$ LANGUAGE plpgsql;

-- Function to clean up orphaned images (for maintenance)
CREATE OR REPLACE FUNCTION cleanup_orphaned_images()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.task_images 
    WHERE task_id NOT IN (SELECT id FROM public.tasks);
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Views for Common Image Queries
-- =====================================================

-- View for task image gallery with metadata
CREATE OR REPLACE VIEW task_image_gallery AS
SELECT 
    ti.id as image_id,
    ti.task_id,
    t.title as task_title,
    ti.file_name,
    ti.file_size,
    ti.file_type,
    ti.file_url,
    ti.image_type,
    ti.uploaded_by,
    ti.uploaded_by_name,
    ti.image_width,
    ti.image_height,
    ti.created_at,
    CASE 
        WHEN ti.image_width IS NOT NULL AND ti.image_height IS NOT NULL 
        THEN ROUND(ti.image_width::DECIMAL / ti.image_height::DECIMAL, 2)
        ELSE NULL 
    END as aspect_ratio,
    pg_size_pretty(ti.file_size) as file_size_human
FROM public.task_images ti
JOIN public.tasks t ON ti.task_id = t.id
ORDER BY ti.created_at DESC;

-- View for image storage summary
CREATE OR REPLACE VIEW image_storage_summary AS
SELECT 
    image_type,
    COUNT(*) as image_count,
    SUM(file_size) as total_size,
    AVG(file_size)::BIGINT as avg_size,
    MIN(file_size) as min_size,
    MAX(file_size) as max_size,
    pg_size_pretty(SUM(file_size)) as total_size_human,
    pg_size_pretty(AVG(file_size)::BIGINT) as avg_size_human
FROM public.task_images
GROUP BY image_type
ORDER BY total_size DESC;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.task_images IS 'Task image management and storage system with metadata tracking and organization';

COMMENT ON COLUMN public.task_images.id IS 'Primary key - unique identifier for each task image';
COMMENT ON COLUMN public.task_images.task_id IS 'Foreign key to tasks table - which task this image belongs to';
COMMENT ON COLUMN public.task_images.file_name IS 'Original filename of the uploaded image';
COMMENT ON COLUMN public.task_images.file_size IS 'File size in bytes';
COMMENT ON COLUMN public.task_images.file_type IS 'MIME type of the image file (image/jpeg, image/png, etc.)';
COMMENT ON COLUMN public.task_images.file_url IS 'Full URL to access the uploaded image';
COMMENT ON COLUMN public.task_images.image_type IS 'Classification of image purpose (before, during, after, evidence, etc.)';
COMMENT ON COLUMN public.task_images.uploaded_by IS 'User ID of the person who uploaded the image';
COMMENT ON COLUMN public.task_images.uploaded_by_name IS 'Display name of the person who uploaded the image';
COMMENT ON COLUMN public.task_images.image_width IS 'Image width in pixels';
COMMENT ON COLUMN public.task_images.image_height IS 'Image height in pixels';
COMMENT ON COLUMN public.task_images.created_at IS 'Timestamp when the image was uploaded';

-- Index comments
COMMENT ON INDEX idx_task_images_task_id IS 'Performance index for task-based image queries';
COMMENT ON INDEX idx_task_images_task_type IS 'Composite index for task-type-timeline queries';
COMMENT ON INDEX idx_task_images_file_name_search IS 'Full-text search index for image filename searches';
COMMENT ON INDEX idx_task_images_large_files IS 'Partial index for storage management of large files';

-- Function comments
COMMENT ON FUNCTION upload_task_image(UUID, TEXT, BIGINT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER) IS 'Uploads a new task image with complete metadata';
COMMENT ON FUNCTION get_task_images_by_type(UUID, TEXT) IS 'Retrieves task images filtered by type with optional type filtering';
COMMENT ON FUNCTION get_task_image_stats(UUID) IS 'Returns comprehensive image statistics for a specific task';
COMMENT ON FUNCTION get_user_upload_stats(TEXT, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) IS 'Returns user upload statistics with optional date filtering';
COMMENT ON FUNCTION cleanup_orphaned_images() IS 'Maintenance function to remove images for deleted tasks';

-- View comments
COMMENT ON VIEW task_image_gallery IS 'Rich view of task images with task details and calculated metadata';
COMMENT ON VIEW image_storage_summary IS 'Storage usage summary grouped by image type for administration';