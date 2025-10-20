-- Migration: Allow same vendor ID in different branches
-- File: 91_allow_same_vendor_id_different_branches.sql
-- Description: Modifies vendor table constraints to allow same ERP vendor ID in different branches

BEGIN;

-- Step 1: Drop existing unique constraint on erp_vendor_id if it exists (not primary key)
DO $$ 
BEGIN
    -- Check if unique constraint exists on erp_vendor_id alone (not primary key)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'vendors' 
        AND tc.constraint_type = 'UNIQUE'
        AND kcu.column_name = 'erp_vendor_id'
        AND NOT EXISTS (
            SELECT 1 FROM information_schema.key_column_usage kcu2
            WHERE kcu2.constraint_name = kcu.constraint_name
            AND kcu2.column_name != 'erp_vendor_id'
        )
    ) THEN
        -- Find and drop the constraint
        DECLARE
            constraint_name_var TEXT;
        BEGIN
            SELECT tc.constraint_name INTO constraint_name_var
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
            ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = 'vendors' 
            AND tc.constraint_type = 'UNIQUE'
            AND kcu.column_name = 'erp_vendor_id'
            AND NOT EXISTS (
                SELECT 1 FROM information_schema.key_column_usage kcu2
                WHERE kcu2.constraint_name = kcu.constraint_name
                AND kcu2.column_name != 'erp_vendor_id'
            )
            LIMIT 1;
            
            IF constraint_name_var IS NOT NULL THEN
                EXECUTE 'ALTER TABLE vendors DROP CONSTRAINT ' || constraint_name_var;
                RAISE NOTICE 'Dropped unique constraint: %', constraint_name_var;
            END IF;
        END;
    END IF;
END $$;

-- Step 2: Create a new unique constraint on (erp_vendor_id, branch_id) combination
-- This allows same vendor ID in different branches but prevents duplicates within same branch
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu1 
        ON tc.constraint_name = kcu1.constraint_name
        JOIN information_schema.key_column_usage kcu2 
        ON tc.constraint_name = kcu2.constraint_name
        WHERE tc.table_name = 'vendors' 
        AND tc.constraint_type = 'UNIQUE'
        AND kcu1.column_name = 'erp_vendor_id'
        AND kcu2.column_name = 'branch_id'
    ) THEN
        ALTER TABLE vendors 
        ADD CONSTRAINT vendors_erp_vendor_branch_unique 
        UNIQUE (erp_vendor_id, branch_id);
        
        RAISE NOTICE 'Added unique constraint on (erp_vendor_id, branch_id)';
    END IF;
END $$;

-- Step 3: Keep existing primary key structure for compatibility
DO $$
BEGIN
    RAISE NOTICE 'Keeping existing primary key structure for compatibility';
    RAISE NOTICE 'Vendor uniqueness now enforced by composite unique constraint on (erp_vendor_id, branch_id)';
    RAISE NOTICE 'Same vendor ID can now exist in different branches';
END $$;

-- Create index for efficient queries by erp_vendor_id alone (for backward compatibility)
CREATE INDEX IF NOT EXISTS idx_vendors_erp_vendor_id 
ON vendors USING btree (erp_vendor_id);

-- Add comment for documentation
COMMENT ON CONSTRAINT vendors_erp_vendor_branch_unique ON vendors IS 
'Ensures ERP vendor ID is unique within each branch, allowing same vendor ID across different branches';

COMMIT;

-- Verification queries
SELECT 'Migration completed successfully - vendors can now have same ERP ID in different branches' AS status;

-- Show updated constraints
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'vendors'
AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
ORDER BY tc.constraint_name, kcu.ordinal_position;