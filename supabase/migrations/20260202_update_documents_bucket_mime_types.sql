-- Update the documents bucket to allow all file types for incident attachments
-- This removes MIME type restrictions to support Excel, Word, PDF, images, and any other files

UPDATE storage.buckets 
SET allowed_mime_types = NULL,
    file_size_limit = 52428800  -- Increase to 50MB to support larger documents
WHERE id = 'documents';

-- Add a comment explaining the change
COMMENT ON TABLE storage.buckets IS 'Updated documents bucket to allow all MIME types for incident attachments';
