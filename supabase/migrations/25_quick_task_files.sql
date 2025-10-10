-- Create quick_task_files table for managing file attachments on quick tasks
-- This table stores file metadata and references to files in storage buckets

-- Create the quick_task_files table
CREATE TABLE IF NOT EXISTS public.quick_task_files (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    quick_task_id UUID NOT NULL,
    file_name CHARACTER VARYING(255) NOT NULL,
    file_type CHARACTER VARYING(100) NULL,
    file_size INTEGER NULL,
    mime_type CHARACTER VARYING(100) NULL,
    storage_path TEXT NOT NULL,
    storage_bucket CHARACTER VARYING(100) NULL DEFAULT 'quick-task-files'::character varying,
    uploaded_by UUID NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT quick_task_files_pkey PRIMARY KEY (id),
    CONSTRAINT quick_task_files_quick_task_id_fkey 
        FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE,
    CONSTRAINT quick_task_files_uploaded_by_fkey 
        FOREIGN KEY (uploaded_by) REFERENCES users (id) ON DELETE SET NULL
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_quick_task_files_task 
ON public.quick_task_files USING btree (quick_task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_files_uploaded_by 
ON public.quick_task_files USING btree (uploaded_by) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_files_file_type 
ON public.quick_task_files (file_type);

CREATE INDEX IF NOT EXISTS idx_quick_task_files_mime_type 
ON public.quick_task_files (mime_type);

CREATE INDEX IF NOT EXISTS idx_quick_task_files_uploaded_at 
ON public.quick_task_files (uploaded_at DESC);

CREATE INDEX IF NOT EXISTS idx_quick_task_files_bucket_path 
ON public.quick_task_files (storage_bucket, storage_path);

CREATE INDEX IF NOT EXISTS idx_quick_task_files_task_uploaded 
ON public.quick_task_files (quick_task_id, uploaded_at DESC);

CREATE INDEX IF NOT EXISTS idx_quick_task_files_size_range 
ON public.quick_task_files (file_size) 
WHERE file_size IS NOT NULL;

-- Create partial index for large files
CREATE INDEX IF NOT EXISTS idx_quick_task_files_large_files 
ON public.quick_task_files (quick_task_id, file_size) 
WHERE file_size > 10485760; -- Files larger than 10MB

-- Create text search index for file names
CREATE INDEX IF NOT EXISTS idx_quick_task_files_name_search 
ON public.quick_task_files USING gin (to_tsvector('english', file_name));

-- Add updated_at column and trigger
ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_quick_task_files_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_quick_task_files_updated_at 
BEFORE UPDATE ON quick_task_files 
FOR EACH ROW 
EXECUTE FUNCTION update_quick_task_files_updated_at();

-- Add data validation constraints
ALTER TABLE public.quick_task_files 
ADD CONSTRAINT chk_file_name_not_empty 
CHECK (TRIM(file_name) != '');

ALTER TABLE public.quick_task_files 
ADD CONSTRAINT chk_storage_path_not_empty 
CHECK (TRIM(storage_path) != '');

ALTER TABLE public.quick_task_files 
ADD CONSTRAINT chk_file_size_positive 
CHECK (file_size IS NULL OR file_size > 0);

ALTER TABLE public.quick_task_files 
ADD CONSTRAINT chk_file_size_reasonable 
CHECK (file_size IS NULL OR file_size <= 1073741824); -- Max 1GB

-- Add additional columns for enhanced functionality
ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS file_hash CHARACTER VARYING(64);

ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;

ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS download_count INTEGER DEFAULT 0;

ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS last_accessed_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS expiry_date TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS metadata JSONB;

ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;

ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.quick_task_files 
ADD COLUMN IF NOT EXISTS deleted_by UUID;

-- Add foreign key for deleted_by
ALTER TABLE public.quick_task_files 
ADD CONSTRAINT quick_task_files_deleted_by_fkey 
FOREIGN KEY (deleted_by) REFERENCES users (id) ON DELETE SET NULL;

-- Create unique constraint for file hash to prevent duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_quick_task_files_hash_unique 
ON public.quick_task_files (file_hash) 
WHERE file_hash IS NOT NULL AND is_deleted = false;

-- Add table and column comments
COMMENT ON TABLE public.quick_task_files IS 'File attachments for quick tasks with metadata and storage information';
COMMENT ON COLUMN public.quick_task_files.id IS 'Unique identifier for the file record';
COMMENT ON COLUMN public.quick_task_files.quick_task_id IS 'Reference to the quick task';
COMMENT ON COLUMN public.quick_task_files.file_name IS 'Original name of the uploaded file';
COMMENT ON COLUMN public.quick_task_files.file_type IS 'File extension or type';
COMMENT ON COLUMN public.quick_task_files.file_size IS 'Size of the file in bytes';
COMMENT ON COLUMN public.quick_task_files.mime_type IS 'MIME type of the file';
COMMENT ON COLUMN public.quick_task_files.storage_path IS 'Path to the file in storage bucket';
COMMENT ON COLUMN public.quick_task_files.storage_bucket IS 'Storage bucket name';
COMMENT ON COLUMN public.quick_task_files.uploaded_by IS 'User who uploaded the file';
COMMENT ON COLUMN public.quick_task_files.uploaded_at IS 'When the file was uploaded';
COMMENT ON COLUMN public.quick_task_files.updated_at IS 'When the record was last updated';
COMMENT ON COLUMN public.quick_task_files.file_hash IS 'Hash of the file content for deduplication';
COMMENT ON COLUMN public.quick_task_files.is_public IS 'Whether the file is publicly accessible';
COMMENT ON COLUMN public.quick_task_files.download_count IS 'Number of times the file has been downloaded';
COMMENT ON COLUMN public.quick_task_files.last_accessed_at IS 'When the file was last accessed';
COMMENT ON COLUMN public.quick_task_files.expiry_date IS 'When the file should expire (optional)';
COMMENT ON COLUMN public.quick_task_files.metadata IS 'Additional file metadata as JSON';
COMMENT ON COLUMN public.quick_task_files.is_deleted IS 'Soft delete flag';
COMMENT ON COLUMN public.quick_task_files.deleted_at IS 'When the file was soft deleted';
COMMENT ON COLUMN public.quick_task_files.deleted_by IS 'User who deleted the file';

-- Create view for active files with user details
CREATE OR REPLACE VIEW quick_task_files_active AS
SELECT 
    qtf.id,
    qtf.quick_task_id,
    qt.title as task_title,
    qtf.file_name,
    qtf.file_type,
    qtf.file_size,
    qtf.mime_type,
    qtf.storage_path,
    qtf.storage_bucket,
    qtf.uploaded_by,
    u.username as uploaded_by_username,
    u.full_name as uploaded_by_name,
    qtf.file_hash,
    qtf.is_public,
    qtf.download_count,
    qtf.last_accessed_at,
    qtf.expiry_date,
    qtf.metadata,
    qtf.uploaded_at,
    qtf.updated_at,
    CASE 
        WHEN qtf.expiry_date IS NOT NULL AND qtf.expiry_date < now() THEN true
        ELSE false
    END as is_expired
FROM quick_task_files qtf
LEFT JOIN users u ON qtf.uploaded_by = u.id
LEFT JOIN quick_tasks qt ON qtf.quick_task_id = qt.id
WHERE qtf.is_deleted = false
ORDER BY qtf.uploaded_at DESC;

-- Create function to upload a file record
CREATE OR REPLACE FUNCTION upload_task_file(
    task_id UUID,
    file_name_param VARCHAR,
    file_type_param VARCHAR DEFAULT NULL,
    file_size_param INTEGER DEFAULT NULL,
    mime_type_param VARCHAR DEFAULT NULL,
    storage_path_param TEXT,
    storage_bucket_param VARCHAR DEFAULT 'quick-task-files',
    uploaded_by_param UUID DEFAULT NULL,
    file_hash_param VARCHAR DEFAULT NULL,
    is_public_param BOOLEAN DEFAULT false,
    metadata_param JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    file_id UUID;
BEGIN
    INSERT INTO quick_task_files (
        quick_task_id,
        file_name,
        file_type,
        file_size,
        mime_type,
        storage_path,
        storage_bucket,
        uploaded_by,
        file_hash,
        is_public,
        metadata
    ) VALUES (
        task_id,
        file_name_param,
        file_type_param,
        file_size_param,
        mime_type_param,
        storage_path_param,
        storage_bucket_param,
        uploaded_by_param,
        file_hash_param,
        is_public_param,
        metadata_param
    ) RETURNING id INTO file_id;
    
    RETURN file_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to soft delete a file
CREATE OR REPLACE FUNCTION delete_task_file(
    file_id UUID,
    deleter_user_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE quick_task_files 
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = deleter_user_id,
        updated_at = now()
    WHERE id = file_id 
      AND is_deleted = false
      AND (uploaded_by = deleter_user_id OR deleter_user_id IN (
          SELECT id FROM users WHERE role IN ('admin', 'manager')
      ));
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to track file downloads
CREATE OR REPLACE FUNCTION track_file_download(file_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE quick_task_files 
    SET download_count = download_count + 1,
        last_accessed_at = now(),
        updated_at = now()
    WHERE id = file_id 
      AND is_deleted = false;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get file statistics for a task
CREATE OR REPLACE FUNCTION get_task_file_stats(task_id UUID)
RETURNS TABLE(
    total_files BIGINT,
    total_size BIGINT,
    active_files BIGINT,
    deleted_files BIGINT,
    public_files BIGINT,
    private_files BIGINT,
    expired_files BIGINT,
    total_downloads BIGINT,
    image_files BIGINT,
    document_files BIGINT,
    video_files BIGINT,
    audio_files BIGINT,
    other_files BIGINT,
    latest_upload_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_files,
        COALESCE(SUM(file_size), 0) as total_size,
        COUNT(*) FILTER (WHERE is_deleted = false) as active_files,
        COUNT(*) FILTER (WHERE is_deleted = true) as deleted_files,
        COUNT(*) FILTER (WHERE is_public = true AND is_deleted = false) as public_files,
        COUNT(*) FILTER (WHERE is_public = false AND is_deleted = false) as private_files,
        COUNT(*) FILTER (WHERE expiry_date IS NOT NULL AND expiry_date < now() AND is_deleted = false) as expired_files,
        COALESCE(SUM(download_count), 0) as total_downloads,
        COUNT(*) FILTER (WHERE mime_type LIKE 'image/%' AND is_deleted = false) as image_files,
        COUNT(*) FILTER (WHERE mime_type IN ('application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') AND is_deleted = false) as document_files,
        COUNT(*) FILTER (WHERE mime_type LIKE 'video/%' AND is_deleted = false) as video_files,
        COUNT(*) FILTER (WHERE mime_type LIKE 'audio/%' AND is_deleted = false) as audio_files,
        COUNT(*) FILTER (WHERE mime_type NOT LIKE 'image/%' AND mime_type NOT LIKE 'video/%' AND mime_type NOT LIKE 'audio/%' AND mime_type NOT IN ('application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') AND is_deleted = false) as other_files,
        MAX(uploaded_at) as latest_upload_at
    FROM quick_task_files
    WHERE quick_task_id = task_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up expired files
CREATE OR REPLACE FUNCTION cleanup_expired_files()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    UPDATE quick_task_files 
    SET is_deleted = true,
        deleted_at = now(),
        deleted_by = NULL -- System cleanup
    WHERE expiry_date IS NOT NULL 
      AND expiry_date < now() 
      AND is_deleted = false;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get duplicate files
CREATE OR REPLACE FUNCTION get_duplicate_files()
RETURNS TABLE(
    file_hash VARCHAR,
    file_count BIGINT,
    total_size BIGINT,
    file_ids UUID[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        qtf.file_hash,
        COUNT(*) as file_count,
        SUM(qtf.file_size) as total_size,
        ARRAY_AGG(qtf.id) as file_ids
    FROM quick_task_files qtf
    WHERE qtf.file_hash IS NOT NULL 
      AND qtf.is_deleted = false
    GROUP BY qtf.file_hash
    HAVING COUNT(*) > 1
    ORDER BY COUNT(*) DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get files by type
CREATE OR REPLACE FUNCTION get_files_by_type(
    task_id UUID DEFAULT NULL,
    file_type_filter VARCHAR DEFAULT NULL,
    include_deleted BOOLEAN DEFAULT false
)
RETURNS TABLE(
    file_id UUID,
    file_name VARCHAR,
    file_type VARCHAR,
    file_size INTEGER,
    mime_type VARCHAR,
    storage_path TEXT,
    uploaded_by UUID,
    uploaded_by_name VARCHAR,
    uploaded_at TIMESTAMPTZ,
    download_count INTEGER,
    is_public BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        qtf.id,
        qtf.file_name,
        qtf.file_type,
        qtf.file_size,
        qtf.mime_type,
        qtf.storage_path,
        qtf.uploaded_by,
        COALESCE(u.full_name, u.username) as uploaded_by_name,
        qtf.uploaded_at,
        qtf.download_count,
        qtf.is_public
    FROM quick_task_files qtf
    LEFT JOIN users u ON qtf.uploaded_by = u.id
    WHERE (task_id IS NULL OR qtf.quick_task_id = task_id)
      AND (file_type_filter IS NULL OR qtf.file_type = file_type_filter)
      AND (include_deleted = true OR qtf.is_deleted = false)
    ORDER BY qtf.uploaded_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update task's last activity when file is uploaded
CREATE OR REPLACE FUNCTION update_task_last_activity_on_file()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the quick_tasks table with last activity if that column exists
    BEGIN
        UPDATE quick_tasks 
        SET updated_at = now()
        WHERE id = NEW.quick_task_id;
    EXCEPTION
        WHEN undefined_column THEN
            -- Column doesn't exist, ignore
            NULL;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_task_last_activity_on_file
AFTER INSERT ON quick_task_files 
FOR EACH ROW 
EXECUTE FUNCTION update_task_last_activity_on_file();

RAISE NOTICE 'quick_task_files table created with comprehensive file management features';