-- Migration: Create storage bucket for pr excel files
-- File: 54_storage_pr_excel_files_bucket.sql
-- Description: Creates the pr-excel-files storage bucket with policies

BEGIN;

-- Create storage bucket for pr excel files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pr-excel-files',
  'pr-excel-files',
  true,
  52428800, -- 50 MB in bytes
  ARRAY['application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
);

-- Create storage policies for pr-excel-files bucket
-- Policy: Allow all operations on pr-excel-files
CREATE POLICY "Allow all operations on pr-excel-files" ON storage.objects
FOR ALL
USING (bucket_id = 'pr-excel-files');

COMMIT;