-- Fix check_accountant_dependency function to check URLs instead of boolean flags
-- This function is called by complete_receiving_task for accountant validation

CREATE OR REPLACE FUNCTION public.check_accountant_dependency(receiving_record_id_param UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_receiving_record RECORD;
  missing_files TEXT[];
BEGIN
  -- Get the receiving record
  SELECT * INTO v_receiving_record
  FROM receiving_records
  WHERE id = receiving_record_id_param;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'can_complete', false,
      'error', 'Receiving record not found',
      'error_code', 'RECORD_NOT_FOUND',
      'message', 'Receiving record not found'
    );
  END IF;
  
  missing_files := ARRAY[]::TEXT[];
  
  -- Check if original bill URL exists (not the boolean flag)
  IF v_receiving_record.original_bill_url IS NULL OR 
     TRIM(v_receiving_record.original_bill_url) = '' THEN
    missing_files := array_append(missing_files, 'Original Bill');
  END IF;
  
  -- Check if PR Excel URL exists (not the boolean flag)
  IF v_receiving_record.pr_excel_file_url IS NULL OR 
     TRIM(v_receiving_record.pr_excel_file_url) = '' THEN
    missing_files := array_append(missing_files, 'PR Excel File');
  END IF;
  
  -- If any files are missing, return error
  IF array_length(missing_files, 1) > 0 THEN
    RETURN jsonb_build_object(
      'can_complete', false,
      'error', 'Missing required files: ' || array_to_string(missing_files, ', ') || '. Please ensure all files are uploaded before completing this task.',
      'error_code', 'REQUIRED_FILES_NOT_UPLOADED',
      'message', 'Missing required files: ' || array_to_string(missing_files, ', ') || '. Please ensure all files are uploaded before completing this task.',
      'missing_files', missing_files
    );
  END IF;
  
  -- All files present, accountant can complete
  RETURN jsonb_build_object(
    'can_complete', true,
    'message', 'All required files are uploaded'
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'can_complete', false,
    'error', SQLERRM,
    'error_code', 'INTERNAL_ERROR',
    'message', 'Error checking accountant dependencies: ' || SQLERRM
  );
END;
$$;
