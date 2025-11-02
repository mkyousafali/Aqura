-- =====================================================
-- Fix trigger_sync_erp_reference_on_task_completion
-- =====================================================
-- Purpose: Fix the trigger to work with correct table structure
-- The receiving_tasks table doesn't have task_id/assignment_id columns
-- It has its own id and is independent of the tasks/task_assignments tables
-- =====================================================

-- Drop and recreate the function with the correct logic
CREATE OR REPLACE FUNCTION public.trigger_sync_erp_reference_on_task_completion()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    update_count INTEGER := 0;
BEGIN
    -- Only process if ERP reference is provided and completed
    IF NEW.erp_reference_completed = true 
       AND NEW.erp_reference_number IS NOT NULL 
       AND TRIM(NEW.erp_reference_number) != '' THEN
        
        -- Check if this is a regular task completion (not receiving task)
        -- Regular tasks (like payment tasks) don't need this trigger
        -- This trigger only handles receiving_tasks (inventory manager tasks)
        
        -- Since receiving_tasks is a separate system with its own completion logic,
        -- and regular tasks/task_assignments are separate,
        -- we don't need to do anything here for regular task completions.
        
        -- The receiving tasks have their own completion system via:
        -- complete_receiving_task() function which is called directly
        
        RAISE NOTICE 'ℹ️  Task completion with ERP reference: Task ID %, ERP: %', 
                     NEW.task_id, 
                     TRIM(NEW.erp_reference_number);
        
        -- Note: For payment tasks, the ERP reference sync is handled in the application code
        -- (TaskCompletionModal.svelte) which updates vendor_payment_schedule.payment_reference
        
    END IF;
    
    RETURN NEW;
END;
$function$;

-- Keep the trigger (it won't cause issues now)
-- The trigger remains but does nothing harmful - just logs
-- This way we don't break any existing functionality

COMMENT ON FUNCTION trigger_sync_erp_reference_on_task_completion IS 
'Trigger function for task completions with ERP references. Note: Receiving tasks use their own completion system (complete_receiving_task), and payment tasks sync is handled in the application layer.';
