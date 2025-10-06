-- Storage Bucket for Quick Task Files
-- Run this in Supabase SQL Editor or through Supabase CLI

-- 1. Create storage bucket for quick task files
INSERT INTO storage.buckets (id, name, public)
VALUES ('quick-task-files', 'quick-task-files', false)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage policies for quick task files
-- Policy: Users can upload files to their own quick tasks
CREATE POLICY "Users can upload quick task files" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'quick-task-files' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can view files from quick tasks they're involved in
CREATE POLICY "Users can view quick task files" ON storage.objects
FOR SELECT USING (
    bucket_id = 'quick-task-files' AND (
        -- File owner can always view
        auth.uid()::text = (storage.foldername(name))[1] OR
        -- Users assigned to the task can view
        auth.uid() IN (
            SELECT assigned_to_user_id 
            FROM quick_task_assignments qta
            JOIN quick_task_files qtf ON qta.quick_task_id = qtf.quick_task_id
            WHERE qtf.storage_path = name
        ) OR
        -- Task creator can view
        auth.uid() IN (
            SELECT assigned_by 
            FROM quick_tasks qt
            JOIN quick_task_files qtf ON qt.id = qtf.quick_task_id
            WHERE qtf.storage_path = name
        )
    )
);

-- Policy: Users can update files they uploaded
CREATE POLICY "Users can update their quick task files" ON storage.objects
FOR UPDATE USING (
    bucket_id = 'quick-task-files' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy: Users can delete files they uploaded or from tasks they created
CREATE POLICY "Users can delete quick task files" ON storage.objects
FOR DELETE USING (
    bucket_id = 'quick-task-files' AND (
        auth.uid()::text = (storage.foldername(name))[1] OR
        auth.uid() IN (
            SELECT assigned_by 
            FROM quick_tasks qt
            JOIN quick_task_files qtf ON qt.id = qtf.quick_task_id
            WHERE qtf.storage_path = name
        )
    )
);

-- Storage bucket configuration
UPDATE storage.buckets 
SET 
    file_size_limit = 52428800, -- 50MB limit
    allowed_mime_types = ARRAY[
        'image/jpeg', 
        'image/png', 
        'image/gif', 
        'image/webp',
        'application/pdf',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain',
        'text/csv'
    ]
WHERE id = 'quick-task-files';

-- Create view for easy file access with task information
CREATE OR REPLACE VIEW quick_task_files_with_details AS
SELECT 
    qtf.*,
    qt.title as task_title,
    qt.status as task_status,
    u.username as uploaded_by_username,
    he.name as uploaded_by_name
FROM quick_task_files qtf
LEFT JOIN quick_tasks qt ON qtf.quick_task_id = qt.id
LEFT JOIN users u ON qtf.uploaded_by = u.id
LEFT JOIN hr_employees he ON u.employee_id = he.id;