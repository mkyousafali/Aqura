create table public.expense_scheduler (
  id bigserial not null,
  branch_id bigint not null,
  branch_name text not null,
  expense_category_id bigint null,
  expense_category_name_en text null,
  expense_category_name_ar text null,
  requisition_id bigint null,
  requisition_number text null,
  co_user_id uuid null,
  co_user_name text null,
  bill_type text not null,
  bill_number text null,
  bill_date date null,
  payment_method text null,
  due_date date null,
  credit_period integer null,
  amount numeric not null,
  bill_file_url text null,
  description text null,
  notes text null,
  is_paid boolean null default false,
  paid_date timestamp with time zone null,
  status text null default 'pending'::text,
  created_by uuid not null,
  created_at timestamp with time zone null default now(),
  updated_by uuid null,
  updated_at timestamp with time zone null default now(),
  bank_name text null,
  iban text null,
  payment_reference character varying(255) null,
  schedule_type text null default 'single_bill'::text,
  recurring_type text null,
  recurring_metadata jsonb null,
  approver_id uuid null,
  approver_name text null,
  constraint expense_scheduler_pkey primary key (id),
  constraint fk_expense_scheduler_requisition foreign KEY (requisition_id) references expense_requisitions (id) on delete set null,
  constraint fk_expense_scheduler_branch foreign KEY (branch_id) references branches (id) on delete RESTRICT,
  constraint fk_expense_scheduler_category foreign KEY (expense_category_id) references expense_sub_categories (id) on delete set null,
  constraint fk_expense_scheduler_co_user foreign KEY (co_user_id) references users (id) on delete RESTRICT,
  constraint fk_expense_scheduler_created_by foreign KEY (created_by) references users (id) on delete RESTRICT,
  constraint fk_expense_scheduler_approver foreign KEY (approver_id) references users (id) on delete set null,
  constraint check_recurring_type_values check (
    (
      (
        (schedule_type <> 'recurring'::text)
        and (recurring_type is null)
      )
      or (
        (schedule_type = 'recurring'::text)
        and (
          recurring_type = any (
            array[
              'daily'::text,
              'weekly'::text,
              'monthly_date'::text,
              'monthly_day'::text,
              'yearly'::text,
              'half_yearly'::text,
              'quarterly'::text,
              'custom'::text
            ]
          )
        )
      )
    )
  ),
  constraint check_schedule_type_values check (
    (
      schedule_type = any (
        array[
          'single_bill'::text,
          'multiple_bill'::text,
          'recurring'::text,
          'expense_requisition'::text,
          'closed_requisition_bill'::text
        ]
      )
    )
  ),
  constraint check_co_user_for_non_recurring check (
    (
      (schedule_type = 'recurring'::text)
      or (schedule_type = 'expense_requisition'::text)
      or (schedule_type = 'closed_requisition_bill'::text)
      or (
        (
          schedule_type = any (array['single_bill'::text, 'multiple_bill'::text])
        )
        and (co_user_id is not null)
        and (co_user_name is not null)
      )
    )
  ),
  constraint check_approver_for_recurring check (
    (
      (schedule_type <> 'recurring'::text)
      or (
        (schedule_type = 'recurring'::text)
        and (approver_id is not null)
        and (approver_name is not null)
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_approver_id on public.expense_scheduler using btree (approver_id) TABLESPACE pg_default
where
  (approver_id is not null);

create index IF not exists idx_expense_scheduler_branch_id on public.expense_scheduler using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_category_id on public.expense_scheduler using btree (expense_category_id) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_co_user_id on public.expense_scheduler using btree (co_user_id) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_created_at on public.expense_scheduler using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_created_by on public.expense_scheduler using btree (created_by) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_credit_period on public.expense_scheduler using btree (credit_period) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_due_date on public.expense_scheduler using btree (due_date) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_is_paid on public.expense_scheduler using btree (is_paid) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_payment_reference on public.expense_scheduler using btree (payment_reference) TABLESPACE pg_default
where
  (payment_reference is not null);

create index IF not exists idx_expense_scheduler_recurring_type on public.expense_scheduler using btree (recurring_type) TABLESPACE pg_default
where
  (recurring_type is not null);

create index IF not exists idx_expense_scheduler_requisition_id on public.expense_scheduler using btree (requisition_id) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_schedule_type on public.expense_scheduler using btree (schedule_type) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_status on public.expense_scheduler using btree (status) TABLESPACE pg_default;

create index IF not exists idx_expense_scheduler_due_date_paid on public.expense_scheduler using btree (due_date, is_paid) TABLESPACE pg_default;

create trigger expense_scheduler_updated_at BEFORE
update on expense_scheduler for EACH row
execute FUNCTION update_expense_scheduler_updated_at ();

create trigger sync_requisition_balance_trigger
after INSERT
or
update on expense_scheduler for EACH row
execute FUNCTION sync_requisition_balance ();

create trigger trigger_update_requisition_balance
after INSERT
or DELETE
or
update on expense_scheduler for EACH row
execute FUNCTION update_requisition_balance ();

create trigger trigger_update_requisition_balance_old BEFORE DELETE
or
update on expense_scheduler for EACH row
execute FUNCTION update_requisition_balance_old ();