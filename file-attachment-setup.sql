-- File Attachment Support Setup
-- This script creates the necessary tables and storage buckets for file attachments
-- Run this in Supabase SQL Editor

-- 1. Create notification_attachments table if not exists
CREATE TABLE IF NOT EXISTS notification_attachments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    notification_id uuid NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    file_name text NOT NULL,
    file_path text NOT NULL,
    file_size bigint NOT NULL,
    file_type text NOT NULL,
    uploaded_by uuid NOT NULL REFERENCES users(id),
    created_at timestamp with time zone DEFAULT now()
);

-- 2. Create task_attachments table for task files
CREATE TABLE IF NOT EXISTS task_attachments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    file_name text NOT NULL,
    file_path text NOT NULL,
    file_size bigint NOT NULL,
    file_type text NOT NULL,
    attachment_type text DEFAULT 'task_creation' CHECK (attachment_type IN ('task_creation', 'task_completion')),
    uploaded_by uuid NOT NULL REFERENCES users(id),
    uploaded_by_name text,
    created_at timestamp with time zone DEFAULT now()
);

-- 3. Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_notification_attachments_notification_id ON notification_attachments(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_attachments_uploaded_by ON notification_attachments(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_task_attachments_task_id ON task_attachments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_attachments_uploaded_by ON task_attachments(uploaded_by);

-- 4. Create storage buckets for different file types

-- Documents bucket (for PDFs, Word docs, Excel files, etc.)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'documents',
    'documents', 
    true,
    52428800, -- 50MB in bytes
    ARRAY[
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/csv',
        'text/plain',
        'application/sql',
        'text/sql',
        'application/zip',
        'application/x-zip-compressed',
        'application/x-rar-compressed',
        'application/x-7z-compressed'
    ]
) ON CONFLICT (id) DO NOTHING;

-- Update notification-images bucket to support more file types
UPDATE storage.buckets 
SET 
    file_size_limit = 52428800, -- 50MB
    allowed_mime_types = ARRAY[
        'image/jpeg', 
        'image/png', 
        'image/gif', 
        'image/webp',
        'image/svg+xml',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/csv',
        'text/plain',
        'application/sql',
        'text/sql'
    ]
WHERE id = 'notification-images';

-- Update task-images bucket to support more file types  
UPDATE storage.buckets 
SET 
    file_size_limit = 52428800, -- 50MB
    allowed_mime_types = ARRAY[
        'image/jpeg', 
        'image/png', 
        'image/gif', 
        'image/webp',
        'image/svg+xml',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/csv',
        'text/plain',
        'application/sql',
        'text/sql'
    ]
WHERE id = 'task-images';

-- 5. Create RLS policies for documents bucket

-- Allow authenticated users to upload documents
CREATE POLICY "Allow authenticated users to upload documents" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'documents');

-- Allow public read access to documents
CREATE POLICY "Allow public read access to documents" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'documents');

-- Allow users to delete their own uploads
CREATE POLICY "Allow users to delete their own documents" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 6. Create RLS policies for notification_attachments table

-- Enable RLS
ALTER TABLE notification_attachments ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view attachments for notifications they can see
CREATE POLICY "Users can view notification attachments" ON notification_attachments
FOR SELECT TO authenticated
USING (
    notification_id IN (
        SELECT id FROM notifications 
        WHERE created_by = auth.uid()::text 
        OR target_type = 'all_users'
        OR (target_type = 'specific_users' AND id IN (
            SELECT notification_id FROM notification_recipients 
            WHERE user_id = auth.uid()::text
        ))
    )
);

-- Allow authenticated users to create attachments for their notifications
CREATE POLICY "Users can create notification attachments" ON notification_attachments
FOR INSERT TO authenticated
WITH CHECK (uploaded_by = auth.uid());

-- Allow users to delete their own attachments
CREATE POLICY "Users can delete their own notification attachments" ON notification_attachments
FOR DELETE TO authenticated
USING (uploaded_by = auth.uid());

-- 7. Create RLS policies for task_attachments table

-- Enable RLS
ALTER TABLE task_attachments ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view task attachments
CREATE POLICY "Users can view task attachments" ON task_attachments
FOR SELECT TO authenticated
USING (
    task_id IN (
        SELECT id FROM tasks 
        WHERE created_by = auth.uid()::text
    )
    OR task_id IN (
        SELECT task_id FROM task_assignments 
        WHERE assigned_to = auth.uid()::text
    )
);

-- Allow authenticated users to create task attachments
CREATE POLICY "Users can create task attachments" ON task_attachments
FOR INSERT TO authenticated
WITH CHECK (uploaded_by = auth.uid());

-- Allow users to delete their own task attachments
CREATE POLICY "Users can delete their own task attachments" ON task_attachments
FOR DELETE TO authenticated
USING (uploaded_by = auth.uid());

-- 8. Create helper function to get file extension
CREATE OR REPLACE FUNCTION get_file_extension(filename text)
RETURNS text AS $$
BEGIN
    RETURN lower(split_part(filename, '.', array_length(string_to_array(filename, '.'), 1)));
END;
$$ LANGUAGE plpgsql;

-- 9. Create helper function to format file size
CREATE OR REPLACE FUNCTION format_file_size(size_bytes bigint)
RETURNS text AS $$
DECLARE
    size_kb numeric := size_bytes / 1024.0;
    size_mb numeric := size_kb / 1024.0;
    size_gb numeric := size_mb / 1024.0;
BEGIN
    IF size_gb >= 1 THEN
        RETURN round(size_gb, 2) || ' GB';
    ELSIF size_mb >= 1 THEN
        RETURN round(size_mb, 2) || ' MB';
    ELSIF size_kb >= 1 THEN
        RETURN round(size_kb, 2) || ' KB';
    ELSE
        RETURN size_bytes || ' Bytes';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 10. Verify setup
DO $$
BEGIN
    RAISE NOTICE 'File attachment support setup completed!';
    RAISE NOTICE 'Tables created: notification_attachments, task_attachments';
    RAISE NOTICE 'Storage buckets: documents, notification-images (updated), task-images (updated)';
    RAISE NOTICE 'RLS policies created for security';
    RAISE NOTICE 'Helper functions: get_file_extension, format_file_size';
END $$;