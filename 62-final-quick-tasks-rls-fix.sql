-- Final Quick Tasks RLS Policy Fix
-- This creates more permissive policies to allow proper functionality

-- 1. Drop the overly restrictive policies
DROP POLICY IF EXISTS "quick_tasks_access" ON quick_tasks;
DROP POLICY IF EXISTS "quick_task_user_preferences_access" ON quick_task_user_preferences;
DROP POLICY IF EXISTS "quick_task_user_preferences_insert" ON quick_task_user_preferences;
DROP POLICY IF EXISTS "quick_task_assignments_access" ON quick_task_assignments;
DROP POLICY IF EXISTS "quick_task_assignments_creator" ON quick_task_assignments;
DROP POLICY IF EXISTS "quick_task_files_access" ON quick_task_files;
DROP POLICY IF EXISTS "quick_task_comments_access" ON quick_task_comments;

-- 2. Create more permissive policies that allow proper functionality

-- Quick Tasks - Allow creators and assignees
CREATE POLICY "quick_tasks_full_access" ON quick_tasks FOR ALL USING (
    auth.uid() = assigned_by OR
    auth.uid() = ANY(
        SELECT assigned_to_user_id 
        FROM quick_task_assignments 
        WHERE quick_task_id = quick_tasks.id
    )
);

-- Allow INSERT for task creation
CREATE POLICY "quick_tasks_insert" ON quick_tasks FOR INSERT WITH CHECK (
    auth.uid() = assigned_by
);

-- Quick Task User Preferences - Full access for users to their own preferences
CREATE POLICY "quick_task_user_preferences_full" ON quick_task_user_preferences FOR ALL USING (
    auth.uid() = user_id
);

CREATE POLICY "quick_task_user_preferences_insert_check" ON quick_task_user_preferences FOR INSERT WITH CHECK (
    auth.uid() = user_id
);

-- Quick Task Assignments - Allow assigned users and task creators
CREATE POLICY "quick_task_assignments_full" ON quick_task_assignments FOR ALL USING (
    auth.uid() = assigned_to_user_id OR
    auth.uid() = ANY(
        SELECT assigned_by 
        FROM quick_tasks 
        WHERE id = quick_task_assignments.quick_task_id
    )
);

-- Allow INSERT for creating assignments
CREATE POLICY "quick_task_assignments_insert_check" ON quick_task_assignments FOR INSERT WITH CHECK (
    auth.uid() = ANY(
        SELECT assigned_by 
        FROM quick_tasks 
        WHERE id = quick_task_assignments.quick_task_id
    )
);

-- Quick Task Files - Allow file owners, task creators, and assignees
CREATE POLICY "quick_task_files_full" ON quick_task_files FOR ALL USING (
    auth.uid() = uploaded_by OR
    auth.uid() = ANY(
        SELECT assigned_by 
        FROM quick_tasks 
        WHERE id = quick_task_files.quick_task_id
    ) OR
    auth.uid() = ANY(
        SELECT assigned_to_user_id 
        FROM quick_task_assignments 
        WHERE quick_task_id = quick_task_files.quick_task_id
    )
);

-- Quick Task Comments - Allow comment creators, task creators, and assignees
CREATE POLICY "quick_task_comments_full" ON quick_task_comments FOR ALL USING (
    auth.uid() = created_by OR
    auth.uid() = ANY(
        SELECT assigned_by 
        FROM quick_tasks 
        WHERE id = quick_task_comments.quick_task_id
    ) OR
    auth.uid() = ANY(
        SELECT assigned_to_user_id 
        FROM quick_task_assignments 
        WHERE quick_task_id = quick_task_comments.quick_task_id
    )
);

-- 3. Test that policies are working
SELECT 'More permissive RLS policies applied successfully' as status;

-- 4. Verify the new policies
SELECT 
    tablename, 
    policyname, 
    cmd,
    SUBSTRING(qual, 1, 50) as policy_condition
FROM pg_policies 
WHERE tablename LIKE 'quick_task%'
ORDER BY tablename, policyname;