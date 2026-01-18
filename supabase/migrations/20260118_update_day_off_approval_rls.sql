-- Update RLS policies for day_off table with approval status

-- Drop existing policies
DROP POLICY IF EXISTS "Allow users to view their own day offs" ON day_off;
DROP POLICY IF EXISTS "Allow users to create their own day offs" ON day_off;
DROP POLICY IF EXISTS "Allow users to update their own day offs" ON day_off;
DROP POLICY IF EXISTS "Allow users to delete their own day offs" ON day_off;

-- Create new policies that include approval status checks
-- View: Users can see their own day offs, approvers can see pending/sent for approval requests
CREATE POLICY "Users can view their own day offs"
ON day_off
FOR SELECT
USING (
  auth.uid() IN (
    -- User owns this day off (via employee)
    SELECT id FROM hr_employee_master WHERE user_id = auth.uid()
  )
  OR
  -- User is an approver with permission to approve leave requests
  EXISTS (
    SELECT 1 FROM approval_permissions
    WHERE user_id = auth.uid()
    AND can_approve_leave_requests = true
    AND is_active = true
  )
);

-- Insert: Users can only create day off for their own employee record
CREATE POLICY "Users can create their own day offs"
ON day_off
FOR INSERT
WITH CHECK (
  employee_id IN (
    SELECT id FROM hr_employee_master WHERE user_id = auth.uid()
  )
  AND approval_status = 'pending'
);

-- Update: Users can update their own pending day offs, approvers can approve/reject
CREATE POLICY "Users can update their own pending day offs"
ON day_off
FOR UPDATE
USING (
  -- User owns this and it's still pending
  (
    employee_id IN (
      SELECT id FROM hr_employee_master WHERE user_id = auth.uid()
    )
    AND approval_status = 'pending'
  )
  OR
  -- User is an approver with permission to approve leave requests
  (
    EXISTS (
      SELECT 1 FROM approval_permissions
      WHERE user_id = auth.uid()
      AND can_approve_leave_requests = true
      AND is_active = true
    )
    AND approval_status IN ('pending', 'sent_for_approval')
  )
)
WITH CHECK (TRUE);

-- Delete: Users can only delete their own pending day offs
CREATE POLICY "Users can delete their own pending day offs"
ON day_off
FOR DELETE
USING (
  employee_id IN (
    SELECT id FROM hr_employee_master WHERE user_id = auth.uid()
  )
  AND approval_status = 'pending'
);

-- Grant appropriate permissions to roles
GRANT SELECT, INSERT, UPDATE, DELETE ON day_off TO authenticated;
GRANT SELECT, UPDATE ON day_off TO service_role;
GRANT SELECT ON day_off TO anon;
