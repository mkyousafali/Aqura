create table public.app_functions (
  id uuid not null default extensions.uuid_generate_v4 (),
  function_name character varying(100) not null,
  function_code character varying(50) not null,
  description text null,
  category character varying(50) null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint app_functions_pkey primary key (id),
  constraint app_functions_function_code_key unique (function_code),
  constraint app_functions_function_name_key unique (function_name)
) TABLESPACE pg_default;

create index IF not exists idx_app_functions_active on public.app_functions using btree (function_code) TABLESPACE pg_default
where
  (is_active = true);

create trigger update_app_functions_updated_at BEFORE
update on app_functions for EACH row
execute FUNCTION update_updated_at_column ();