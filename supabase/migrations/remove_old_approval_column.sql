-- Remove old approval permission column from users table
-- All components now use the approval_permissions table

-- Remove the old can_approve_payments column
ALTER TABLE public.users DROP COLUMN IF EXISTS can_approve_payments;

-- Add comment to document the change
COMMENT ON TABLE public.users IS 'User accounts table. Approval permissions moved to approval_permissions table.';
