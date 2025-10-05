-- Fix Notifications Table Structure
-- This will ensure the table has the correct columns

-- First, let's see what we actually have
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'notifications' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- If the table is missing columns, let's add them
DO $$
BEGIN
    -- Add priority column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'priority' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN priority VARCHAR(20) NOT NULL DEFAULT 'medium';
    END IF;
    
    -- Add status column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'status' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'published';
    END IF;
    
    -- Add other missing columns
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'created_by' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN created_by VARCHAR(255) NOT NULL DEFAULT 'system';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'created_by_name' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN created_by_name VARCHAR(100) NOT NULL DEFAULT 'System';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'created_by_role' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN created_by_role VARCHAR(50) NOT NULL DEFAULT 'Admin';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'target_type' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN target_type VARCHAR(50) NOT NULL DEFAULT 'all_users';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'target_users' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN target_users JSONB;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'target_roles' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN target_roles JSONB;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
          AND column_name = 'target_branches' 
          AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications 
        ADD COLUMN target_branches JSONB;
    END IF;
    
END $$;

-- Force schema refresh
NOTIFY pgrst, 'reload schema';

-- Test the fix
SELECT 'Table structure fixed!' as status;

-- Verify columns now exist
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'notifications' 
  AND table_schema = 'public'
ORDER BY ordinal_position;