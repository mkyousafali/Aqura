-- =====================================================
-- Enable Vendor Payment Approvals for Test Users
-- =====================================================
-- Purpose: Update approval_permissions to enable vendor payment approvals
-- Created: 2025-11-03
-- =====================================================

-- Update all existing users to have vendor payment approval permissions
-- This enables the approval workflow for testing
update public.approval_permissions
set 
  can_approve_vendor_payments = true,
  vendor_payment_amount_limit = 0,  -- 0 means unlimited
  updated_at = now()
where is_active = true;

-- Log the results
do $$
declare
  updated_count integer;
begin
  select count(*) into updated_count
  from public.approval_permissions
  where can_approve_vendor_payments = true and is_active = true;
  
  raise notice 'Successfully enabled vendor payment approvals';
  raise notice '% users can now approve vendor payments (unlimited amount)', updated_count;
end $$;

-- Optional: Create a specific high-limit approver (uncomment if needed)
-- update public.approval_permissions
-- set 
--   can_approve_vendor_payments = true,
--   vendor_payment_amount_limit = 100000.00,  -- Specific limit
--   updated_at = now()
-- where user_id = 'INSERT_SPECIFIC_USER_ID_HERE';
