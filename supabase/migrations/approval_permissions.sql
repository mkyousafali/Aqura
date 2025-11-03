-- =====================================================
-- Approval Permissions Table
-- =====================================================
-- Purpose: Manage granular approval permissions for different types of requests
-- Created: 2025-11-03
-- =====================================================

create table if not exists public.approval_permissions (
  id bigserial not null,
  user_id uuid not null,
  
  -- Expense Requisition Approvals
  can_approve_requisitions boolean not null default false,
  requisition_amount_limit numeric(15, 2) null default 0.00,
  
  -- Payment Schedule Approvals (separated by type)
  can_approve_single_bill boolean not null default false,
  single_bill_amount_limit numeric(15, 2) null default 0.00,
  
  can_approve_multiple_bill boolean not null default false,
  multiple_bill_amount_limit numeric(15, 2) null default 0.00,
  
  can_approve_recurring_bill boolean not null default false,
  recurring_bill_amount_limit numeric(15, 2) null default 0.00,
  
  -- Vendor Payment Approvals
  can_approve_vendor_payments boolean not null default false,
  vendor_payment_amount_limit numeric(15, 2) null default 0.00,
  
  -- Future approval types (ready for expansion)
  can_approve_leave_requests boolean not null default false,
  
  -- Metadata
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  created_by uuid null,
  updated_by uuid null,
  is_active boolean not null default true,
  
  -- Constraints
  constraint approval_permissions_pkey primary key (id),
  constraint approval_permissions_user_id_key unique (user_id),
  constraint approval_permissions_user_id_fkey foreign key (user_id) references users (id) on delete cascade,
  constraint approval_permissions_created_by_fkey foreign key (created_by) references users (id) on delete set null,
  constraint approval_permissions_updated_by_fkey foreign key (updated_by) references users (id) on delete set null,
  
  -- Check constraints for amount limits
  constraint approval_permissions_requisition_limit_check check (requisition_amount_limit >= 0),
  constraint approval_permissions_single_bill_limit_check check (single_bill_amount_limit >= 0),
  constraint approval_permissions_multiple_bill_limit_check check (multiple_bill_amount_limit >= 0),
  constraint approval_permissions_recurring_bill_limit_check check (recurring_bill_amount_limit >= 0),
  constraint approval_permissions_vendor_payment_limit_check check (vendor_payment_amount_limit >= 0)
) tablespace pg_default;

-- Indexes for performance
create index if not exists idx_approval_permissions_user_id 
  on public.approval_permissions using btree (user_id) tablespace pg_default;

create index if not exists idx_approval_permissions_requisitions 
  on public.approval_permissions using btree (can_approve_requisitions) tablespace pg_default
  where (can_approve_requisitions = true and is_active = true);

create index if not exists idx_approval_permissions_single_bill 
  on public.approval_permissions using btree (can_approve_single_bill) tablespace pg_default
  where (can_approve_single_bill = true and is_active = true);

create index if not exists idx_approval_permissions_multiple_bill 
  on public.approval_permissions using btree (can_approve_multiple_bill) tablespace pg_default
  where (can_approve_multiple_bill = true and is_active = true);

create index if not exists idx_approval_permissions_recurring_bill 
  on public.approval_permissions using btree (can_approve_recurring_bill) tablespace pg_default
  where (can_approve_recurring_bill = true and is_active = true);

create index if not exists idx_approval_permissions_vendor_payments 
  on public.approval_permissions using btree (can_approve_vendor_payments) tablespace pg_default
  where (can_approve_vendor_payments = true and is_active = true);

-- Enable RLS
alter table public.approval_permissions enable row level security;

-- RLS Policies
-- Only authenticated users can view approval permissions
create policy "Users can view approval permissions"
  on public.approval_permissions
  for select
  using (auth.role() = 'authenticated');

-- Only admins can insert/update/delete approval permissions
create policy "Admins can manage approval permissions"
  on public.approval_permissions
  for all
  using (
    exists (
      select 1 from users
      where users.id = auth.uid()
      and users.role_type = 'Master Admin'
    )
  );

-- Function to automatically update updated_at timestamp
create or replace function update_approval_permissions_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger to update timestamp
create trigger update_approval_permissions_timestamp
  before update on public.approval_permissions
  for each row
  execute function update_approval_permissions_updated_at();

-- Comment on table
comment on table public.approval_permissions is 'Stores granular approval permissions for different types of requests (requisitions, schedules, vendor payments, etc.)';

-- Comments on columns
comment on column public.approval_permissions.user_id is 'Reference to the user who has these approval permissions';
comment on column public.approval_permissions.can_approve_requisitions is 'Whether user can approve expense requisitions';
comment on column public.approval_permissions.requisition_amount_limit is 'Maximum amount user can approve for requisitions (0 = unlimited)';
comment on column public.approval_permissions.can_approve_single_bill is 'Whether user can approve single bill payment schedules';
comment on column public.approval_permissions.single_bill_amount_limit is 'Maximum amount user can approve for single bills (0 = unlimited)';
comment on column public.approval_permissions.can_approve_multiple_bill is 'Whether user can approve multiple bill payment schedules';
comment on column public.approval_permissions.multiple_bill_amount_limit is 'Maximum amount user can approve for multiple bills (0 = unlimited)';
comment on column public.approval_permissions.can_approve_recurring_bill is 'Whether user can approve recurring bill payment schedules';
comment on column public.approval_permissions.recurring_bill_amount_limit is 'Maximum amount user can approve for recurring bills (0 = unlimited)';
comment on column public.approval_permissions.can_approve_vendor_payments is 'Whether user can approve vendor payments';
comment on column public.approval_permissions.vendor_payment_amount_limit is 'Maximum amount user can approve for vendor payments (0 = unlimited)';
comment on column public.approval_permissions.is_active is 'Whether these permissions are currently active';
