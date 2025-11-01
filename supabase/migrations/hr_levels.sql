create table public.hr_levels (
  id uuid not null default extensions.uuid_generate_v4 (),
  level_name_en character varying(100) not null,
  level_name_ar character varying(100) not null,
  level_order integer not null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint hr_levels_pkey primary key (id)
) TABLESPACE pg_default;