-- Quick Task Assignments Diagnostic and Fix
-- This script checks if the table exists and fixes any issues

-- First, check if the table exists
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'quick_task_assignments'
) as table_exists;

-- Check the table structure if it exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'quick_task_assignments'
ORDER BY ordinal_position;

-- Check if RLS is enabled and what policies exist
SELECT schemaname, tablename, rowsecurity, enablerls 
FROM pg_tables 
WHERE tablename = 'quick_task_assignments';

-- Check existing policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'quick_task_assignments';

-- If the table doesn't exist, create it with proper structure
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'quick_task_assignments'
    ) THEN
        -- Create the table
        CREATE TABLE public.quick_task_assignments (
            id uuid NOT NULL DEFAULT gen_random_uuid(),
            quick_task_id uuid NOT NULL,
            assigned_to_user_id uuid NOT NULL,
            status character varying(50) DEFAULT 'pending'::character varying,
            accepted_at timestamp with time zone,
            started_at timestamp with time zone,
            completed_at timestamp with time zone,
            created_at timestamp with time zone DEFAULT now(),
            updated_at timestamp with time zone DEFAULT now(),
            CONSTRAINT quick_task_assignments_pkey PRIMARY KEY (id),
            CONSTRAINT quick_task_assignments_quick_task_id_assigned_to_user_id_key UNIQUE (quick_task_id, assigned_to_user_id),
            CONSTRAINT quick_task_assignments_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE CASCADE,
            CONSTRAINT quick_task_assignments_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE
        );

        -- Create indexes
        CREATE INDEX idx_quick_task_assignments_task ON quick_task_assignments (quick_task_id);
        CREATE INDEX idx_quick_task_assignments_user ON quick_task_assignments (assigned_to_user_id);
        CREATE INDEX idx_quick_task_assignments_status ON quick_task_assignments (status);
        CREATE INDEX idx_quick_task_assignments_created_at ON quick_task_assignments (created_at);

        RAISE NOTICE 'Created quick_task_assignments table with proper structure';
    ELSE
        RAISE NOTICE 'quick_task_assignments table already exists';
    END IF;
END $$;

-- Disable RLS for quick_task_assignments (temporary fix)
ALTER TABLE quick_task_assignments DISABLE ROW LEVEL SECURITY;

-- Grant necessary permissions
GRANT ALL ON quick_task_assignments TO authenticated;
GRANT ALL ON quick_task_assignments TO anon;

-- Verify the fix
SELECT 
    'Table exists: ' || EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'quick_task_assignments'
    )::text as status;

-- Test insert permissions
SELECT 
    'Insert permission: ' || 
    CASE 
        WHEN has_table_privilege('authenticated', 'quick_task_assignments', 'INSERT') 
        THEN 'GRANTED' 
        ELSE 'DENIED' 
    END as insert_status;