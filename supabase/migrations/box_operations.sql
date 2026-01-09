-- Box Operations Table Schema
-- This table stores all box opening/closing operations with detailed denomination counts and reconciliation data

create table public.box_operations (
  id uuid not null default gen_random_uuid (),
  box_number smallint not null,
  branch_id integer not null,
  user_id uuid not null,
  denomination_record_id uuid not null,
  counts_before jsonb not null,
  counts_after jsonb not null,
  total_before numeric(15, 2) not null,
  total_after numeric(15, 2) not null,
  difference numeric(15, 2) not null,
  is_matched boolean not null,
  status character varying(20) not null default 'in_use'::character varying,
  start_time timestamp with time zone not null default now(),
  end_time timestamp with time zone null,
  notes text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  closing_details jsonb null,
  supervisor_verified_at timestamp with time zone null,
  supervisor_id uuid null,
  closing_start_date date null,
  closing_start_time time without time zone null,
  closing_end_date date null,
  closing_end_time time without time zone null,
  recharge_opening_balance numeric(15, 2) null,
  recharge_close_balance numeric(15, 2) null,
  recharge_sales numeric(15, 2) null,
  bank_mada numeric(15, 2) null,
  bank_visa numeric(15, 2) null,
  bank_mastercard numeric(15, 2) null,
  bank_google_pay numeric(15, 2) null,
  bank_other numeric(15, 2) null,
  bank_total numeric(15, 2) null,
  system_cash_sales numeric(15, 2) null,
  system_card_sales numeric(15, 2) null,
  system_return numeric(15, 2) null,
  difference_cash_sales numeric(15, 2) null,
  difference_card_sales numeric(15, 2) null,
  total_difference numeric(15, 2) null,
  closing_total numeric(15, 2) null,
  closing_cash_500 integer null,
  closing_cash_200 integer null,
  closing_cash_100 integer null,
  closing_cash_50 integer null,
  closing_cash_20 integer null,
  closing_cash_10 integer null,
  closing_cash_5 integer null,
  closing_cash_2 integer null,
  closing_cash_1 integer null,
  closing_cash_050 integer null,
  closing_cash_025 integer null,
  closing_coins integer null,
  total_cash_sales numeric(15, 2) null,
  cash_sales_per_count numeric(15, 2) null,
  vouchers_total numeric(15, 2) null,
  total_erp_cash_sales numeric(15, 2) null,
  total_erp_sales numeric(15, 2) null,
  suspense_paid jsonb null,
  suspense_received jsonb null,
  pos_before_url text null,
  completed_by_user_id uuid null,
  completed_by_name text null,
  constraint box_operations_pkey primary key (id),
  constraint box_operations_branch_id_fkey foreign KEY (branch_id) references branches (id) on delete CASCADE,
  constraint box_operations_denomination_record_id_fkey foreign KEY (denomination_record_id) references denomination_records (id) on delete CASCADE,
  constraint box_operations_supervisor_id_fkey foreign KEY (supervisor_id) references users (id) on delete set null,
  constraint box_operations_user_id_fkey foreign KEY (user_id) references users (id) on delete CASCADE,
  constraint box_operations_box_number_check check (
    (
      (box_number >= 1)
      and (box_number <= 12)
    )
  ),
  constraint box_operations_status_check check (
    (
      (status)::text = any (
        (
          array[
            'in_use'::character varying,
            'pending_close'::character varying,
            'completed'::character varying,
            'cancelled'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

-- Indexes for performance optimization
create index IF not exists idx_box_operations_box on public.box_operations using btree (box_number) TABLESPACE pg_default;

create index IF not exists idx_box_operations_branch on public.box_operations using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_box_operations_user on public.box_operations using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_box_operations_status on public.box_operations using btree (status) TABLESPACE pg_default;

create index IF not exists idx_box_operations_start_time on public.box_operations using btree (start_time desc) TABLESPACE pg_default;

create index IF not exists idx_box_operations_denomination on public.box_operations using btree (denomination_record_id) TABLESPACE pg_default;

create index IF not exists idx_box_operations_active on public.box_operations using btree (branch_id, status) TABLESPACE pg_default
where
  ((status)::text = 'in_use'::text);

create index IF not exists idx_box_operations_pos_before_url on public.box_operations using btree (pos_before_url) TABLESPACE pg_default;

-- Trigger to automatically update the updated_at timestamp
create trigger box_operations_updated_at BEFORE
update on box_operations for EACH row
execute FUNCTION update_box_operations_updated_at ();
