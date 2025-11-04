-- =====================================================
-- FIX GET_DEPENDENCY_COMPLETION_PHOTOS FUNCTION
-- =====================================================
-- Fix variable name conflict that was preventing photo lookup
-- =====================================================

CREATE OR REPLACE FUNCTION get_dependency_completion_photos(
  receiving_record_id_param UUID,
  dependency_role_types TEXT[]
)
RETURNS JSON AS $$
DECLARE
  result_photos JSONB := '{}'::JSONB;
  current_role_type TEXT;
  task_record RECORD;
BEGIN
  -- Loop through each dependency role type
  FOREACH current_role_type IN ARRAY dependency_role_types
  LOOP
    -- Get the completion photo for this role type
    SELECT completion_photo_url, role_type INTO task_record
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = current_role_type
      AND task_completed = true
      AND completion_photo_url IS NOT NULL
    LIMIT 1;
    
    -- If photo exists, add it to the result
    IF FOUND AND task_record.completion_photo_url IS NOT NULL THEN
      result_photos := result_photos || jsonb_build_object(
        current_role_type, task_record.completion_photo_url
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

-- Test the function with our known data
SELECT get_dependency_completion_photos(
  '64dae86d-efc8-423f-ada2-0cebb0f46490'::UUID, 
  ARRAY['shelf_stocker']
) as test_result;

-- Also test with the exact call that would happen in the frontend
SELECT get_dependency_completion_photos(
  '64dae86d-efc8-423f-ada2-0cebb0f46490'::UUID, 
  ARRAY['shelf_stocker', 'warehouse_handler']
) as test_result_multiple;