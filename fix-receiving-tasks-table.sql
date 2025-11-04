-- =====================================================
-- VERIFY RECEIVING_TASKS TABLE STRUCTURE
-- =====================================================
-- Check current table structure and add any missing columns
-- =====================================================

-- Show current table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'receiving_tasks'
ORDER BY ordinal_position;

-- Check and add missing columns if needed
DO $$ 
BEGIN
    -- Check for completion_notes column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'receiving_tasks' AND column_name = 'completion_notes'
    ) THEN
        ALTER TABLE receiving_tasks ADD COLUMN completion_notes TEXT;
        RAISE NOTICE 'Added completion_notes column';
    END IF;

    -- Check for completion_photo_url column  
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'receiving_tasks' AND column_name = 'completion_photo_url'
    ) THEN
        ALTER TABLE receiving_tasks ADD COLUMN completion_photo_url TEXT;
        RAISE NOTICE 'Added completion_photo_url column';
    END IF;

    -- Check for erp_reference_number column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'receiving_tasks' AND column_name = 'erp_reference_number'
    ) THEN
        ALTER TABLE receiving_tasks ADD COLUMN erp_reference_number VARCHAR(255);
        RAISE NOTICE 'Added erp_reference_number column';
    END IF;

    -- Check for original_bill_uploaded column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'receiving_tasks' AND column_name = 'original_bill_uploaded'
    ) THEN
        ALTER TABLE receiving_tasks ADD COLUMN original_bill_uploaded BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added original_bill_uploaded column';
    END IF;

    -- Check for rule_effective_date column (used in photo requirement check)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'receiving_tasks' AND column_name = 'rule_effective_date'
    ) THEN
        ALTER TABLE receiving_tasks ADD COLUMN rule_effective_date TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added rule_effective_date column';
    END IF;

END $$;

-- Show updated table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'receiving_tasks'
ORDER BY ordinal_position;