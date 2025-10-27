-- Clean up duplicate entries in vendor_payment_schedule table
-- This script removes duplicates, keeping only the oldest entry for each receiving_record_id

-- Step 1: Show current duplicates
DO $$
DECLARE
    duplicate_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT receiving_record_id, COUNT(*) as count
        FROM vendor_payment_schedule
        GROUP BY receiving_record_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 Found % receiving records with duplicate payment schedules', duplicate_count;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Step 2: Delete duplicates, keeping the oldest entry (earliest created_at)
WITH duplicates AS (
    SELECT 
        id,
        receiving_record_id,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY receiving_record_id 
            ORDER BY created_at ASC
        ) as rn
    FROM vendor_payment_schedule
    WHERE receiving_record_id IS NOT NULL
)
DELETE FROM vendor_payment_schedule
WHERE id IN (
    SELECT id 
    FROM duplicates 
    WHERE rn > 1
);

-- Step 3: Show results
DO $$
DECLARE
    total_count INTEGER;
    duplicate_count INTEGER;
BEGIN
    -- Count total schedules
    SELECT COUNT(*) INTO total_count
    FROM vendor_payment_schedule;
    
    -- Count remaining duplicates
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT receiving_record_id, COUNT(*) as count
        FROM vendor_payment_schedule
        GROUP BY receiving_record_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Cleanup Complete';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 Total payment schedules: %', total_count;
    RAISE NOTICE '📊 Remaining duplicates: %', duplicate_count;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Step 4: Create a unique constraint to prevent future duplicates
DO $$
BEGIN
    -- Drop the constraint if it exists
    ALTER TABLE vendor_payment_schedule 
    DROP CONSTRAINT IF EXISTS vendor_payment_schedule_receiving_record_id_unique;
    
    -- Add unique constraint on receiving_record_id
    ALTER TABLE vendor_payment_schedule 
    ADD CONSTRAINT vendor_payment_schedule_receiving_record_id_unique 
    UNIQUE (receiving_record_id);
    
    RAISE NOTICE '✅ Added unique constraint to prevent future duplicates';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  Could not add unique constraint: %', SQLERRM;
END $$;
