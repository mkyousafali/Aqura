-- Storage Buckets Migration
-- Generated on: 2025-10-30T21:55:45.336Z

-- Create storage bucket: employee-documents
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('employee-documents', 'employee-documents', true, '2025-09-27T06:44:19.983Z', '2025-09-27T06:44:19.983Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for employee-documents
CREATE POLICY "Authenticated users can view employee-documents" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'employee-documents');

CREATE POLICY "Authenticated users can upload to employee-documents" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'employee-documents');

-- Create storage bucket: user-avatars
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('user-avatars', 'user-avatars', true, '2025-09-27T09:37:55.546Z', '2025-09-27T09:37:55.546Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for user-avatars
CREATE POLICY "Authenticated users can view user-avatars" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'user-avatars');

CREATE POLICY "Authenticated users can upload to user-avatars" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'user-avatars');

-- Create storage bucket: documents
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('documents', 'documents', true, '2025-09-29T21:07:24.977Z', '2025-09-29T21:07:24.977Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for documents
CREATE POLICY "Authenticated users can view documents" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'documents');

CREATE POLICY "Authenticated users can upload to documents" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'documents');

-- Create storage bucket: original-bills
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('original-bills', 'original-bills', true, '2025-10-16T09:39:29.747Z', '2025-10-16T09:39:29.747Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for original-bills
CREATE POLICY "Authenticated users can view original-bills" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'original-bills');

CREATE POLICY "Authenticated users can upload to original-bills" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'original-bills');

-- Create storage bucket: vendor-contracts
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('vendor-contracts', 'vendor-contracts', true, '2025-09-20T10:53:24.356Z', '2025-09-20T10:53:24.356Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for vendor-contracts
CREATE POLICY "Authenticated users can view vendor-contracts" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'vendor-contracts');

CREATE POLICY "Authenticated users can upload to vendor-contracts" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'vendor-contracts');

-- Create storage bucket: pr-excel-files
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('pr-excel-files', 'pr-excel-files', true, '2025-10-18T19:05:27.954Z', '2025-10-18T19:05:27.954Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for pr-excel-files
CREATE POLICY "Authenticated users can view pr-excel-files" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'pr-excel-files');

CREATE POLICY "Authenticated users can upload to pr-excel-files" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'pr-excel-files');

-- Create storage bucket: requisition-images
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('requisition-images', 'requisition-images', true, '2025-10-26T15:56:44.886Z', '2025-10-26T15:56:44.886Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for requisition-images
CREATE POLICY "Authenticated users can view requisition-images" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'requisition-images');

CREATE POLICY "Authenticated users can upload to requisition-images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'requisition-images');

-- Create storage bucket: expense-scheduler-bills
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('expense-scheduler-bills', 'expense-scheduler-bills', false, '2025-10-27T17:17:54.351Z', '2025-10-27T17:17:54.351Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for expense-scheduler-bills
CREATE POLICY "Authenticated users can view expense-scheduler-bills" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'expense-scheduler-bills');

CREATE POLICY "Authenticated users can upload to expense-scheduler-bills" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'expense-scheduler-bills');

-- Create storage bucket: notification-images
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('notification-images', 'notification-images', true, '2025-10-05T08:21:22.199Z', '2025-10-05T08:21:22.199Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for notification-images
CREATE POLICY "Authenticated users can view notification-images" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'notification-images');

CREATE POLICY "Authenticated users can upload to notification-images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'notification-images');

-- Create storage bucket: task-images
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('task-images', 'task-images', true, '2025-09-29T21:07:24.977Z', '2025-09-29T21:07:24.977Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for task-images
CREATE POLICY "Authenticated users can view task-images" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'task-images');

CREATE POLICY "Authenticated users can upload to task-images" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'task-images');

-- Create storage bucket: warning-documents
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('warning-documents', 'warning-documents', true, '2025-10-30T17:22:56.189Z', '2025-10-30T17:22:56.189Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for warning-documents
CREATE POLICY "Authenticated users can view warning-documents" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'warning-documents');

CREATE POLICY "Authenticated users can upload to warning-documents" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'warning-documents');

-- Create storage bucket: quick-task-files
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('quick-task-files', 'quick-task-files', true, '2025-10-06T11:32:05.112Z', '2025-10-06T11:32:05.112Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for quick-task-files
CREATE POLICY "Authenticated users can view quick-task-files" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'quick-task-files');

CREATE POLICY "Authenticated users can upload to quick-task-files" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'quick-task-files');

-- Create storage bucket: completion-photos
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('completion-photos', 'completion-photos', true, '2025-09-29T21:07:24.977Z', '2025-09-29T21:07:24.977Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for completion-photos
CREATE POLICY "Authenticated users can view completion-photos" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'completion-photos');

CREATE POLICY "Authenticated users can upload to completion-photos" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'completion-photos');

-- Create storage bucket: clearance-certificates
INSERT INTO storage.buckets (id, name, public, created_at, updated_at)
VALUES ('clearance-certificates', 'clearance-certificates', true, '2025-10-16T07:51:17.889Z', '2025-10-16T07:51:17.889Z')
ON CONFLICT (id) DO NOTHING;

-- Storage policies for clearance-certificates
CREATE POLICY "Authenticated users can view clearance-certificates" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'clearance-certificates');

CREATE POLICY "Authenticated users can upload to clearance-certificates" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'clearance-certificates');

