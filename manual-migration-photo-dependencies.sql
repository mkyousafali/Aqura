-- =====================================================
-- RECEIVING TASKS PHOTO UPLOAD AND DEPENDENCIES
-- =====================================================
-- Purpose: Add photo upload requirements and task dependencies
-- Changes:
--   1. Add completion_photo_url to receiving_tasks
--   2. Add depends_on_role_types to receiving_task_templates
--   3. Update templates with dependency rules
--   4. Add validation constraints
-- =====================================================

-- =====================================================
-- STEP 1: ADD PHOTO SUPPORT TO RECEIVING_TASKS
-- =====================================================

-- Add completion photo URL column
ALTER TABLE public.receiving_tasks 
  ADD COLUMN IF NOT EXISTS completion_photo_url TEXT NULL;

-- Add index for photo URL lookups
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_completion_photo_url 
  ON public.receiving_tasks USING btree (completion_photo_url) 
  WHERE completion_photo_url IS NOT NULL;

-- Add comments
COMMENT ON COLUMN public.receiving_tasks.completion_photo_url IS 
  'URL of completion photo uploaded by user (required for shelf_stocker role)';

-- =====================================================
-- STEP 2: ADD DEPENDENCIES TO TEMPLATES
-- =====================================================

-- Add dependency support to task templates
ALTER TABLE public.receiving_task_templates 
  ADD COLUMN IF NOT EXISTS depends_on_role_types TEXT[] DEFAULT '{}';

-- Add require_photo_upload column to templates
ALTER TABLE public.receiving_task_templates 
  ADD COLUMN IF NOT EXISTS require_photo_upload BOOLEAN DEFAULT FALSE;

-- Add comments
COMMENT ON COLUMN public.receiving_task_templates.depends_on_role_types IS 
  'Array of role types that must complete their tasks before this role can complete theirs';

COMMENT ON COLUMN public.receiving_task_templates.require_photo_upload IS 
  'Whether this role must upload a completion photo';

-- =====================================================
-- STEP 3: UPDATE SPECIFIC TEMPLATES WITH REQUIREMENTS
-- =====================================================

-- Update shelf_stocker template to require photo upload
UPDATE public.receiving_task_templates 
SET 
  require_photo_upload = TRUE,
  depends_on_role_types = '{}' -- Shelf stocker has no dependencies
WHERE role_type = 'shelf_stocker';

-- Update branch_manager to depend on shelf_stocker
UPDATE public.receiving_task_templates 
SET 
  depends_on_role_types = '{"shelf_stocker"}',
  require_photo_upload = FALSE
WHERE role_type = 'branch_manager';

-- Update night_supervisor to depend on shelf_stocker  
UPDATE public.receiving_task_templates 
SET 
  depends_on_role_types = '{"shelf_stocker"}',
  require_photo_upload = FALSE
WHERE role_type = 'night_supervisor';

-- Keep other roles independent (no dependencies)
UPDATE public.receiving_task_templates 
SET 
  depends_on_role_types = '{}',
  require_photo_upload = FALSE
WHERE role_type IN ('purchase_manager', 'inventory_manager', 'warehouse_handler', 'accountant');

-- =====================================================
-- STEP 4: CREATE DEPENDENCY VALIDATION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION check_receiving_task_dependencies(
  receiving_record_id_param UUID,
  role_type_param TEXT
)
RETURNS JSON AS $$
DECLARE
  v_template RECORD;
  v_dependency TEXT;
  v_dependency_completed BOOLEAN;
  v_blocking_roles TEXT[] := '{}';
  v_completed_dependencies TEXT[] := '{}';
