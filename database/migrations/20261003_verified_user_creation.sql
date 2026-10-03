begin;

alter table public.users
  add column if not exists email text,
  add column if not exists whatsapp_number text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('user-avatars', 'user-avatars', true, 5242880, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.user_creation_verifications (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid not null references public.users(id) on delete cascade,
  employee_id uuid not null references public.hr_employees(id) on delete cascade,
  email text not null,
  whatsapp_number text not null,
  email_otp_hash text not null,
  whatsapp_otp_hash text not null,
  email_verified_at timestamptz,
  whatsapp_verified_at timestamptz,
  email_attempts integer not null default 0,
  whatsapp_attempts integer not null default 0,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (email_attempts between 0 and 5),
  check (whatsapp_attempts between 0 and 5)
);

create index if not exists user_creation_verifications_actor_idx
  on public.user_creation_verifications (requested_by, created_at desc);

alter table public.user_creation_verifications enable row level security;
revoke all on public.user_creation_verifications from public, anon, authenticated;
grant all on public.user_creation_verifications to service_role;

create or replace function public.create_verified_user(
  p_verification_id uuid,
  p_username varchar,
  p_password varchar,
  p_is_master_admin boolean default false,
  p_is_admin boolean default false,
  p_user_type varchar default 'branch_specific',
  p_branch_id bigint default null,
  p_position_id uuid default null,
  p_quick_access_code varchar default null,
  p_avatar text default null,
  p_requesting_user_id uuid default null
) returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_verification public.user_creation_verifications%rowtype;
  v_user_id uuid;
  v_quick_access_code varchar(6);
  v_password_hash text;
  v_quick_access_hash text;
  v_salt text;
  v_quick_access_salt text;
  v_requester_is_master boolean := false;
  v_requester_can_create boolean := false;
begin
  select * into v_verification
  from public.user_creation_verifications
  where id = p_verification_id
  for update;

  if v_verification.id is null
     or v_verification.requested_by <> p_requesting_user_id
     or v_verification.consumed_at is not null
     or v_verification.expires_at <= now()
     or v_verification.email_verified_at is null
     or v_verification.whatsapp_verified_at is null then
    return json_build_object('success', false, 'message', 'Email and WhatsApp verification is required');
  end if;

  select coalesce(u.is_master_admin, false) into v_requester_is_master
  from public.users u where u.id = p_requesting_user_id and u.status = 'active';

  select exists (
    select 1 from public.button_permissions bp
    where bp.user_id = p_requesting_user_id
      and bp.button_code = 'CREATE_USER' and bp.is_enabled = true
  ) into v_requester_can_create;

  if not coalesce(v_requester_is_master, false)
     and not coalesce(v_requester_can_create, false) then
    return json_build_object('success', false, 'message', 'Access denied: Create User permission required');
  end if;

  if (coalesce(p_is_admin, false) or coalesce(p_is_master_admin, false))
     and not coalesce(v_requester_is_master, false) then
    return json_build_object('success', false, 'message', 'Only a Master Admin can create Admin or Master Admin users');
  end if;

  if p_user_type not in ('global', 'branch_specific')
     or (p_user_type = 'branch_specific' and p_branch_id is null) then
    return json_build_object('success', false, 'message', 'A branch is required for branch-specific users');
  end if;

  if length(trim(coalesce(p_username, ''))) < 3 or length(p_username) > 50 then
    return json_build_object('success', false, 'message', 'Username must contain 3 to 50 characters');
  end if;

  if length(coalesce(p_password, '')) < 8
     or p_password !~ '[A-Z]'
     or p_password !~ '[a-z]'
     or p_password !~ '[0-9]'
     or p_password !~ '[^A-Za-z0-9]' then
    return json_build_object('success', false, 'message', 'Password does not meet security requirements');
  end if;

  if p_quick_access_code is not null and p_quick_access_code !~ '^[0-9]{6}$' then
    return json_build_object('success', false, 'message', 'Access code must contain exactly six digits');
  end if;

  if not exists (
    select 1 from public.hr_employees e
    where e.id = v_verification.employee_id
      and e.status = 'active'
      and (p_user_type = 'global' or e.branch_id = p_branch_id)
  ) then
    return json_build_object('success', false, 'message', 'The selected employee is not active in the selected branch');
  end if;

  if exists (select 1 from public.users where username = p_username) then
    return json_build_object('success', false, 'message', 'Username already exists');
  end if;

  if exists (select 1 from public.users where employee_id = v_verification.employee_id and status <> 'inactive') then
    return json_build_object('success', false, 'message', 'This employee already has an active user account');
  end if;

  if exists (
    select 1 from public.users
    where status <> 'inactive'
      and (lower(email) = lower(v_verification.email) or whatsapp_number = v_verification.whatsapp_number)
  ) then
    return json_build_object('success', false, 'message', 'The verified email or WhatsApp number is already assigned to an active user');
  end if;

  v_quick_access_code := p_quick_access_code;
  if v_quick_access_code is null then
    loop
      v_quick_access_code := lpad(((('x' || encode(gen_random_bytes(4), 'hex'))::bit(32)::bigint % 1000000)::integer)::text, 6, '0');
      exit when not exists (
        select 1 from public.users
        where extensions.crypt(v_quick_access_code, quick_access_code) = quick_access_code
      );
    end loop;
  elsif exists (
    select 1 from public.users
    where extensions.crypt(v_quick_access_code, quick_access_code) = quick_access_code
  ) then
    return json_build_object('success', false, 'message', 'Quick access code already exists');
  end if;

  v_salt := extensions.gen_salt('bf');
  v_quick_access_salt := extensions.gen_salt('bf');
  v_password_hash := extensions.crypt(p_password, v_salt);
  v_quick_access_hash := extensions.crypt(v_quick_access_code, v_quick_access_salt);

  insert into public.users (
    username, password_hash, salt, quick_access_code, quick_access_salt,
    is_master_admin, is_admin, user_type, branch_id, employee_id, position_id,
    avatar, email, whatsapp_number, status, is_first_login,
    failed_login_attempts, created_at, updated_at
  ) values (
    p_username, v_password_hash, v_salt, v_quick_access_hash, v_quick_access_salt,
    coalesce(p_is_master_admin, false), coalesce(p_is_admin, false),
    p_user_type::public.user_type_enum, p_branch_id, v_verification.employee_id, p_position_id,
    p_avatar, v_verification.email, v_verification.whatsapp_number, 'active', true,
    0, now(), now()
  ) returning id into v_user_id;

  update public.hr_employee_master
  set email = v_verification.email,
      whatsapp_number = v_verification.whatsapp_number,
      updated_at = now()
  where id = v_verification.employee_id::text;

  update public.user_creation_verifications
  set consumed_at = now()
  where id = v_verification.id;

  return json_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_verification.email,
    'quick_access_code', v_quick_access_code,
    'message', 'User created successfully'
  );
exception when others then
  return json_build_object('success', false, 'message', sqlerrm);
end;
$$;

revoke all on function public.create_verified_user(uuid, varchar, varchar, boolean, boolean, varchar, bigint, uuid, varchar, text, uuid)
  from public, anon, authenticated;
grant execute on function public.create_verified_user(uuid, varchar, varchar, boolean, boolean, varchar, bigint, uuid, varchar, text, uuid)
  to service_role;

commit;
