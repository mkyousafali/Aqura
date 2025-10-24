-- Migration: Restore branch IDs for existing task assignments
-- File: 77_restore_task_branch_ids.sql
-- Description: Updates existing task_assignments to set branch_id from receiving_records

BEGIN;

-- First, let's create a temporary function to extract UUID from task description
CREATE OR REPLACE FUNCTION extract_receiving_record_id(description TEXT)
RETURNS UUID AS $$
DECLARE
    uuid_pattern TEXT := '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}';
    extracted_uuid TEXT;
BEGIN
    -- Extract UUID pattern from description
    extracted_uuid := (SELECT (regexp_matches(description, uuid_pattern, 'i'))[1]);
    
    -- Return as UUID or NULL if not found
    IF extracted_uuid IS NOT NULL THEN
        RETURN extracted_uuid::UUID;
    ELSE
        RETURN NULL;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Update task_assignments with correct branch_id from receiving_records
UPDATE public.task_assignments ta
SET assigned_to_branch_id = rr.branch_id
FROM public.tasks t
LEFT JOIN public.receiving_records rr ON rr.id = extract_receiving_record_id(t.description)
WHERE ta.task_id = t.id
AND ta.assigned_to_branch_id IS NULL
AND rr.branch_id IS NOT NULL;

-- Drop the temporary function
DROP FUNCTION IF EXISTS extract_receiving_record_id(TEXT);

-- Log the results
DO $$
DECLARE
    total_count INTEGER;
    null_count INTEGER;
    with_branch_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_count FROM task_assignments;
    SELECT COUNT(*) INTO null_count FROM task_assignments WHERE assigned_to_branch_id IS NULL;
    with_branch_count := total_count - null_count;
    
    RAISE NOTICE 'Total task_assignments: %', total_count;
    RAISE NOTICE 'With branch_id: %', with_branch_count;
    RAISE NOTICE 'Still NULL: %', null_count;
END $$;

COMMIT;
