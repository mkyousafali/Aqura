create table public.receiving_tasks (
  id uuid not null default gen_random_uuid (),
  receiving_record_id uuid not null,
  task_id uuid not null,
  assignment_id uuid not null,
  role_type character varying(50) not null,
  assigned_user_id uuid null,
  requires_erp_reference boolean null default false,
  requires_original_bill_upload boolean null default false,
  requires_reassignment boolean null default false,
  requires_task_finished_mark boolean null default true,
  erp_reference_number character varying(255) null,
  original_bill_uploaded boolean null default false,
  original_bill_file_path text null,
  task_completed boolean null default false,
  completed_at timestamp with time zone null,
  clearance_certificate_url text null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint receiving_tasks_pkey primary key (id),
  constraint receiving_tasks_assigned_user_id_fkey foreign KEY (assigned_user_id) references users (id) on delete set null,
  constraint receiving_tasks_assignment_id_fkey foreign KEY (assignment_id) references task_assignments (id) on delete CASCADE,
  constraint receiving_tasks_receiving_record_id_fkey foreign KEY (receiving_record_id) references receiving_records (id) on delete CASCADE,
  constraint receiving_tasks_task_id_fkey foreign KEY (task_id) references tasks (id) on delete CASCADE,
  constraint receiving_tasks_role_type_check check (
    (
      (role_type)::text = any (
        array[
          ('branch_manager'::character varying)::text,
          ('purchase_manager'::character varying)::text,
          ('inventory_manager'::character varying)::text,
          ('night_supervisor'::character varying)::text,
          ('warehouse_handler'::character varying)::text,
          ('shelf_stocker'::character varying)::text,
          ('accountant'::character varying)::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_receiving_record_id on public.receiving_tasks using btree (receiving_record_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_task_id on public.receiving_tasks using btree (task_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_assignment_id on public.receiving_tasks using btree (assignment_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_assigned_user_id on public.receiving_tasks using btree (assigned_user_id) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_role_type on public.receiving_tasks using btree (role_type) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_task_completed on public.receiving_tasks using btree (task_completed) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_created_at on public.receiving_tasks using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_user_role on public.receiving_tasks using btree (assigned_user_id, role_type) TABLESPACE pg_default;

create index IF not exists idx_receiving_tasks_record_role on public.receiving_tasks using btree (receiving_record_id, role_type) TABLESPACE pg_default;

create trigger trigger_update_receiving_tasks_updated_at BEFORE
update on receiving_tasks for EACH row
execute FUNCTION update_receiving_tasks_updated_at ();