create table public.user_audit_logs (
  id uuid not null default extensions.uuid_generate_v4 (),
  user_id uuid null,
  target_user_id uuid null,
  action character varying(100) not null,
  table_name character varying(100) null,
  record_id uuid null,
  old_values jsonb null,
  new_values jsonb null,
  ip_address inet null,
  user_agent text null,
  performed_by uuid null,
  created_at timestamp with time zone null default now(),
  constraint user_audit_logs_pkey primary key (id),
  constraint user_audit_logs_performed_by_fkey foreign KEY (performed_by) references users (id),
  constraint user_audit_logs_target_user_id_fkey foreign KEY (target_user_id) references users (id) on delete set null,
  constraint user_audit_logs_user_id_fkey foreign KEY (user_id) references users (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_user_audit_logs_user_id on public.user_audit_logs using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_user_audit_logs_action on public.user_audit_logs using btree (action) TABLESPACE pg_default;

create index IF not exists idx_user_audit_logs_created_at on public.user_audit_logs using btree (created_at) TABLESPACE pg_default;