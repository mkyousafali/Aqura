-- =====================================================
-- Fix task_completions trigger issue
-- =====================================================
-- Purpose: Drop the problematic trigger that references non-existent columns
-- The trigger was trying to reference receiving_tasks.task_id which doesn't exist
-- =====================================================

-- Drop the problematic trigger
DROP TRIGGER IF EXISTS trigger_sync_erp_on_completion ON task_completions;

-- Drop the function if it exists
DROP FUNCTION IF EXISTS trigger_sync_erp_reference_on_task_completion();

-- Note: The ERP reference syncing is now handled directly in the application code
-- (TaskCompletionModal.svelte) which updates vendor_payment_schedule.payment_reference
-- when a payment task is completed with an ERP reference.
