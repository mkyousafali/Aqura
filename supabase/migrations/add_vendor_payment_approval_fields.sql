-- =====================================================
-- Add Approval Fields to Vendor Payment Schedule
-- =====================================================
-- Purpose: Enable approval workflow for vendor payments
-- Created: 2025-11-03
-- =====================================================

-- Add approval-related columns to vendor_payment_schedule table
alter table public.vendor_payment_schedule
  add column if not exists approval_status text not null default 'pending',
  add column if not exists approval_requested_by uuid null,
  add column if not exists approval_requested_at timestamp with time zone null,
  add column if not exists approved_by uuid null,
  add column if not exists approved_at timestamp with time zone null,
  add column if not exists approval_notes text null;

-- Add check constraint for approval_status values
alter table public.vendor_payment_schedule
  add constraint vendor_payment_approval_status_check 
  check (approval_status in ('pending', 'sent_for_approval', 'approved', 'rejected'));

-- Add foreign key constraints for user references
alter table public.vendor_payment_schedule
  add constraint vendor_payment_approval_requested_by_fkey 
  foreign key (approval_requested_by) references users (id) on delete set null;

alter table public.vendor_payment_schedule
  add constraint vendor_payment_approved_by_fkey 
  foreign key (approved_by) references users (id) on delete set null;

-- Create indexes for performance
create index if not exists idx_vendor_payment_approval_status 
  on public.vendor_payment_schedule using btree (approval_status) tablespace pg_default
  where (approval_status = 'sent_for_approval');

create index if not exists idx_vendor_payment_approval_requested_by 
  on public.vendor_payment_schedule using btree (approval_requested_by) tablespace pg_default;

create index if not exists idx_vendor_payment_approved_by 
  on public.vendor_payment_schedule using btree (approved_by) tablespace pg_default;

-- Add comments for documentation
comment on column public.vendor_payment_schedule.approval_status is 'Approval workflow status: pending, sent_for_approval, approved, rejected';
comment on column public.vendor_payment_schedule.approval_requested_by is 'User who requested approval';
comment on column public.vendor_payment_schedule.approval_requested_at is 'Timestamp when approval was requested';
comment on column public.vendor_payment_schedule.approved_by is 'User who approved the payment';
comment on column public.vendor_payment_schedule.approved_at is 'Timestamp when payment was approved';
comment on column public.vendor_payment_schedule.approval_notes is 'Optional notes about the approval decision';

-- Log completion
do $$
begin
  raise notice 'Successfully added approval fields to vendor_payment_schedule table';
  raise notice 'New fields: approval_status, approval_requested_by, approval_requested_at, approved_by, approved_at, approval_notes';
end $$;
