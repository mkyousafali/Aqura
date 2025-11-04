-- =====================================================
-- ADD MISSING COMPLETION_NOTES COLUMN
-- =====================================================
-- Add the completion_notes column to receiving_tasks table
-- that was referenced in the updated function but doesn't exist
-- =====================================================

-- Check if column exists first, then add if missing
DO $$ 
BEGIN
    -- Check if the column exists
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'receiving_tasks' 
        AND column_name = 'completion_notes'
    ) THEN
        -- Add the missing column
        ALTER TABLE receiving_tasks 
        ADD COLUMN completion_notes TEXT;
        
        RAISE NOTICE 'Added completion_notes column to receiving_tasks table';
    ELSE
        RAISE NOTICE 'completion_notes column already exists in receiving_tasks table';
    END IF;
END $$;

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'receiving_tasks' 
AND column_name = 'completion_notes';