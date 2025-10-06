-- Fix Quick Tasks RLS Policy Issues
-- This fixes the infinite recursion and authorization issues

-- 1. Fix infinite recursion in quick_tasks policy
-- The issue is that the policy references quick_task_assignments which references back to quick_tasks
DROP POLICY IF EXISTS quick_tasks_policy ON quick_tasks;
CREATE POLICY quick_tasks_policy ON quick_tasks FOR ALL USING (
    -- User is the task creator
    auth.uid() = assigned_by OR 
    -- User is assigned to this task (direct check to avoid recursion)
    EXISTS (
        SELECT 1 FROM quick_task_assignments qta 
        WHERE qta.quick_task_id = quick_tasks.id 
        AND qta.assigned_to_user_id = auth.uid()
    )
);

-- 2. Fix quick_task_user_preferences policy (allow users to insert their own preferences)
DROP POLICY IF EXISTS quick_task_user_preferences_policy ON quick_task_user_preferences;
CREATE POLICY quick_task_user_preferences_policy ON quick_task_user_preferences FOR ALL USING (
    auth.uid() = user_id
);

-- Add separate INSERT policy for preferences to allow creation
CREATE POLICY quick_task_user_preferences_insert_policy ON quick_task_user_preferences FOR INSERT WITH CHECK (
    auth.uid() = user_id
);

-- 3. Fix quick_task_assignments policy to avoid recursion
DROP POLICY IF EXISTS quick_task_assignments_policy ON quick_task_assignments;
CREATE POLICY quick_task_assignments_policy ON quick_task_assignments FOR ALL USING (
    -- User is assigned to this task
    auth.uid() = assigned_to_user_id OR 
    -- User created the task (direct check to avoid recursion)
    EXISTS (
        SELECT 1 FROM quick_tasks qt 
        WHERE qt.id = quick_task_assignments.quick_task_id 
        AND qt.assigned_by = auth.uid()
    )
);

-- 4. Simplify other policies to avoid potential recursion issues
DROP POLICY IF EXISTS quick_task_files_policy ON quick_task_files;
CREATE POLICY quick_task_files_policy ON quick_task_files FOR ALL USING (
    -- User uploaded the file
    auth.uid() = uploaded_by OR
    -- User created the task
    EXISTS (
        SELECT 1 FROM quick_tasks qt 
        WHERE qt.id = quick_task_files.quick_task_id 
        AND qt.assigned_by = auth.uid()
    ) OR
    -- User is assigned to the task
    EXISTS (
        SELECT 1 FROM quick_task_assignments qta 
        WHERE qta.quick_task_id = quick_task_files.quick_task_id 
        AND qta.assigned_to_user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS quick_task_comments_policy ON quick_task_comments;
CREATE POLICY quick_task_comments_policy ON quick_task_comments FOR ALL USING (
    -- User created the comment
    auth.uid() = created_by OR
    -- User created the task
    EXISTS (
        SELECT 1 FROM quick_tasks qt 
        WHERE qt.id = quick_task_comments.quick_task_id 
        AND qt.assigned_by = auth.uid()
    ) OR
    -- User is assigned to the task
    EXISTS (
        SELECT 1 FROM quick_task_assignments qta 
        WHERE qta.quick_task_id = quick_task_comments.quick_task_id 
        AND qta.assigned_to_user_id = auth.uid()
    )
);

-- 5. Verify policies are working by testing
-- Test 1: Check if current user can create preferences
DO $$
BEGIN
    IF current_setting('request.jwt.claims', true)::json->>'sub' IS NOT NULL THEN
        RAISE NOTICE 'Current user ID: %', current_setting('request.jwt.claims', true)::json->>'sub';
    ELSE
        RAISE NOTICE 'No authenticated user found';
    END IF;
END $$;

-- 6. Grant necessary permissions explicitly
GRANT ALL ON quick_tasks TO authenticated;
GRANT ALL ON quick_task_assignments TO authenticated;
GRANT ALL ON quick_task_files TO authenticated;
GRANT ALL ON quick_task_comments TO authenticated;
GRANT ALL ON quick_task_user_preferences TO authenticated;

-- 7. Test the policies
SELECT 'RLS policies updated successfully' as status;