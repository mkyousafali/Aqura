-- ============================================================
-- FIX FOR SQL ERROR: "operator does not exist: json ? unknown"
-- ============================================================
-- The complete_receiving_task function uses the ? operator
-- which only works with JSONB, not JSON
-- We need to change the return type from JSON to JSONB
-- ============================================================

-- Step 1: Drop the existing function (required to change return type)
DROP FUNCTION IF EXISTS public.check_accountant_dependency(uuid);

-- Step 2: Recreate with JSONB return type
CREATE OR REPLACE FUNCTION public.check_accountant_dependency(receiving_record_id_param uuid)
RETURNS jsonb  -- Changed from json to jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  receiving_record RECORD;
BEGIN
  -- Get the receiving record to check file upload status
  SELECT * INTO receiving_record
  FROM receiving_records 
  WHERE id = receiving_record_id_param;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(  -- Changed from json_build_object
      'can_complete', false,
      'error', 'Receiving record not found',
      'error_code', 'RECORD_NOT_FOUND'
    );
  END IF;

  -- Build list of missing files
  DECLARE
    missing_files TEXT[] := ARRAY[]::TEXT[];
  BEGIN
    -- Check if Original Bill is uploaded
    IF receiving_record.original_bill_uploaded IS NULL OR 
       receiving_record.original_bill_uploaded = false OR 
       receiving_record.original_bill_url IS NULL OR 
       receiving_record.original_bill_url = '' THEN
      missing_files := array_append(missing_files, 'Original Bill');
    END IF;

    -- Check if PR Excel is uploaded
    IF receiving_record.pr_excel_file_uploaded IS NULL OR 
       receiving_record.pr_excel_file_uploaded = false OR 
       receiving_record.pr_excel_file_url IS NULL OR 
       receiving_record.pr_excel_file_url = '' THEN
      missing_files := array_append(missing_files, 'PR Excel File');
    END IF;

    -- If any files are missing, block completion
    IF array_length(missing_files, 1) > 0 THEN
      RETURN jsonb_build_object(  -- Changed from json_build_object
        'can_complete', false,
        'error', 'Missing required files: ' || array_to_string(missing_files, ', ') || '. Please ensure all files are uploaded before completing this task.',
        'error_code', 'REQUIRED_FILES_NOT_UPLOADED',
        'message', 'Missing required files: ' || array_to_string(missing_files, ', ') || '. Please ensure all files are uploaded before completing this task.',
        'missing_files', missing_files
      );
    END IF;
  END;

  -- All checks passed - both files are uploaded
  RETURN jsonb_build_object(  -- Changed from json_build_object
    'can_complete', true,
    'message', 'All required files uploaded. Accountant can proceed.',
    'original_bill_url', receiving_record.original_bill_url,
    'pr_excel_file_url', receiving_record.pr_excel_file_url
  );
END;
$function$;

-- ============================================================
-- CHANGES MADE:
-- 1. Return type: json → jsonb
-- 2. All json_build_object → jsonb_build_object
-- 3. Logic remains the same (checks files, not tasks)
-- ============================================================
