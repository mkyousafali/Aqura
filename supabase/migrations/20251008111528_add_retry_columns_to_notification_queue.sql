-- Add retry tracking columns to notification_queue table
-- This enables the 3-attempt retry system with 10-second intervals

DO $$ 
BEGIN
    -- Add retry_count column (tracks number of retry attempts)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notification_queue' 
        AND column_name = 'retry_count'
    ) THEN
        ALTER TABLE notification_queue 
        ADD COLUMN retry_count INTEGER DEFAULT 0 NOT NULL;
        
        COMMENT ON COLUMN notification_queue.retry_count IS 'Number of retry attempts (max 3)';
    END IF;

    -- Add next_retry_at column (when to attempt next retry)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notification_queue' 
        AND column_name = 'next_retry_at'
    ) THEN
        ALTER TABLE notification_queue 
        ADD COLUMN next_retry_at TIMESTAMPTZ;
        
        COMMENT ON COLUMN notification_queue.next_retry_at IS 'When to attempt next retry (NULL if not scheduled)';
    END IF;

    -- Add last_attempt_at column (when last attempt was made)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notification_queue' 
        AND column_name = 'last_attempt_at'
    ) THEN
        ALTER TABLE notification_queue 
        ADD COLUMN last_attempt_at TIMESTAMPTZ;
        
        COMMENT ON COLUMN notification_queue.last_attempt_at IS 'When the last delivery attempt was made';
    END IF;

    -- Update the status column to include 'retry' and 'processing' states
    -- First check if notification_status enum exists, if not, assume VARCHAR status column
    IF EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'notification_status'
    ) THEN
        -- Enum exists, add new values if not present
        IF NOT EXISTS (
            SELECT 1 FROM pg_enum e
            JOIN pg_type t ON e.enumtypid = t.oid
            WHERE t.typname = 'notification_status'
            AND e.enumlabel = 'retry'
        ) THEN
            ALTER TYPE notification_status ADD VALUE 'retry';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pg_enum e
            JOIN pg_type t ON e.enumtypid = t.oid
            WHERE t.typname = 'notification_status'
            AND e.enumlabel = 'processing'
        ) THEN
            ALTER TYPE notification_status ADD VALUE 'processing';
        END IF;
        
        RAISE NOTICE 'Added retry and processing values to notification_status enum';
    ELSE
        -- Enum doesn't exist, status is likely VARCHAR - add a check constraint instead
        -- First check current status column type
        DECLARE
            status_data_type TEXT;
        BEGIN
            SELECT data_type INTO status_data_type
            FROM information_schema.columns 
            WHERE table_name = 'notification_queue' 
            AND column_name = 'status';
            
            IF status_data_type IN ('character varying', 'text', 'varchar') THEN
                -- Add check constraint for allowed status values including retry and processing
                IF NOT EXISTS (
                    SELECT 1 FROM information_schema.check_constraints 
                    WHERE constraint_name = 'notification_queue_status_check'
                ) THEN
                    ALTER TABLE notification_queue 
                    ADD CONSTRAINT notification_queue_status_check 
                    CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'retry', 'processing'));
                END IF;
                
                RAISE NOTICE 'Added check constraint for status values including retry and processing';
            ELSE
                RAISE NOTICE 'Status column is % type, no enum or constraint changes needed', status_data_type;
            END IF;
        END;
    END IF;

    -- Create index for efficient retry processing
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'notification_queue' 
        AND indexname = 'idx_notification_queue_retry'
    ) THEN
        CREATE INDEX idx_notification_queue_retry 
        ON notification_queue (status, next_retry_at) 
        WHERE status = 'retry' AND next_retry_at IS NOT NULL;
    END IF;

    -- Create index for processing status
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'notification_queue' 
        AND indexname = 'idx_notification_queue_processing'
    ) THEN
        CREATE INDEX idx_notification_queue_processing 
        ON notification_queue (status, last_attempt_at) 
        WHERE status IN ('pending', 'processing', 'retry');
    END IF;

    RAISE NOTICE 'Retry tracking columns and indexes added successfully to notification_queue table';
END $$;