create table public.hr_employees (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id character varying(10) not null,
  branch_id bigint not null,
  hire_date date null,
  status character varying(20) null default 'active'::character varying,
  created_at timestamp with time zone null default now(),
  name character varying(200) not null,
  constraint hr_employees_pkey primary key (id),
  constraint hr_employees_employee_id_branch_id_unique unique (employee_id, branch_id),
  constraint hr_employees_branch_id_fkey foreign KEY (branch_id) references branches (id)
) TABLESPACE pg_default;

create index IF not exists idx_hr_employees_employee_id_branch_id on public.hr_employees using btree (employee_id, branch_id) TABLESPACE pg_default;

create index IF not exists idx_hr_employees_employee_id on public.hr_employees using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_hr_employees_branch_id on public.hr_employees using btree (branch_id) TABLESPACE pg_default;