BEGIN
  
  -- Get template for this role
  SELECT * INTO v_template
  FROM receiving_task_templates
  WHERE role_type = role_type_param;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Template not found for role type',
      'can_complete', false
    );
  END IF;
  
  -- If no dependencies, can complete
  IF v_template.depends_on_role_types IS NULL OR array_length(v_template.depends_on_role_types, 1) IS NULL THEN
    RETURN json_build_object(
      'success', true,
      'can_complete', true,
      'blocking_roles', '{}',
      'completed_dependencies', '{}'
    );
  END IF;
  
  -- Check each dependency
  FOREACH v_dependency IN ARRAY v_template.depends_on_role_types LOOP
    
    -- Check if dependency role task is completed
    SELECT task_completed INTO v_dependency_completed
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = v_dependency
      AND task_completed = true;
    
    IF v_dependency_completed IS TRUE THEN
      v_completed_dependencies := array_append(v_completed_dependencies, v_dependency);
    ELSE
      v_blocking_roles := array_append(v_blocking_roles, v_dependency);
    END IF;
    
  END LOOP;
  
  -- Return dependency status
  RETURN json_build_object(
    'success', true,
    'can_complete', array_length(v_blocking_roles, 1) IS NULL,
    'blocking_roles', v_blocking_roles,
    'completed_dependencies', v_completed_dependencies,
    'total_dependencies', array_length(v_template.depends_on_role_types, 1)
  );
  
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- STEP 5: CREATE FUNCTION TO GET DEPENDENCY PHOTOS
-- =====================================================

CREATE OR REPLACE FUNCTION get_dependency_completion_photos(
  receiving_record_id_param UUID,
  dependency_role_types TEXT[]
)
RETURNS JSON AS $$
DECLARE
  v_photos JSON := '{}';
  v_role TEXT;
  v_photo_url TEXT;
BEGIN
  
  -- Loop through each dependency role
  FOREACH v_role IN ARRAY dependency_role_types LOOP
    
    -- Get completion photo for this role
    SELECT completion_photo_url INTO v_photo_url
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = v_role
      AND task_completed = true
      AND completion_photo_url IS NOT NULL;
    
    -- Add to photos object if found
    IF v_photo_url IS NOT NULL THEN
      v_photos := v_photos || json_build_object(v_role, v_photo_url);
    END IF;
    
  END LOOP;
  
  RETURN v_photos;
  
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- STEP 6: GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION check_receiving_task_dependencies TO authenticated;
GRANT EXECUTE ON FUNCTION check_receiving_task_dependencies TO service_role;
GRANT EXECUTE ON FUNCTION get_dependency_completion_photos TO authenticated;
GRANT EXECUTE ON FUNCTION get_dependency_completion_photos TO service_role;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Verify schema changes
DO $$
DECLARE
  column_exists BOOLEAN;
BEGIN
  -- Check if completion_photo_url column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receiving_tasks' 
    AND column_name = 'completion_photo_url'
  ) INTO column_exists;
  
  IF column_exists THEN
    RAISE NOTICE '✅ completion_photo_url column added successfully';
  ELSE
    RAISE EXCEPTION '❌ completion_photo_url column not found';
  END IF;
  
  -- Check if dependency columns exist
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receiving_task_templates' 
    AND column_name = 'depends_on_role_types'
  ) INTO column_exists;
  
  IF column_exists THEN
    RAISE NOTICE '✅ depends_on_role_types column added successfully';
  ELSE
    RAISE EXCEPTION '❌ depends_on_role_types column not found';
  END IF;
  
  -- Check template updates
  IF EXISTS (
    SELECT 1 FROM receiving_task_templates 
    WHERE role_type = 'shelf_stocker' 
    AND require_photo_upload = true
  ) THEN
    RAISE NOTICE '✅ shelf_stocker template updated to require photo';
  ELSE
    RAISE EXCEPTION '❌ shelf_stocker template not updated correctly';
  END IF;
  
  RAISE NOTICE '🎉 All schema changes applied successfully!';
END $$;

-- Display updated templates
SELECT 
  role_type,
  require_photo_upload,
  depends_on_role_types,
  deadline_hours
FROM receiving_task_templates 
ORDER BY 
  CASE role_type
    WHEN 'shelf_stocker' THEN 1
    WHEN 'branch_manager' THEN 2
    WHEN 'night_supervisor' THEN 3
    ELSE 4
  END;