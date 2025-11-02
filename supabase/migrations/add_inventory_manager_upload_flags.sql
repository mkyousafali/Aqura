-- =====================================================
-- ADD INVENTORY MANAGER UPLOAD FLAGS TO RECEIVING_RECORDS
-- =====================================================
-- Purpose: Add boolean flags to track uploads for Inventory Manager tasks
-- =====================================================

-- Add boolean columns to track upload status
ALTER TABLE public.receiving_records 
ADD COLUMN IF NOT EXISTS erp_purchase_invoice_uploaded BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS pr_excel_file_uploaded BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS original_bill_uploaded BOOLEAN DEFAULT FALSE;

-- Add indexes for the new boolean columns
CREATE INDEX IF NOT EXISTS idx_receiving_records_erp_purchase_invoice_uploaded 
  ON public.receiving_records USING btree (erp_purchase_invoice_uploaded) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_pr_excel_file_uploaded 
  ON public.receiving_records USING btree (pr_excel_file_uploaded) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_records_original_bill_uploaded 
  ON public.receiving_records USING btree (original_bill_uploaded) 
  TABLESPACE pg_default;

-- Add comments
COMMENT ON COLUMN public.receiving_records.erp_purchase_invoice_uploaded IS 
  'Boolean flag indicating if ERP purchase invoice reference has been entered by Inventory Manager';

COMMENT ON COLUMN public.receiving_records.pr_excel_file_uploaded IS 
  'Boolean flag indicating if PR Excel file has been uploaded by Inventory Manager';

COMMENT ON COLUMN public.receiving_records.original_bill_uploaded IS 
  'Boolean flag indicating if original bill has been uploaded by Inventory Manager';

-- Update existing records where URLs exist to set flags to true
UPDATE public.receiving_records 
SET 
  erp_purchase_invoice_uploaded = CASE 
    WHEN erp_purchase_invoice_reference IS NOT NULL AND erp_purchase_invoice_reference != '' THEN TRUE 
    ELSE FALSE 
  END,
  pr_excel_file_uploaded = CASE 
    WHEN pr_excel_file_url IS NOT NULL AND pr_excel_file_url != '' THEN TRUE 
    ELSE FALSE 
  END,
  original_bill_uploaded = CASE 
    WHEN original_bill_url IS NOT NULL AND original_bill_url != '' THEN TRUE 
    ELSE FALSE 
  END;

-- Verification
DO $$
DECLARE
  column_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO column_count
  FROM information_schema.columns 
  WHERE table_name = 'receiving_records' 
  AND column_name IN ('erp_purchase_invoice_uploaded', 'pr_excel_file_uploaded', 'original_bill_uploaded');
  
  IF column_count = 3 THEN
    RAISE NOTICE '✅ Successfully added 3 upload flag columns to receiving_records';
  ELSE
    RAISE EXCEPTION '❌ Expected 3 columns, found %', column_count;
  END IF;
END $$;