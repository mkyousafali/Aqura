-- =====================================================
-- DEBUG VERSION OF PHOTO FUNCTION
-- =====================================================
-- Create a simpler version with more debugging
-- =====================================================

CREATE OR REPLACE FUNCTION debug_get_dependency_photos(
  receiving_record_id_param UUID,
  dependency_role_types TEXT[]
)
RETURNS JSON AS $$
DECLARE
  result_photos JSONB := '{}'::JSONB;
  role_type TEXT;
  task_record RECORD;
  found_count INTEGER := 0;
BEGIN
  RAISE NOTICE 'Debug: Starting function with receiving_record_id = %, roles = %', receiving_record_id_param, dependency_role_types;
  
  -- Loop through each dependency role type
  FOREACH role_type IN ARRAY dependency_role_types
  LOOP
    RAISE NOTICE 'Debug: Looking for role_type = %', role_type;
    
    -- Get the completion photo for this role type
    SELECT completion_photo_url, role_type as task_role_type INTO task_record
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = role_type
      AND task_completed = true
      AND completion_photo_url IS NOT NULL
    LIMIT 1;
    
    IF FOUND THEN
      found_count := found_count + 1;
      RAISE NOTICE 'Debug: Found task with photo for role %, URL = %', role_type, task_record.completion_photo_url;
      
      result_photos := result_photos || jsonb_build_object(
        task_record.task_role_type, task_record.completion_photo_url
      );
    ELSE
      RAISE NOTICE 'Debug: No photo found for role %', role_type;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Debug: Found % photos, returning %', found_count, result_photos;
  
  -- Convert JSONB to JSON for return
  RETURN result_photos::JSON;
  
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Debug: Error occurred - %', SQLERRM;
  RETURN '{}'::JSON;
END;
$$ LANGUAGE plpgsql;

-- Test the debug version
SELECT debug_get_dependency_photos(
    '64dae86d-efc8-423f-ada2-0cebb0f46490'::UUID,
    ARRAY['shelf_stocker']
) as debug_result;