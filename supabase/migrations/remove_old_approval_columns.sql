-- =====================================================
-- Remove Old Approval Columns from Users Table
-- =====================================================
-- Purpose: Drop can_approve_payments and approval_amount_limit columns
--          after migrating to approval_permissions table
-- Created: 2025-11-03
-- =====================================================

-- Drop the old approval columns from users table
alter table public.users
drop column if exists can_approve_payments,
drop column if exists approval_amount_limit;

-- Log the change
do $$
begin
  raise notice 'Old approval columns removed from users table. All approval permissions now in approval_permissions table.';
end $$;
