-- ============================================================
-- FIX FOR ACCOUNTANT TASK COMPLETION ISSUE
-- ============================================================
-- Problem: Function checks if inventory_manager TASK is completed
--          But should only check if REQUIRED FILES are uploaded
-- Solution: Remove inventory_manager task check, only verify files
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_accountant_dependency(receiving_record_id_param uuid)
RETURNS json
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
    RETURN json_build_object(
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
      RETURN json_build_object(
        'can_complete', false,
        'error', 'Missing required files: ' || array_to_string(missing_files, ', ') || '. Please ensure all files are uploaded before completing this task.',
        'error_code', 'REQUIRED_FILES_NOT_UPLOADED',
        'message', 'Missing required files: ' || array_to_string(missing_files, ', ') || '. Please ensure all files are uploaded before completing this task.',
        'missing_files', missing_files
      );
    END IF;
  END;

  -- All checks passed - both files are uploaded
  RETURN json_build_object(
    'can_complete', true,
    'message', 'All required files uploaded. Accountant can proceed.',
    'original_bill_url', receiving_record.original_bill_url,
    'pr_excel_file_url', receiving_record.pr_excel_file_url
  );
END;
$function$;

-- ============================================================
-- EXPLANATION OF CHANGES:
-- ============================================================
-- ❌ REMOVED: Check for inventory_manager task existence/completion
-- ✅ ADDED: Check for pr_excel_file_uploaded flag and URL
-- ✅ KEPT: Check for original_bill_uploaded flag and URL
-- ✅ IMPROVED: Better error messages listing which files are missing
-- 
-- BUSINESS LOGIC:
-- Accountant can complete their task when BOTH:
-- 1. Original Bill is uploaded (flag = true, URL exists)
-- 2. PR Excel is uploaded (flag = true, URL exists)
-- 
-- No longer depends on whether inventory_manager task exists!
-- ============================================================

-- Test the fix (optional - you can run this to verify)
-- SELECT check_accountant_dependency('7cfa516e-4974-40b0-91db-a2c74783e532');
-- SELECT check_accountant_dependency('79913f8f-ca82-4482-8c22-5a84ac06f0a0');
