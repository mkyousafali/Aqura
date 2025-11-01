create table public.non_approved_payment_scheduler (
  id bigserial not null,
  schedule_type text not null,
  branch_id bigint not null,
  branch_name text not null,
  expense_category_id bigint not null,
  expense_category_name_en text null,
  expense_category_name_ar text null,
  co_user_id uuid null,
  co_user_name text null,
  bill_type text null,
  bill_number text null,
  bill_date date null,
  payment_method text null,
  due_date date null,
  credit_period integer null,
  amount numeric not null,
  bill_file_url text null,
  bank_name text null,
  iban text null,
  description text null,
  notes text null,
  recurring_type text null,
  recurring_metadata jsonb null,
  approver_id uuid not null,
  approver_name text not null,
  approval_status text null default 'pending'::text,
  approved_at timestamp with time zone null,
  approved_by uuid null,
  rejection_reason text null,
  expense_scheduler_id bigint null,
  created_by uuid not null,
  created_at timestamp with time zone null default now(),
  updated_by uuid null,
  updated_at timestamp with time zone null default now(),
  constraint non_approved_payment_scheduler_pkey primary key (id),
  constraint fk_non_approved_scheduler_branch foreign KEY (branch_id) references branches (id) on delete RESTRICT,
  constraint fk_non_approved_scheduler_category foreign KEY (expense_category_id) references expense_sub_categories (id) on delete RESTRICT,
  constraint fk_non_approved_scheduler_co_user foreign KEY (co_user_id) references users (id) on delete RESTRICT,
  constraint fk_non_approved_scheduler_created_by foreign KEY (created_by) references users (id) on delete RESTRICT,
  constraint fk_non_approved_scheduler_expense_scheduler foreign KEY (expense_scheduler_id) references expense_scheduler (id) on delete set null,
  constraint fk_non_approved_scheduler_approved_by foreign KEY (approved_by) references users (id) on delete set null,
  constraint fk_non_approved_scheduler_approver foreign KEY (approver_id) references users (id) on delete RESTRICT,
  constraint check_non_approved_recurring_type check (
    (
      (recurring_type is null)
      or (
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
  ),
  constraint check_non_approved_schedule_type check (
    (
      schedule_type = any (
        array[
          'single_bill'::text,
          'multiple_bill'::text,
          'recurring'::text
        ]
      )
    )
  ),
  constraint check_non_approved_approval_status check (
    (
      approval_status = any (
        array[
          'pending'::text,
          'approved'::text,
          'rejected'::text
        ]
      )
    )
  ),
  constraint check_non_approved_co_user_for_non_recurring check (
    (
      (schedule_type = 'recurring'::text)
      or (
        (
          schedule_type = any (array['single_bill'::text, 'multiple_bill'::text])
        )
        and (co_user_id is not null)
        and (co_user_name is not null)
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_non_approved_scheduler_branch_id on public.non_approved_payment_scheduler using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_non_approved_scheduler_category_id on public.non_approved_payment_scheduler using btree (expense_category_id) TABLESPACE pg_default;

create index IF not exists idx_non_approved_scheduler_co_user_id on public.non_approved_payment_scheduler using btree (co_user_id) TABLESPACE pg_default
where
  (co_user_id is not null);

create index IF not exists idx_non_approved_scheduler_approver_id on public.non_approved_payment_scheduler using btree (approver_id) TABLESPACE pg_default;

create index IF not exists idx_non_approved_scheduler_created_by on public.non_approved_payment_scheduler using btree (created_by) TABLESPACE pg_default;

create index IF not exists idx_non_approved_scheduler_approval_status on public.non_approved_payment_scheduler using btree (approval_status) TABLESPACE pg_default;

create index IF not exists idx_non_approved_scheduler_schedule_type on public.non_approved_payment_scheduler using btree (schedule_type) TABLESPACE pg_default;

create index IF not exists idx_non_approved_scheduler_created_at on public.non_approved_payment_scheduler using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_non_approved_scheduler_expense_scheduler_id on public.non_approved_payment_scheduler using btree (expense_scheduler_id) TABLESPACE pg_default
where
  (expense_scheduler_id is not null);

create trigger non_approved_scheduler_updated_at BEFORE
update on non_approved_payment_scheduler for EACH row
execute FUNCTION update_non_approved_scheduler_updated_at ();