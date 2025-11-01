create table public.hr_fingerprint_transactions (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id character varying(10) not null,
  name character varying(200) null,
  branch_id bigint not null,
  transaction_date date not null,
  transaction_time time without time zone not null,
  punch_state character varying(20) not null,
  device_id character varying(50) null,
  created_at timestamp with time zone null default now(),
  constraint hr_fingerprint_transactions_pkey primary key (id),
  constraint hr_fingerprint_transactions_branch_id_fkey foreign KEY (branch_id) references branches (id),
  constraint chk_hr_fingerprint_punch check (
    (
      (punch_state)::text = any (
        (
          array[
            'Check In'::character varying,
            'Check Out'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_hr_fingerprint_employee_id on public.hr_fingerprint_transactions using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_hr_fingerprint_date on public.hr_fingerprint_transactions using btree (transaction_date) TABLESPACE pg_default;

create index IF not exists idx_hr_fingerprint_punch_state on public.hr_fingerprint_transactions using btree (punch_state) TABLESPACE pg_default;

create index IF not exists idx_hr_fingerprint_branch_id on public.hr_fingerprint_transactions using btree (branch_id) TABLESPACE pg_default;