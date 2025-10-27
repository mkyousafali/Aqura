-- Update storage bucket file size limit from 10MB to 50MB for expense scheduler bills

UPDATE storage.buckets
SET file_size_limit = 52428800  -- 50MB in bytes (50 * 1024 * 1024)
WHERE id = 'expense-scheduler-bills';
