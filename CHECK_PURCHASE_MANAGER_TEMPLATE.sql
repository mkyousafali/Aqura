-- ============================================================
-- CHECK: What dependencies does purchase_manager have?
-- ============================================================

SELECT 
  role_type,
  depends_on_role_types,
  require_photo_upload,
  require_erp_reference,
  require_original_bill_upload
FROM receiving_task_templates
WHERE role_type = 'purchase_manager';

-- ============================================================
-- This will show if purchase_manager has similar dependency issues
-- ============================================================
