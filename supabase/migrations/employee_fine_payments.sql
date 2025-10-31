create table public.employee_fine_payments (
  id uuid not null default extensions.uuid_generate_v4 (),
  warning_id uuid null,
  payment_method character varying(50) null,
  payment_amount numeric(10, 2) not null,
  payment_currency character varying(3) null default 'USD'::character varying,
  payment_date timestamp without time zone null default CURRENT_TIMESTAMP,
  payment_reference character varying(100) null,
  payment_notes text null,
  processed_by uuid null,
  processed_by_username character varying(255) null,
  account_code character varying(50) null,
  transaction_id character varying(100) null,
  receipt_number character varying(100) null,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  updated_at timestamp without time zone null default CURRENT_TIMESTAMP,
  constraint employee_fine_payments_pkey primary key (id),
  constraint employee_fine_payments_processed_by_fkey foreign KEY (processed_by) references users (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_fine_payments_warning_id on public.employee_fine_payments using btree (warning_id) TABLESPACE pg_default;

create index IF not exists idx_fine_payments_payment_date on public.employee_fine_payments using btree (payment_date) TABLESPACE pg_default;

create index IF not exists idx_fine_payments_processed_by on public.employee_fine_payments using btree (processed_by) TABLESPACE pg_default;