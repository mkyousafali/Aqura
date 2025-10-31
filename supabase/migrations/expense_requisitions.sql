create table public.expense_requisitions (
  id bigserial not null,
  requisition_number text not null,
  branch_id bigint not null,
  branch_name text not null,
  approver_id uuid null,
  approver_name text null,
  expense_category_id bigint null,
  expense_category_name_en text null,
  expense_category_name_ar text null,
  requester_id text not null,
  requester_name text not null,
  requester_contact text not null,
  vat_applicable boolean null default false,
  amount numeric(15, 2) not null,
  payment_category text not null,
  description text null,
  status text null default 'pending'::text,
  image_url text null,
  created_by uuid not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  credit_period integer null,
  bank_name text null,
  iban text null,
  used_amount numeric null default 0,
  remaining_balance numeric null default 0,
  requester_ref_id uuid null,
  is_active boolean not null default true,
  constraint expense_requisitions_pkey primary key (id),
  constraint expense_requisitions_requisition_number_key unique (requisition_number),
  constraint expense_requisitions_expense_category_id_fkey foreign KEY (expense_category_id) references expense_sub_categories (id),
  constraint expense_requisitions_requester_ref_id_fkey foreign KEY (requester_ref_id) references requesters (id)
) TABLESPACE pg_default;

create index IF not exists idx_expense_requisitions_is_active on public.expense_requisitions using btree (is_active) TABLESPACE pg_default
where
  (is_active = true);

create index IF not exists idx_expense_requisitions_status_active on public.expense_requisitions using btree (status, is_active) TABLESPACE pg_default;

create index IF not exists idx_expense_requisitions_remaining_balance on public.expense_requisitions using btree (remaining_balance) TABLESPACE pg_default;

create index IF not exists idx_expense_requisitions_requester_ref on public.expense_requisitions using btree (requester_ref_id) TABLESPACE pg_default;

create index IF not exists idx_requisitions_branch on public.expense_requisitions using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_requisitions_status on public.expense_requisitions using btree (status) TABLESPACE pg_default;

create index IF not exists idx_requisitions_created_at on public.expense_requisitions using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_requisitions_number on public.expense_requisitions using btree (requisition_number) TABLESPACE pg_default;