create table public.hr_salary_wages (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  branch_id uuid not null,
  basic_salary numeric(12, 2) not null,
  effective_from date not null,
  is_current boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint hr_salary_wages_pkey primary key (id),
  constraint hr_salary_wages_employee_id_fkey foreign KEY (employee_id) references hr_employees (id)
) TABLESPACE pg_default;

create index IF not exists idx_hr_salary_employee_id on public.hr_salary_wages using btree (employee_id) TABLESPACE pg_default;