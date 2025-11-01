create table public.hr_departments (
  id uuid not null default extensions.uuid_generate_v4 (),
  department_name_en character varying(100) not null,
  department_name_ar character varying(100) not null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint hr_departments_pkey primary key (id)
) TABLESPACE pg_default;