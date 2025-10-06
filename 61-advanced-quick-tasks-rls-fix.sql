-- Advanced Quick Tasks RLS Policy Fix
-- This addresses persistent policy issues and caching problems

-- 1. First, completely disable RLS temporarily to clear cache
ALTER TABLE quick_tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_files DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_comments DISABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_user_preferences DISABLE ROW LEVEL SECURITY;

-- 2. Drop ALL existing policies completely
DROP POLICY IF EXISTS quick_tasks_policy ON quick_tasks;
DROP POLICY IF EXISTS quick_task_assignments_policy ON quick_task_assignments;
DROP POLICY IF EXISTS quick_task_files_policy ON quick_task_files;
DROP POLICY IF EXISTS quick_task_comments_policy ON quick_task_comments;
DROP POLICY IF EXISTS quick_task_user_preferences_policy ON quick_task_user_preferences;
DROP POLICY IF EXISTS quick_task_user_preferences_insert_policy ON quick_task_user_preferences;

-- Also check for any other policy names that might exist
DROP POLICY IF EXISTS "quick_tasks_policy" ON quick_tasks;
DROP POLICY IF EXISTS "quick_task_assignments_policy" ON quick_task_assignments;
DROP POLICY IF EXISTS "quick_task_files_policy" ON quick_task_files;
DROP POLICY IF EXISTS "quick_task_comments_policy" ON quick_task_comments;
DROP POLICY IF EXISTS "quick_task_user_preferences_policy" ON quick_task_user_preferences;

-- 3. Verify no policies exist
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename LIKE 'quick_task%'
ORDER BY tablename, policyname;

-- 4. Re-enable RLS
ALTER TABLE quick_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_user_preferences ENABLE ROW LEVEL SECURITY;

-- 5. Create new, simple policies without any cross-references

-- Quick Tasks - Simple policy
CREATE POLICY "quick_tasks_access" ON quick_tasks FOR ALL USING (
    auth.uid() = assigned_by
);

-- Quick Task User Preferences - Allow users to manage their own preferences
CREATE POLICY "quick_task_user_preferences_access" ON quick_task_user_preferences FOR ALL USING (
    auth.uid() = user_id
);

CREATE POLICY "quick_task_user_preferences_insert" ON quick_task_user_preferences FOR INSERT WITH CHECK (
    auth.uid() = user_id
);

-- Quick Task Assignments - Simple policy
CREATE POLICY "quick_task_assignments_access" ON quick_task_assignments FOR ALL USING (
    auth.uid() = assigned_to_user_id
);

-- Allow task creators to create assignments
CREATE POLICY "quick_task_assignments_creator" ON quick_task_assignments FOR INSERT WITH CHECK (
    auth.uid() IN (
        SELECT assigned_by FROM quick_tasks WHERE id = quick_task_id
    )
);

-- Quick Task Files - Simple policy
CREATE POLICY "quick_task_files_access" ON quick_task_files FOR ALL USING (
    auth.uid() = uploaded_by
);

-- Quick Task Comments - Simple policy  
CREATE POLICY "quick_task_comments_access" ON quick_task_comments FOR ALL USING (
    auth.uid() = created_by
);

-- 6. Grant permissions explicitly
GRANT ALL ON quick_tasks TO authenticated;
GRANT ALL ON quick_task_assignments TO authenticated;
GRANT ALL ON quick_task_files TO authenticated;
GRANT ALL ON quick_task_comments TO authenticated;
GRANT ALL ON quick_task_user_preferences TO authenticated;

-- 7. Test basic operations
SELECT 'Quick Task RLS policies recreated successfully' as status;

-- 8. Force cache refresh
NOTIFY pgrst, 'reload schema';

-- 9. Verify the new policies
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename LIKE 'quick_task%'
ORDER BY tablename, policyname;