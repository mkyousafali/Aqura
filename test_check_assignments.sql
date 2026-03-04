-- Check latest assignments to verify photo requirement
SELECT 
  id,
  quick_task_id,
  require_photo_upload,
  require_task_finished,
  created_at
FROM quick_task_assignments 
ORDER BY created_at DESC 
LIMIT 3;
