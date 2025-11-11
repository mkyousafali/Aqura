-- ============================================================
-- FIX: Remove inventory_manager dependency from accountant
-- ============================================================
-- The accountant role should NOT depend on inventory_manager TASK
-- Instead, it checks if FILES are uploaded (handled in function)
-- ============================================================

UPDATE receiving_task_templates
SET 
  depends_on_role_types = NULL,  -- Remove inventory_manager dependency
  updated_at = NOW()
WHERE role_type = 'accountant';

-- ============================================================
-- EXPLANATION:
-- Before: accountant depends on inventory_manager TASK completion
-- After: accountant checks if PR Excel + Original Bill FILES are uploaded
--        (This is handled in check_accountant_dependency function)
-- ============================================================

-- Verify the change:
SELECT 
  role_type,
  depends_on_role_types,
  require_photo_upload,
  require_erp_reference,
  require_original_bill_upload
FROM receiving_task_templates
WHERE role_type = 'accountant';
