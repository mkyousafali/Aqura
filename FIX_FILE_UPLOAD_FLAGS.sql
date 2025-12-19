-- SQL Script to retroactively update pr_excel_file_uploaded and original_bill_uploaded flags
-- This fixes records where files exist (have URLs) but the boolean flags are still false
-- This was needed because some files were uploaded before the flags were properly tracked

BEGIN;

-- Update records where PR Excel file URL exists but the uploaded flag is false
UPDATE receiving_records
SET pr_excel_file_uploaded = true
WHERE pr_excel_file_url IS NOT NULL 
  AND pr_excel_file_url != ''
  AND pr_excel_file_uploaded = false;

-- Update records where Original Bill URL exists but the uploaded flag is false
UPDATE receiving_records
SET original_bill_uploaded = true
WHERE original_bill_url IS NOT NULL 
  AND original_bill_url != ''
  AND original_bill_uploaded = false;

-- Log the results
SELECT 
  'Fixed PR Excel File Flags' as operation,
  COUNT(*) as records_updated
FROM receiving_records
WHERE pr_excel_file_url IS NOT NULL 
  AND pr_excel_file_url != ''
  AND pr_excel_file_uploaded = true;

SELECT 
  'Fixed Original Bill Flags' as operation,
  COUNT(*) as records_updated
FROM receiving_records
WHERE original_bill_url IS NOT NULL 
  AND original_bill_url != ''
  AND original_bill_uploaded = true;

COMMIT;
