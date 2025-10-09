-- ===================================================
-- SUPABASE STORAGE BUCKETS INFORMATION
-- Generated on: 2025-10-09T15:56:21.328Z
-- ===================================================

-- Bucket: employee-documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'employee-documents',
  'employee-documents',
  true,
  10485760,
  '["image/jpeg","image/jpg","image/png","image/webp","application/pdf","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document"]'
);

-- Bucket: user-avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-avatars',
  'user-avatars',
  true,
  NULL,
  NULL
);

-- Bucket: documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  true,
  10485760,
  '["application/pdf","image/jpeg","image/png","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document","text/plain"]'
);

-- Bucket: completion-photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'completion-photos',
  'completion-photos',
  true,
  5242880,
  '["image/jpeg","image/png","image/gif","image/webp"]'
);

-- Bucket: vendor-contracts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'vendor-contracts',
  'vendor-contracts',
  true,
  52428800,
  '["application/pdf"]'
);

-- Bucket: notification-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'notification-images',
  'notification-images',
  true,
  52428800,
  '["image/jpeg","image/png","image/gif","image/webp","image/svg+xml","application/pdf","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document","application/vnd.ms-excel","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","text/csv","text/plain","application/sql","text/sql"]'
);

-- Bucket: task-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'task-images',
  'task-images',
  true,
  52428800,
  '["image/jpeg","image/png","image/gif","image/webp","image/svg+xml","application/pdf","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document","application/vnd.ms-excel","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","text/csv","text/plain","application/sql","text/sql"]'
);

-- Bucket: quick-task-files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'quick-task-files',
  'quick-task-files',
  true,
  52428800,
  '["image/jpeg","image/png","image/gif","image/webp","application/pdf","application/vnd.ms-excel","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document","text/plain","text/csv"]'
);