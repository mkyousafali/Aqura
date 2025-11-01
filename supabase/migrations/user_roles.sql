create table public.user_roles (
  id uuid not null default extensions.uuid_generate_v4 (),
  role_name character varying(100) not null,
  role_code character varying(50) not null,
  description text null,
  is_system_role boolean null default false,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  created_by uuid null,
  updated_by uuid null,
  constraint user_roles_pkey primary key (id),
  constraint user_roles_role_code_key unique (role_code),
  constraint user_roles_role_name_key unique (role_name)
) TABLESPACE pg_default;

create index IF not exists idx_user_roles_code on public.user_roles using btree (role_code) TABLESPACE pg_default
where
  (is_active = true);

create trigger update_user_roles_updated_at BEFORE
update on user_roles for EACH row
execute FUNCTION update_updated_at_column ();