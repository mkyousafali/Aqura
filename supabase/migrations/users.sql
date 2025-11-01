create table public.users (
  id uuid not null default extensions.uuid_generate_v4 (),
  username character varying(50) not null,
  password_hash character varying(255) not null,
  salt character varying(100) not null,
  quick_access_code character varying(6) not null,
  quick_access_salt character varying(100) not null,
  user_type public.user_type_enum not null default 'branch_specific'::user_type_enum,
  employee_id uuid null,
  branch_id bigint null,
  role_type public.role_type_enum null default 'Position-based'::role_type_enum,
  position_id uuid null,
  avatar text null,
  avatar_small_url text null,
  avatar_medium_url text null,
  avatar_large_url text null,
  is_first_login boolean null default true,
  failed_login_attempts integer null default 0,
  locked_at timestamp with time zone null,
  locked_by uuid null,
  last_login_at timestamp with time zone null,
  password_expires_at timestamp with time zone null,
  last_password_change timestamp with time zone null default now(),
  created_by bigint null,
  updated_by bigint null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  status character varying(20) not null default 'active'::character varying,
  ai_translation_enabled boolean not null default false,
  can_approve_payments boolean null default false,
  approval_amount_limit numeric(15, 2) null default 0.00,
  constraint users_pkey primary key (id),
  constraint users_username_key unique (username),
  constraint users_quick_access_code_key unique (quick_access_code),
  constraint users_locked_by_fkey foreign KEY (locked_by) references users (id),
  constraint users_branch_id_fkey foreign KEY (branch_id) references branches (id) on delete set null,
  constraint users_employee_id_fkey foreign KEY (employee_id) references hr_employees (id) on delete set null,
  constraint users_employee_branch_check check (
    (
      (user_type = 'global'::user_type_enum)
      or (
        (user_type = 'branch_specific'::user_type_enum)
        and (branch_id is not null)
      )
    )
  ),
  constraint users_quick_access_length check ((length((quick_access_code)::text) = 6)),
  constraint users_quick_access_numeric check (((quick_access_code)::text ~ '^[0-9]{6}$'::text))
) TABLESPACE pg_default;

create index IF not exists idx_users_username on public.users using btree (username) TABLESPACE pg_default;

create unique INDEX IF not exists idx_users_quick_access on public.users using btree (quick_access_code) TABLESPACE pg_default;

create index IF not exists idx_users_role_type on public.users using btree (role_type) TABLESPACE pg_default;

create index IF not exists idx_users_employee_id on public.users using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_users_branch_id on public.users using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_users_created_at on public.users using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_users_last_login on public.users using btree (last_login_at) TABLESPACE pg_default;

create index IF not exists idx_users_employee_lookup on public.users using btree (employee_id) TABLESPACE pg_default
where
  (employee_id is not null);

create index IF not exists idx_users_branch_lookup on public.users using btree (branch_id) TABLESPACE pg_default
where
  (branch_id is not null);

create index IF not exists idx_users_position_lookup on public.users using btree (position_id) TABLESPACE pg_default
where
  (position_id is not null);

create index IF not exists idx_users_ai_translation_enabled on public.users using btree (ai_translation_enabled) TABLESPACE pg_default;

create index IF not exists idx_users_can_approve_payments on public.users using btree (can_approve_payments) TABLESPACE pg_default
where
  (can_approve_payments = true);

create trigger update_users_updated_at BEFORE
update on users for EACH row
execute FUNCTION update_updated_at_column ();

create trigger users_audit_trigger
after INSERT
or DELETE
or
update on users for EACH row
execute FUNCTION log_user_action ();