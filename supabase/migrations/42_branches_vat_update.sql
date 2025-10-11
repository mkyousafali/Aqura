-- Migration: Add VAT number support to branches table
-- File: 42_branches_vat_update.sql
-- Description: Adds VAT number column to branches table with proper constraints and indexing

BEGIN;

-- Add VAT number column to branches table
ALTER TABLE public.branches 
ADD COLUMN IF NOT EXISTS vat_number CHARACTER VARYING(50) NULL;

-- Add comment for documentation
COMMENT ON COLUMN public.branches.vat_number IS 'VAT registration number for the branch - optional field for tax identification';

-- Create index for efficient VAT number queries
CREATE INDEX IF NOT EXISTS idx_branches_vat_number 
ON public.branches USING btree (vat_number) 
WHERE vat_number IS NOT NULL;

-- Add constraint to ensure VAT number is not empty if provided
ALTER TABLE public.branches 
ADD CONSTRAINT IF NOT EXISTS check_vat_number_not_empty 
CHECK (vat_number IS NULL OR LENGTH(TRIM(vat_number)) > 0);

-- Add constraint to ensure VAT number format (basic validation)
ALTER TABLE public.branches 
ADD CONSTRAINT IF NOT EXISTS check_vat_number_format 
CHECK (vat_number IS NULL OR vat_number ~ '^[A-Za-z0-9\-\s]+$');

-- Update any existing branches with empty VAT numbers to NULL
UPDATE public.branches 
SET vat_number = NULL 
WHERE vat_number IS NOT NULL AND LENGTH(TRIM(vat_number)) = 0;

COMMIT;

-- Verification query
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'branches' 
AND column_name = 'vat_number';

-- Success message
SELECT 'VAT number column successfully added to branches table with constraints and indexing' AS migration_result;