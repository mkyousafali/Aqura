SELECT 
  id,
  quick_task_id,
  assigned_to_user_id,
  require_photo_upload,
  require_task_finished,
  require_erp_reference,
  created_at
FROM quick_task_assignments 
ORDER BY created_at DESC 
LIMIT 5;
