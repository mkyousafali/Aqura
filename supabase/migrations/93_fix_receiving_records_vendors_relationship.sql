-- Migration: Fix receiving_records to vendors foreign key relationship
-- File: 93_fix_receiving_records_vendors_relationship.sql
-- Description: Fixes the foreign key relationship between receiving_records and vendors after composite key changes

BEGIN;

-- First, let's check and fix the receiving_records table structure
-- The issue is that receiving_records.vendor_id references vendors.erp_vendor_id
-- but vendors now has a composite constraint on (erp_vendor_id, branch_id)

-- Check if the foreign key exists and what it references
DO $$
BEGIN
    -- Drop the existing foreign key constraint if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'receiving_records_vendor_id_fkey' 
        AND table_name = 'receiving_records'
    ) THEN
        ALTER TABLE receiving_records 
        DROP CONSTRAINT receiving_records_vendor_id_fkey;
        RAISE NOTICE 'Dropped existing receiving_records_vendor_id_fkey constraint';
    END IF;

    -- Note: We cannot create a simple foreign key constraint anymore because vendors 
    -- now allows the same erp_vendor_id in different branches (composite unique constraint)
    -- Instead, we'll rely on the trigger validate_vendor_branch_match() for data integrity
    RAISE NOTICE 'No foreign key constraint created - using trigger validation instead';
    RAISE NOTICE 'Data integrity maintained by validate_vendor_branch_match() trigger';
END $$;

-- Update the validation trigger to properly handle the composite constraint
-- This trigger ensures that when creating/updating receiving records,
-- the vendor belongs to the selected branch (or is unassigned)
CREATE OR REPLACE FUNCTION validate_vendor_branch_match()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if vendor belongs to the selected branch or is unassigned
    IF NOT EXISTS (
        SELECT 1 FROM vendors 
        WHERE erp_vendor_id = NEW.vendor_id 
        AND (branch_id = NEW.branch_id OR branch_id IS NULL)
    ) THEN
        RAISE EXCEPTION 'Vendor % does not belong to branch % or is not assigned to any branch', 
            NEW.vendor_id, NEW.branch_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS validate_vendor_branch_trigger ON receiving_records;
CREATE TRIGGER validate_vendor_branch_trigger
    BEFORE INSERT OR UPDATE ON receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION validate_vendor_branch_match();

-- Add a helpful function to get vendor details for receiving records
CREATE OR REPLACE FUNCTION get_vendor_for_receiving_record(
    vendor_id_param INTEGER,
    branch_id_param BIGINT
)
RETURNS TABLE(
    erp_vendor_id INTEGER,
    vendor_name TEXT,
    vat_number TEXT,
    salesman_name TEXT,
    salesman_contact TEXT,
    branch_id BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.erp_vendor_id,
        v.vendor_name,
        v.vat_number,
        v.salesman_name,
        v.salesman_contact,
        v.branch_id
    FROM vendors v
    WHERE v.erp_vendor_id = vendor_id_param
    AND (v.branch_id = branch_id_param OR v.branch_id IS NULL)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON FUNCTION validate_vendor_branch_match() IS 
'Validates that vendor belongs to the branch specified in receiving record';

COMMENT ON FUNCTION get_vendor_for_receiving_record(INTEGER, BIGINT) IS 
'Gets vendor details for a receiving record, ensuring branch compatibility';

COMMIT;

-- Verification queries
SELECT 'Fixed receiving_records to vendors relationship' AS status;

-- Show the current foreign key constraints on receiving_records
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage ccu 
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'receiving_records'
AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.constraint_name;