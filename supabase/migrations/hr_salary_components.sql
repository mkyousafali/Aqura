create table public.hr_salary_components (
  id uuid not null default extensions.uuid_generate_v4 (),
  salary_id uuid not null,
  employee_id uuid not null,
  component_type character varying(20) not null,
  component_name character varying(100) not null,
  amount numeric(12, 2) not null,
  is_enabled boolean null default true,
  application_type character varying(20) null,
  single_month character varying(7) null,
  start_month character varying(7) null,
  end_month character varying(7) null,
  created_at timestamp with time zone null default now(),
  constraint hr_salary_components_pkey primary key (id),
  constraint hr_salary_components_employee_id_fkey foreign KEY (employee_id) references hr_employees (id),
  constraint hr_salary_components_salary_id_fkey foreign KEY (salary_id) references hr_salary_wages (id),
  constraint chk_hr_components_app_type check (
    (
      (application_type)::text = any (
        (
          array[
            'single'::character varying,
            'multiple'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint chk_hr_components_type check (
    (
      (component_type)::text = any (
        (
          array[
            'ALLOWANCE'::character varying,
            'DEDUCTION'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_hr_components_employee_id on public.hr_salary_components using btree (employee_id) TABLESPACE pg_default;