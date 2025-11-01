create table public.hr_position_assignments (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  position_id uuid not null,
  department_id uuid not null,
  level_id uuid not null,
  branch_id bigint not null,
  effective_date date not null default CURRENT_DATE,
  is_current boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint hr_position_assignments_pkey primary key (id),
  constraint hr_position_assignments_branch_id_fkey foreign KEY (branch_id) references branches (id),
  constraint hr_position_assignments_department_id_fkey foreign KEY (department_id) references hr_departments (id),
  constraint hr_position_assignments_employee_id_fkey foreign KEY (employee_id) references hr_employees (id),
  constraint hr_position_assignments_level_id_fkey foreign KEY (level_id) references hr_levels (id),
  constraint hr_position_assignments_position_id_fkey foreign KEY (position_id) references hr_positions (id)
) TABLESPACE pg_default;

create index IF not exists idx_hr_assignments_employee_id on public.hr_position_assignments using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_hr_assignments_branch_id on public.hr_position_assignments using btree (branch_id) TABLESPACE pg_default;