-- Add is_read column to notification_read_states table
-- This provides better data integrity and easier querying

DO $$ 
BEGIN
    -- Add is_read column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notification_read_states' AND column_name = 'is_read'
    ) THEN
        ALTER TABLE notification_read_states ADD COLUMN is_read BOOLEAN DEFAULT false NOT NULL;
        COMMENT ON COLUMN notification_read_states.is_read IS 'Whether the notification has been read by the user';
        
        -- Update existing records to mark them as read (since they exist, they were read)
        UPDATE notification_read_states SET is_read = true WHERE read_at IS NOT NULL;
        
        RAISE NOTICE 'Added is_read column to notification_read_states table and updated existing records';
    ELSE
        RAISE NOTICE 'is_read column already exists in notification_read_states table';
    END IF;
END $$;