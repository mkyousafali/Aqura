-- ============================================================
-- FIX: Add proper validation for quick task completion requirements
-- ============================================================

-- Drop the existing overloaded versions
DROP FUNCTION IF EXISTS public.submit_quick_task_completion(uuid, text, text, text);
DROP FUNCTION IF EXISTS public.submit_quick_task_completion(uuid, uuid, text, text[], text);

-- Create a single, properly validated version
CREATE OR REPLACE FUNCTION public.submit_quick_task_completion(
    p_assignment_id uuid,
    p_user_id uuid,
    p_completion_notes text DEFAULT NULL,
    p_photos text[] DEFAULT NULL,
    p_erp_reference text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_quick_task_id uuid;
    v_completion_id uuid;
    v_existing_completion_id uuid;
    v_require_photo boolean;
    v_require_erp boolean;
    v_assignment_record RECORD;
BEGIN
    -- Get the assignment details including requirements
    SELECT 
        qta.quick_task_id,
        qta.require_photo_upload,
        qta.require_erp_reference,
        qta.status
    INTO v_assignment_record
    FROM quick_task_assignments qta
    WHERE qta.id = p_assignment_id;

    -- Check if assignment exists
    IF v_assignment_record.quick_task_id IS NULL THEN
        RAISE EXCEPTION 'Assignment not found with ID: %', p_assignment_id;
    END IF;

    -- Check if assignment is already completed
    IF v_assignment_record.status = 'completed' THEN
        RAISE EXCEPTION 'This assignment is already completed';
    END IF;

    v_quick_task_id := v_assignment_record.quick_task_id;
    v_require_photo := v_assignment_record.require_photo_upload;
    v_require_erp := v_assignment_record.require_erp_reference;

    -- ====================================================================
    -- VALIDATE COMPLETION REQUIREMENTS
    -- ====================================================================
    
    -- Check if photo is required but not provided
    IF v_require_photo = true AND (p_photos IS NULL OR array_length(p_photos, 1) IS NULL OR array_length(p_photos, 1) = 0) THEN
        RAISE EXCEPTION 'Photo upload is required for this task. Please upload at least one photo before completing.';
    END IF;
    
    -- Check if ERP reference is required but not provided
    IF v_require_erp = true AND (p_erp_reference IS NULL OR trim(p_erp_reference) = '') THEN
        RAISE EXCEPTION 'ERP reference is required for this task. Please provide an ERP reference before completing.';
    END IF;

    -- ====================================================================
    -- CREATE OR UPDATE COMPLETION RECORD
    -- ====================================================================

    -- Check if completion already exists
    SELECT id INTO v_existing_completion_id
    FROM quick_task_completions
    WHERE assignment_id = p_assignment_id;

    IF v_existing_completion_id IS NOT NULL THEN
        -- Update existing completion
        UPDATE quick_task_completions
        SET
            completion_notes = COALESCE(p_completion_notes, completion_notes),
            photo_path = COALESCE(array_to_string(p_photos, ','), photo_path),
            erp_reference = COALESCE(p_erp_reference, erp_reference),
            updated_at = now()
        WHERE id = v_existing_completion_id;

        v_completion_id := v_existing_completion_id;
    ELSE
        -- Create new completion record
        INSERT INTO quick_task_completions (
            quick_task_id,
            assignment_id,
            completed_by_user_id,
            completion_notes,
            photo_path,
            erp_reference,
            completion_status
        ) VALUES (
            v_quick_task_id,
            p_assignment_id,
            p_user_id,
            p_completion_notes,
            array_to_string(p_photos, ','),
            p_erp_reference,
            'submitted'
        )
        RETURNING id INTO v_completion_id;
    END IF;

    -- ====================================================================
    -- UPDATE ASSIGNMENT STATUS
    -- ====================================================================

    UPDATE quick_task_assignments
    SET
        status = 'completed',
        completed_at = now(),
        updated_at = now()
    WHERE id = p_assignment_id;

    -- ====================================================================
    -- UPDATE QUICK TASK STATUS IF ALL ASSIGNMENTS COMPLETED
    -- ====================================================================

    UPDATE quick_tasks
    SET
        status = CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM quick_task_assignments
                WHERE quick_task_id = v_quick_task_id
                AND status != 'completed'
            ) THEN 'completed'
            ELSE status
        END,
        completed_at = CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM quick_task_assignments
                WHERE quick_task_id = v_quick_task_id
                AND status != 'completed'
            ) THEN now()
            ELSE completed_at
        END,
        updated_at = now()
    WHERE id = v_quick_task_id;

    RETURN v_completion_id;
END;
$function$;

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.submit_quick_task_completion(uuid, uuid, text, text[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_quick_task_completion(uuid, uuid, text, text[], text) TO service_role;

-- ============================================================
-- NOTES:
-- ============================================================
-- This function now properly validates:
-- 1. Photo upload requirement (checks if array has at least one photo)
-- 2. ERP reference requirement (checks if reference is provided and not empty)
-- 3. Assignment exists and is not already completed
-- 
-- The function will throw clear error messages if requirements are not met,
-- which will be caught by the frontend and displayed to the user.
-- ============================================================
