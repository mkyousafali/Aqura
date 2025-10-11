-- Add VAT number column to branches table
-- This migration adds VAT information support for branches

-- Add VAT number column to branches table
ALTER TABLE public.branches 
ADD COLUMN IF NOT EXISTS vat_number CHARACTER VARYING(50) NULL;

-- Add comment for the new column
COMMENT ON COLUMN public.branches.vat_number IS 'VAT registration number for the branch';

-- Create index for VAT number for efficient queries
CREATE INDEX IF NOT EXISTS idx_branches_vat_number 
ON public.branches USING btree (vat_number) 
WHERE vat_number IS NOT NULL;

-- Add constraint to ensure VAT number format (optional - can be customized)
-- This constraint ensures VAT number is not empty string if provided
ALTER TABLE public.branches 
ADD CONSTRAINT check_vat_number_not_empty 
CHECK (vat_number IS NULL OR LENGTH(TRIM(vat_number)) > 0);

-- Migration completed
SELECT 'VAT number column added to branches table successfully' AS result;