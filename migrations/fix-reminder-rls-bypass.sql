-- ============================================================================
-- FIX: Allow SECURITY DEFINER functions to bypass RLS
-- ============================================================================
-- This adds policies to allow the reminder function to access tables

-- 1. Add bypass policy for task_assignments
CREATE POLICY "Allow service role full access to task_assignments"
ON task_assignments
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 2. Add bypass policy for tasks  
CREATE POLICY "Allow service role full access to tasks"
ON tasks
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 3. Add bypass policy for users
CREATE POLICY "Allow service role full access to users"
ON users
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 4. Add bypass policy for task_completions
CREATE POLICY "Allow service role full access to task_completions"
ON task_completions
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 5. Add bypass policy for quick_task_assignments
CREATE POLICY "Allow service role full access to quick_task_assignments"
ON quick_task_assignments
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 6. Add bypass policy for quick_tasks
CREATE POLICY "Allow service role full access to quick_tasks"
ON quick_tasks
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 7. Add bypass policy for quick_task_completions
CREATE POLICY "Allow service role full access to quick_task_completions"
ON quick_task_completions
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Test the function again
SELECT * FROM check_overdue_tasks_and_send_reminders();
