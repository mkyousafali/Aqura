create table public.employee_warnings (
  id uuid not null default extensions.uuid_generate_v4 (),
  user_id uuid null,
  employee_id uuid null,
  username character varying(255) null,
  warning_type character varying(50) not null,
  has_fine boolean null default false,
  fine_amount numeric(10, 2) null default null::numeric,
  fine_currency character varying(3) null default 'USD'::character varying,
  fine_status character varying(20) null default 'pending'::character varying,
  fine_due_date date null,
  fine_paid_date timestamp without time zone null,
  fine_paid_amount numeric(10, 2) null default null::numeric,
  warning_text text not null,
  language_code character varying(5) not null default 'en'::character varying,
  task_id uuid null,
  task_title character varying(500) null,
  task_description text null,
  assignment_id uuid null,
  total_tasks_assigned integer null default 0,
  total_tasks_completed integer null default 0,
  total_tasks_overdue integer null default 0,
  completion_rate numeric(5, 2) null default 0,
  issued_by uuid null,
  issued_by_username character varying(255) null,
  issued_at timestamp without time zone null default CURRENT_TIMESTAMP,
  warning_status character varying(20) null default 'active'::character varying,
  acknowledged_at timestamp without time zone null,
  acknowledged_by uuid null,
  resolved_at timestamp without time zone null,
  resolved_by uuid null,
  resolution_notes text null,
  created_at timestamp without time zone null default CURRENT_TIMESTAMP,
  updated_at timestamp without time zone null default CURRENT_TIMESTAMP,
  branch_id bigint null,
  department_id uuid null,
  severity_level character varying(10) null default 'medium'::character varying,
  follow_up_required boolean null default false,
  follow_up_date date null,
  warning_reference character varying(50) null,
  warning_document_url text null,
  is_deleted boolean null default false,
  deleted_at timestamp without time zone null,
  deleted_by uuid null,
  fine_paid_at timestamp without time zone null,
  frontend_save_id character varying(50) null,
  fine_payment_note text null,
  fine_payment_method character varying(50) null default 'cash'::character varying,
  fine_payment_reference character varying(100) null,
  constraint employee_warnings_pkey primary key (id),
  constraint employee_warnings_warning_reference_key unique (warning_reference),
  constraint employee_warnings_deleted_by_fkey foreign KEY (deleted_by) references users (id) on delete set null,
  constraint employee_warnings_employee_id_fkey foreign KEY (employee_id) references hr_employees (id) on delete set null,
  constraint employee_warnings_issued_by_fkey foreign KEY (issued_by) references users (id) on delete set null,
  constraint employee_warnings_resolved_by_fkey foreign KEY (resolved_by) references users (id) on delete set null,
  constraint employee_warnings_acknowledged_by_fkey foreign KEY (acknowledged_by) references users (id) on delete set null,
  constraint employee_warnings_branch_id_fkey foreign KEY (branch_id) references branches (id) on delete set null,
  constraint employee_warnings_user_id_fkey foreign KEY (user_id) references users (id) on delete CASCADE,
  constraint employee_warnings_warning_type_check check (
    (
      (warning_type)::text = any (
        (
          array[
            'overall_performance_no_fine'::character varying,
            'overall_performance_fine_threat'::character varying,
            'overall_performance_with_fine'::character varying,
            'task_delay_no_fine'::character varying,
            'task_delay_fine_threat'::character varying,
            'task_delay_with_fine'::character varying,
            'task_incomplete_no_fine'::character varying,
            'task_quality_issue'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint employee_warnings_fine_status_check check (
    (
      (fine_status)::text = any (
        array[
          ('pending'::character varying)::text,
          ('paid'::character varying)::text,
          ('waived'::character varying)::text,
          ('cancelled'::character varying)::text
        ]
      )
    )
  ),
  constraint employee_warnings_warning_status_check check (
    (
      (warning_status)::text = any (
        array[
          ('active'::character varying)::text,
          ('acknowledged'::character varying)::text,
          ('resolved'::character varying)::text,
          ('escalated'::character varying)::text,
          ('cancelled'::character varying)::text
        ]
      )
    )
  ),
  constraint employee_warnings_severity_level_check check (
    (
      (severity_level)::text = any (
        array[
          ('low'::character varying)::text,
          ('medium'::character varying)::text,
          ('high'::character varying)::text,
          ('critical'::character varying)::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_user_id on public.employee_warnings using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_employee_id on public.employee_warnings using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_username on public.employee_warnings using btree (username) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_warning_type on public.employee_warnings using btree (warning_type) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_warning_status on public.employee_warnings using btree (warning_status) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_has_fine on public.employee_warnings using btree (has_fine) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_fine_status on public.employee_warnings using btree (fine_status) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_issued_at on public.employee_warnings using btree (issued_at) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_task_id on public.employee_warnings using btree (task_id) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_assignment_id on public.employee_warnings using btree (assignment_id) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_branch_id on public.employee_warnings using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_reference on public.employee_warnings using btree (warning_reference) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_deleted on public.employee_warnings using btree (is_deleted) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_issued_by on public.employee_warnings using btree (issued_by) TABLESPACE pg_default;

create index IF not exists idx_employee_warnings_severity on public.employee_warnings using btree (severity_level) TABLESPACE pg_default;

create unique INDEX IF not exists idx_employee_warnings_reference_unique on public.employee_warnings using btree (warning_reference) TABLESPACE pg_default
where
  (warning_reference is not null);

create index IF not exists idx_employee_warnings_user_type_date on public.employee_warnings using btree (user_id, warning_type, issued_at) TABLESPACE pg_default;

create trigger trigger_create_warning_history
after INSERT
or DELETE
or
update on employee_warnings for EACH row
execute FUNCTION create_warning_history ();

create trigger trigger_generate_warning_reference BEFORE INSERT on employee_warnings for EACH row
execute FUNCTION generate_warning_reference ();

create trigger trigger_update_warning_updated_at BEFORE
update on employee_warnings for EACH row
execute FUNCTION update_warning_updated_at ();