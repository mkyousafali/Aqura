-- Migration: Create submit_quick_task_completion function
-- File: 79_create_submit_quick_task_completion.sql
-- Description: Creates the function to submit quick task completions from the web interface

BEGIN;

-- Create the submit_quick_task_completion function
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
AS $$
DECLARE
    v_quick_task_id uuid;
    v_completion_id uuid;
    v_existing_completion_id uuid;
BEGIN
    -- Get the quick_task_id from the assignment
    SELECT quick_task_id INTO v_quick_task_id
    FROM quick_task_assignments
    WHERE id = p_assignment_id;

    IF v_quick_task_id IS NULL THEN
        RAISE EXCEPTION 'Assignment not found';
    END IF;

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

    -- Update assignment status to completed
    UPDATE quick_task_assignments
    SET
        status = 'completed',
        completed_at = now(),
        updated_at = now()
    WHERE id = p_assignment_id;

    -- Update quick_task status if all assignments are completed
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
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.submit_quick_task_completion(uuid, uuid, text, text[], text) TO authenticated;

COMMIT;
