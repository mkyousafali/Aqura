begin;

alter table public.users
  add column if not exists auth_user_id uuid;

alter table public.customers
  add column if not exists auth_user_id uuid;

create unique index if not exists users_auth_user_id_key
  on public.users (auth_user_id)
  where auth_user_id is not null;

create unique index if not exists customers_auth_user_id_key
  on public.customers (auth_user_id)
  where auth_user_id is not null;

comment on column public.users.auth_user_id is
  'Supabase Auth identity used by authenticated browser sessions. May equal users.id for legacy password accounts.';

comment on column public.customers.auth_user_id is
  'Supabase Auth identity used by authenticated customer browser sessions.';

commit;
