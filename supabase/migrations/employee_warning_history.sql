create table public.employee_warning_history (
  id uuid not null default extensions.uuid_generate_v4 (),
  warning_id uuid not null,
  action_type character varying(20) not null,
  old_values jsonb null,
  new_values jsonb null,
  changed_by uuid null,
  changed_by_username character varying(255) null,
  change_reason text null,
  created_at timestamp without time zone not null default CURRENT_TIMESTAMP,
  ip_address inet null,
  user_agent text null,
  constraint employee_warning_history_pkey primary key (id),
  constraint employee_warning_history_changed_by_fkey foreign KEY (changed_by) references users (id) on delete set null,
  constraint employee_warning_history_warning_id_fkey foreign KEY (warning_id) references employee_warnings (id) on delete CASCADE,
  constraint employee_warning_history_action_type_check check (
    (
      (action_type)::text = any (
        (
          array[
            'created'::character varying,
            'updated'::character varying,
            'deleted'::character varying,
            'status_changed'::character varying,
            'fine_paid'::character varying,
            'acknowledged'::character varying,
            'resolved'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_employee_warning_history_warning_id on public.employee_warning_history using btree (warning_id) TABLESPACE pg_default;

create index IF not exists idx_employee_warning_history_action_type on public.employee_warning_history using btree (action_type) TABLESPACE pg_default;

create index IF not exists idx_employee_warning_history_changed_by on public.employee_warning_history using btree (changed_by) TABLESPACE pg_default;

create index IF not exists idx_employee_warning_history_created_at on public.employee_warning_history using btree (created_at) TABLESPACE pg_default;