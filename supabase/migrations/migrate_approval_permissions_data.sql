-- =====================================================
-- Data Migration: Migrate Existing Approval Permissions
-- =====================================================
-- Purpose: Migrate users.can_approve_payments to approval_permissions table
-- Created: 2025-11-03
-- =====================================================

-- Insert approval permissions for all users who currently have can_approve_payments = true
insert into public.approval_permissions (
  user_id,
  can_approve_requisitions,
  requisition_amount_limit,
  can_approve_single_bill,
  single_bill_amount_limit,
  can_approve_multiple_bill,
  multiple_bill_amount_limit,
  can_approve_recurring_bill,
  recurring_bill_amount_limit,
  can_approve_vendor_payments,
  vendor_payment_amount_limit,
  can_approve_leave_requests,
  created_at,
  updated_at,
  is_active
)
select 
  id as user_id,
  true as can_approve_requisitions,
  coalesce(approval_amount_limit, 0.00) as requisition_amount_limit,
  true as can_approve_single_bill,
  coalesce(approval_amount_limit, 0.00) as single_bill_amount_limit,
  true as can_approve_multiple_bill,
  coalesce(approval_amount_limit, 0.00) as multiple_bill_amount_limit,
  true as can_approve_recurring_bill,
  coalesce(approval_amount_limit, 0.00) as recurring_bill_amount_limit,
  false as can_approve_vendor_payments,
  0.00 as vendor_payment_amount_limit,
  false as can_approve_leave_requests,
  now() as created_at,
  now() as updated_at,
  case when status = 'active' then true else false end as is_active
from public.users
where can_approve_payments = true
on conflict (user_id) do update
set
  can_approve_requisitions = excluded.can_approve_requisitions,
  requisition_amount_limit = excluded.requisition_amount_limit,
  can_approve_single_bill = excluded.can_approve_single_bill,
  single_bill_amount_limit = excluded.single_bill_amount_limit,
  can_approve_multiple_bill = excluded.can_approve_multiple_bill,
  multiple_bill_amount_limit = excluded.multiple_bill_amount_limit,
  can_approve_recurring_bill = excluded.can_approve_recurring_bill,
  recurring_bill_amount_limit = excluded.recurring_bill_amount_limit,
  updated_at = now();

-- Log migration results
do $$
declare
  migrated_count integer;
begin
  select count(*) into migrated_count
  from public.approval_permissions;
  
  raise notice 'Migration completed: % users migrated to approval_permissions table', migrated_count;
end $$;
