-- Fix the ON CONFLICT constraint issue in notification_recipients table
-- The error occurs because queue_push_notification function uses ON CONFLICT 
-- but the required unique constraint doesn't exist

-- 1. First check if notification_recipients table exists and its structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'notification_recipients' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check existing constraints on notification_recipients
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'notification_recipients'
    AND tc.table_schema = 'public'
GROUP BY tc.constraint_name, tc.constraint_type
ORDER BY tc.constraint_type, tc.constraint_name;

-- 3. Create the missing unique constraint for notification_recipients
-- First check if the constraint already exists, then add it if it doesn't
DO $$ 
BEGIN
    -- Check if constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'unique_notification_recipient' 
        AND table_name = 'notification_recipients'
    ) THEN
        -- Add the constraint
        ALTER TABLE notification_recipients 
        ADD CONSTRAINT unique_notification_recipient 
        UNIQUE (notification_id, user_id);
        
        RAISE NOTICE 'Added unique constraint: unique_notification_recipient';
    ELSE
        RAISE NOTICE 'Constraint unique_notification_recipient already exists';
    END IF;
END $$;

-- 4. Also ensure the table exists with proper structure if it doesn't
CREATE TABLE IF NOT EXISTS notification_recipients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    branch_id TEXT,
    role TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Verify the constraint was created
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'notification_recipients'
    AND tc.constraint_type = 'UNIQUE'
    AND tc.table_schema = 'public'
GROUP BY tc.constraint_name, tc.constraint_type;

-- Success message
SELECT 'Notification recipients constraint fixed!' as status;
SELECT 'The ON CONFLICT (notification_id, user_id) clause should now work' as result;