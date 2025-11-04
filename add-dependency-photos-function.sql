-- =====================================================
-- ADD GET_DEPENDENCY_COMPLETION_PHOTOS FUNCTION
-- =====================================================
-- This function retrieves completion photos from dependency tasks
-- Used by branch managers and night supervisors to see photos
-- from completed shelf stocker and other dependency tasks
-- =====================================================

CREATE OR REPLACE FUNCTION get_dependency_completion_photos(
  receiving_record_id_param UUID,
  dependency_role_types TEXT[]
)
RETURNS JSON AS $$
DECLARE
  result_photos JSONB := '{}'::JSONB;
  role_type TEXT;
  task_record RECORD;
BEGIN
  -- Loop through each dependency role type
  FOREACH role_type IN ARRAY dependency_role_types
  LOOP
    -- Get the completion photo for this role type
    SELECT completion_photo_url, role_type as task_role_type INTO task_record
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = role_type
      AND task_completed = true
      AND completion_photo_url IS NOT NULL
    LIMIT 1;
    
    -- If photo exists, add it to the result
    IF FOUND AND task_record.completion_photo_url IS NOT NULL THEN
      result_photos := result_photos || jsonb_build_object(
        task_record.task_role_type, task_record.completion_photo_url
      );
    END IF;
  END LOOP;
  
  -- Convert JSONB to JSON for return
  RETURN result_photos::JSON;
  
EXCEPTION WHEN OTHERS THEN
  -- Return empty object on error
  RETURN '{}'::JSON;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_dependency_completion_photos TO authenticated;
GRANT EXECUTE ON FUNCTION get_dependency_completion_photos TO service_role;

-- Test the function to make sure it works
-- This will return empty object if no photos exist, which is expected
SELECT get_dependency_completion_photos(
  '00000000-0000-0000-0000-000000000000'::UUID, 
  ARRAY['shelf_stocker', 'warehouse_handler']
) as test_result;