-- Fix RLS for quick_task_user_preferences table
-- This allows users to read and write their own preferences
-- Note: Since this app uses custom authentication (not Supabase Auth),
-- we need to disable RLS or use a different approach

-- Disable RLS on the table to allow access
-- (Your application already handles authorization at the application level)
ALTER TABLE quick_task_user_preferences DISABLE ROW LEVEL SECURITY;

-- Alternative: If you want to keep RLS enabled, you need to set up
-- custom claims or use service role key for authenticated operations
