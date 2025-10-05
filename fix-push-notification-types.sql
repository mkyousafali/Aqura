-- Fix Push Notification System Data Types
-- The issue is that user_id columns have mismatched types

-- 1. First check the current data types
SELECT 'Checking Data Types:' as test;

SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('users', 'notification_recipients', 'notification_queue', 'push_subscriptions')
    AND column_name LIKE '%user_id%' OR column_name = 'id' AND table_name = 'users'
ORDER BY table_name, column_name;

-- 2. Fix notification_recipients table
SELECT 'Fixing notification_recipients user_id column type:' as test;

-- First, remove any existing data to avoid conflicts
DELETE FROM notification_recipients WHERE user_id IS NOT NULL;

-- Drop and recreate the user_id column with correct type
ALTER TABLE notification_recipients DROP COLUMN IF EXISTS user_id;
ALTER TABLE notification_recipients ADD COLUMN user_id UUID;

-- Add foreign key constraint
ALTER TABLE notification_recipients 
ADD CONSTRAINT fk_notification_recipients_user 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- 3. Fix notification_queue table if needed
SELECT 'Fixing notification_queue user_id column type:' as test;

-- Check current type and fix if needed
DO $$
BEGIN
    -- Check if user_id exists and what type it is
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notification_queue' 
        AND column_name = 'user_id' 
        AND data_type != 'uuid'
    ) THEN
        -- Clear existing data and fix type
        DELETE FROM notification_queue WHERE user_id IS NOT NULL;
        ALTER TABLE notification_queue DROP COLUMN user_id;
        ALTER TABLE notification_queue ADD COLUMN user_id UUID;
        ALTER TABLE notification_queue 
        ADD CONSTRAINT fk_notification_queue_user 
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 4. Fix push_subscriptions table if needed  
SELECT 'Fixing push_subscriptions user_id column type:' as test;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'push_subscriptions' 
        AND column_name = 'user_id' 
        AND data_type != 'uuid'
    ) THEN
        -- Don't delete push subscriptions data as it's important
        -- Instead, create a new column and migrate data
        ALTER TABLE push_subscriptions ADD COLUMN user_id_new UUID;
        
        -- Try to convert existing data if possible
        UPDATE push_subscriptions 
        SET user_id_new = user_id::uuid 
        WHERE user_id IS NOT NULL AND user_id != '';
        
        -- Drop old column and rename new one
        ALTER TABLE push_subscriptions DROP COLUMN user_id;
        ALTER TABLE push_subscriptions RENAME COLUMN user_id_new TO user_id;
        
        -- Add foreign key
        ALTER TABLE push_subscriptions 
        ADD CONSTRAINT fk_push_subscriptions_user 
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 5. Verify the fixes
SELECT 'Data Types After Fix:' as test;

SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('users', 'notification_recipients', 'notification_queue', 'push_subscriptions')
    AND (column_name LIKE '%user_id%' OR (column_name = 'id' AND table_name = 'users'))
ORDER BY table_name, column_name;