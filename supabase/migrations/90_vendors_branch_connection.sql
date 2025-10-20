-- Migration: Add branch connection to vendors table
-- File: 90_vendors_branch_connection.sql
-- Description: Adds branch_id column to vendors table to make vendor management branch-wise

BEGIN;

-- Add branch_id column to vendors table
ALTER TABLE public.vendors 
ADD COLUMN IF NOT EXISTS branch_id BIGINT NULL;

-- Add foreign key constraint to branches table (drop first if exists)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'vendors_branch_id_fkey' 
        AND table_name = 'vendors'
    ) THEN
        ALTER TABLE public.vendors 
        ADD CONSTRAINT vendors_branch_id_fkey 
        FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create index for efficient branch-based vendor queries
CREATE INDEX IF NOT EXISTS idx_vendors_branch_id 
ON public.vendors USING btree (branch_id) 
WHERE branch_id IS NOT NULL;

-- Create composite index for branch and status queries
CREATE INDEX IF NOT EXISTS idx_vendors_branch_status 
ON public.vendors USING btree (branch_id, status) 
WHERE branch_id IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN public.vendors.branch_id IS 'Branch ID that this vendor belongs to - makes vendor management branch-wise';

-- Update any existing vendors to have NULL branch_id (they will need to be assigned later)
-- This ensures backward compatibility

-- Create a function to get vendors by branch
CREATE OR REPLACE FUNCTION get_vendors_by_branch(branch_id_param BIGINT DEFAULT NULL)
RETURNS TABLE(
    erp_vendor_id INTEGER,
    vendor_name TEXT,
    salesman_name TEXT,
    vendor_contact_number TEXT,
    payment_method TEXT,
    status TEXT,
    branch_id BIGINT,
    categories TEXT[],
    delivery_modes TEXT[],
    place TEXT,
    vat_number TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) AS $$
BEGIN
    IF branch_id_param IS NULL THEN
        -- Return all vendors if no branch specified
        RETURN QUERY
        SELECT 
            v.erp_vendor_id,
            v.vendor_name,
            v.salesman_name,
            v.vendor_contact_number,
            v.payment_method,
            v.status,
            v.branch_id,
            v.categories,
            v.delivery_modes,
            v.place,
            v.vat_number,
            v.created_at,
            v.updated_at
        FROM vendors v
        ORDER BY v.vendor_name;
    ELSE
        -- Return vendors for specific branch
        RETURN QUERY
        SELECT 
            v.erp_vendor_id,
            v.vendor_name,
            v.salesman_name,
            v.vendor_contact_number,
            v.payment_method,
            v.status,
            v.branch_id,
            v.categories,
            v.delivery_modes,
            v.place,
            v.vat_number,
            v.created_at,
            v.updated_at
        FROM vendors v
        WHERE v.branch_id = branch_id_param
        ORDER BY v.vendor_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create a function to get vendor count by branch
CREATE OR REPLACE FUNCTION get_vendor_count_by_branch()
RETURNS TABLE(
    branch_id BIGINT,
    branch_name TEXT,
    vendor_count BIGINT,
    active_vendor_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id as branch_id,
        b.name_en as branch_name,
        COUNT(v.erp_vendor_id) as vendor_count,
        COUNT(CASE WHEN v.status = 'Active' THEN 1 END) as active_vendor_count
    FROM branches b
    LEFT JOIN vendors v ON b.id = v.branch_id
    GROUP BY b.id, b.name_en
    ORDER BY b.name_en;
END;
$$ LANGUAGE plpgsql;

-- Update the receiving_records table foreign key to handle branch-wise vendors
-- This ensures that when creating receiving records, we can validate vendor belongs to selected branch
DO $$ 
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'receiving_records_vendor_id_fkey' 
        AND table_name = 'receiving_records'
    ) THEN
        ALTER TABLE public.receiving_records 
        DROP CONSTRAINT receiving_records_vendor_id_fkey;
    END IF;
    
    -- Add the constraint back
    ALTER TABLE public.receiving_records 
    ADD CONSTRAINT receiving_records_vendor_id_fkey 
    FOREIGN KEY (vendor_id) REFERENCES public.vendors(erp_vendor_id) ON DELETE RESTRICT;
END $$;

-- Create a validation function for receiving records
CREATE OR REPLACE FUNCTION validate_vendor_branch_match()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if vendor belongs to the selected branch
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

-- Create trigger to validate vendor-branch relationship on receiving records
DROP TRIGGER IF EXISTS validate_vendor_branch_trigger ON receiving_records;
CREATE TRIGGER validate_vendor_branch_trigger
    BEFORE INSERT OR UPDATE ON receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION validate_vendor_branch_match();

COMMIT;

-- Verification queries
SELECT 'Migration completed successfully' AS status;

-- Show updated vendor table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'vendors' 
AND column_name IN ('erp_vendor_id', 'vendor_name', 'branch_id')
ORDER BY ordinal_position;