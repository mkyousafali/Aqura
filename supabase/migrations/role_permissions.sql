create table public.role_permissions (
  id uuid not null default extensions.uuid_generate_v4 (),
  role_id uuid not null,
  function_id uuid not null,
  can_view boolean null default false,
  can_add boolean null default false,
  can_edit boolean null default false,
  can_delete boolean null default false,
  can_export boolean null default false,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint role_permissions_pkey primary key (id),
  constraint role_permissions_role_id_function_id_key unique (role_id, function_id),
  constraint role_permissions_function_id_fkey foreign KEY (function_id) references app_functions (id) on delete CASCADE,
  constraint role_permissions_role_id_fkey foreign KEY (role_id) references user_roles (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_role_permissions_role_id on public.role_permissions using btree (role_id) TABLESPACE pg_default;

create index IF not exists idx_role_permissions_function_id on public.role_permissions using btree (function_id) TABLESPACE pg_default;

create index IF not exists idx_role_permissions_composite on public.role_permissions using btree (role_id, function_id) TABLESPACE pg_default;

create trigger update_role_permissions_updated_at BEFORE
update on role_permissions for EACH row
execute FUNCTION update_updated_at_column ();