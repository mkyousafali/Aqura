-- Create notification_attachments table for managing notification file attachments
-- This table stores file attachment information linked to notifications

-- Create the notification_attachments table
CREATE TABLE IF NOT EXISTS public.notification_attachments (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,
    file_name CHARACTER VARYING(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    file_type CHARACTER VARYING(100) NOT NULL,
    uploaded_by CHARACTER VARYING(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    CONSTRAINT notification_attachments_pkey PRIMARY KEY (id),
    CONSTRAINT notification_attachments_notification_fkey 
        FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notification_attachments_notification_id 
ON public.notification_attachments USING btree (notification_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_attachments_uploaded_by 
ON public.notification_attachments USING btree (uploaded_by) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_notification_attachments_file_type 
ON public.notification_attachments (file_type);

CREATE INDEX IF NOT EXISTS idx_notification_attachments_file_size 
ON public.notification_attachments (file_size);

CREATE INDEX IF NOT EXISTS idx_notification_attachments_created_at 
ON public.notification_attachments (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_attachments_file_name 
ON public.notification_attachments (file_name);

-- Create text search index for file names
CREATE INDEX IF NOT EXISTS idx_notification_attachments_file_search 
ON public.notification_attachments USING gin (to_tsvector('english', file_name));

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_notification_attachments_notification_created 
ON public.notification_attachments (notification_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_attachments_uploader_created 
ON public.notification_attachments (uploaded_by, created_at DESC);

-- Add updated_at column and trigger
ALTER TABLE public.notification_attachments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_notification_attachments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_notification_attachments_updated_at 
BEFORE UPDATE ON notification_attachments 
FOR EACH ROW 
EXECUTE FUNCTION update_notification_attachments_updated_at();

-- Add data validation constraints
ALTER TABLE public.notification_attachments 
ADD CONSTRAINT chk_file_name_not_empty 
CHECK (TRIM(file_name) != '');

ALTER TABLE public.notification_attachments 
ADD CONSTRAINT chk_file_path_not_empty 
CHECK (TRIM(file_path) != '');

ALTER TABLE public.notification_attachments 
ADD CONSTRAINT chk_file_size_positive 
CHECK (file_size > 0);

ALTER TABLE public.notification_attachments 
ADD CONSTRAINT chk_file_size_reasonable 
CHECK (file_size <= 104857600); -- 100MB limit

ALTER TABLE public.notification_attachments 
ADD CONSTRAINT chk_uploaded_by_not_empty 
CHECK (TRIM(uploaded_by) != '');

-- Add common file type validation
ALTER TABLE public.notification_attachments 
ADD CONSTRAINT chk_file_type_valid 
CHECK (file_type IN (
    'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain', 'text/csv', 'application/zip', 'application/x-rar-compressed',
    'image/jpeg', 'image/png', 'image/gif', 'image/bmp', 'image/tiff', 'image/webp',
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'video/mp4', 'video/avi', 'video/mov',
    'application/json', 'application/xml', 'text/html'
));

-- Add table and column comments
COMMENT ON TABLE public.notification_attachments IS 'File attachments associated with notifications';
COMMENT ON COLUMN public.notification_attachments.id IS 'Unique identifier for the attachment';
COMMENT ON COLUMN public.notification_attachments.notification_id IS 'Reference to the parent notification';
COMMENT ON COLUMN public.notification_attachments.file_name IS 'Original name of the uploaded file';
COMMENT ON COLUMN public.notification_attachments.file_path IS 'Storage path or URL of the file';
COMMENT ON COLUMN public.notification_attachments.file_size IS 'Size of the file in bytes';
COMMENT ON COLUMN public.notification_attachments.file_type IS 'MIME type of the file';
COMMENT ON COLUMN public.notification_attachments.uploaded_by IS 'Username or identifier of who uploaded the file';
COMMENT ON COLUMN public.notification_attachments.created_at IS 'Timestamp when the attachment was uploaded';
COMMENT ON COLUMN public.notification_attachments.updated_at IS 'Timestamp when the attachment was last updated';

-- Create view for attachment details with notification info
CREATE OR REPLACE VIEW notification_attachment_details AS
SELECT 
    na.id,
    na.notification_id,
    n.title as notification_title,
    n.message as notification_message,
    na.file_name,
    na.file_path,
    na.file_size,
    na.file_type,
    na.uploaded_by,
    na.created_at,
    na.updated_at,
    CASE 
        WHEN na.file_size < 1024 THEN na.file_size::TEXT || ' B'
        WHEN na.file_size < 1048576 THEN ROUND(na.file_size / 1024.0, 2)::TEXT || ' KB'
        WHEN na.file_size < 1073741824 THEN ROUND(na.file_size / 1048576.0, 2)::TEXT || ' MB'
        ELSE ROUND(na.file_size / 1073741824.0, 2)::TEXT || ' GB'
    END as file_size_formatted,
    CASE 
        WHEN na.file_type LIKE 'image/%' THEN 'image'
        WHEN na.file_type LIKE 'video/%' THEN 'video'
        WHEN na.file_type LIKE 'audio/%' THEN 'audio'
        WHEN na.file_type IN ('application/pdf') THEN 'pdf'
        WHEN na.file_type LIKE 'application/vnd.ms-%' OR na.file_type LIKE 'application/vnd.openxmlformats%' THEN 'office'
        WHEN na.file_type IN ('text/plain', 'text/csv', 'application/json', 'application/xml') THEN 'text'
        WHEN na.file_type IN ('application/zip', 'application/x-rar-compressed') THEN 'archive'
        ELSE 'other'
    END as file_category
FROM notification_attachments na
LEFT JOIN notifications n ON na.notification_id = n.id
ORDER BY na.created_at DESC;

-- Create function to get attachments by notification
CREATE OR REPLACE FUNCTION get_notification_attachments(notif_id UUID)
RETURNS TABLE(
    attachment_id UUID,
    file_name VARCHAR,
    file_path TEXT,
    file_size BIGINT,
    file_size_formatted TEXT,
    file_type VARCHAR,
    file_category VARCHAR,
    uploaded_by VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        na.id,
        na.file_name,
        na.file_path,
        na.file_size,
        CASE 
            WHEN na.file_size < 1024 THEN na.file_size::TEXT || ' B'
            WHEN na.file_size < 1048576 THEN ROUND(na.file_size / 1024.0, 2)::TEXT || ' KB'
            WHEN na.file_size < 1073741824 THEN ROUND(na.file_size / 1048576.0, 2)::TEXT || ' MB'
            ELSE ROUND(na.file_size / 1073741824.0, 2)::TEXT || ' GB'
        END as file_size_formatted,
        na.file_type,
        CASE 
            WHEN na.file_type LIKE 'image/%' THEN 'image'::VARCHAR
            WHEN na.file_type LIKE 'video/%' THEN 'video'::VARCHAR
            WHEN na.file_type LIKE 'audio/%' THEN 'audio'::VARCHAR
            WHEN na.file_type IN ('application/pdf') THEN 'pdf'::VARCHAR
            WHEN na.file_type LIKE 'application/vnd.ms-%' OR na.file_type LIKE 'application/vnd.openxmlformats%' THEN 'office'::VARCHAR
            WHEN na.file_type IN ('text/plain', 'text/csv', 'application/json', 'application/xml') THEN 'text'::VARCHAR
            WHEN na.file_type IN ('application/zip', 'application/x-rar-compressed') THEN 'archive'::VARCHAR
            ELSE 'other'::VARCHAR
        END as file_category,
        na.uploaded_by,
        na.created_at
    FROM notification_attachments na
    WHERE na.notification_id = notif_id
    ORDER BY na.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get attachment statistics
CREATE OR REPLACE FUNCTION get_attachment_statistics()
RETURNS TABLE(
    total_attachments BIGINT,
    total_size_bytes BIGINT,
    total_size_formatted TEXT,
    avg_file_size NUMERIC,
    most_common_type VARCHAR,
    unique_uploaders BIGINT
) AS $$
DECLARE
    total_bytes BIGINT;
BEGIN
    SELECT COALESCE(SUM(file_size), 0) INTO total_bytes FROM notification_attachments;
    
    RETURN QUERY
    SELECT 
        COUNT(*) as total_attachments,
        total_bytes as total_size_bytes,
        CASE 
            WHEN total_bytes < 1024 THEN total_bytes::TEXT || ' B'
            WHEN total_bytes < 1048576 THEN ROUND(total_bytes / 1024.0, 2)::TEXT || ' KB'
            WHEN total_bytes < 1073741824 THEN ROUND(total_bytes / 1048576.0, 2)::TEXT || ' MB'
            ELSE ROUND(total_bytes / 1073741824.0, 2)::TEXT || ' GB'
        END as total_size_formatted,
        ROUND(AVG(file_size), 2) as avg_file_size,
        (SELECT file_type FROM notification_attachments GROUP BY file_type ORDER BY COUNT(*) DESC LIMIT 1) as most_common_type,
        COUNT(DISTINCT uploaded_by) as unique_uploaders
    FROM notification_attachments;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up orphaned attachments
CREATE OR REPLACE FUNCTION cleanup_orphaned_attachments()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notification_attachments 
    WHERE notification_id NOT IN (SELECT id FROM notifications);
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get large files
CREATE OR REPLACE FUNCTION get_large_attachments(size_threshold_mb NUMERIC DEFAULT 10)
RETURNS TABLE(
    attachment_id UUID,
    notification_id UUID,
    file_name VARCHAR,
    file_size BIGINT,
    file_size_mb NUMERIC,
    uploaded_by VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
DECLARE
    size_threshold_bytes BIGINT;
BEGIN
    size_threshold_bytes := (size_threshold_mb * 1048576)::BIGINT;
    
    RETURN QUERY
    SELECT 
        na.id,
        na.notification_id,
        na.file_name,
        na.file_size,
        ROUND(na.file_size / 1048576.0, 2) as file_size_mb,
        na.uploaded_by,
        na.created_at
    FROM notification_attachments na
    WHERE na.file_size > size_threshold_bytes
    ORDER BY na.file_size DESC;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'notification_attachments table created with file management and statistics features';