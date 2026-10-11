begin;

create table if not exists public.employee_login_otp_settings (
  interface_type text primary key check (interface_type in ('cashier', 'mobile', 'desktop')),
  delivery_mode text not null default 'both' check (delivery_mode in ('disabled', 'email', 'whatsapp', 'both')),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users(id) on delete set null
);

insert into public.employee_login_otp_settings (interface_type, delivery_mode)
values ('cashier', 'both'), ('mobile', 'both'), ('desktop', 'both')
on conflict (interface_type) do nothing;

create table if not exists public.employee_login_otp_state (
  user_id uuid not null references public.users(id) on delete cascade,
  interface_type text not null check (interface_type in ('cashier', 'mobile', 'desktop')),
  failed_attempts integer not null default 0 check (failed_attempts between 0 and 3),
  delivery_count integer not null default 0 check (delivery_count between 0 and 3),
  delivery_window_started_at timestamptz,
  last_sent_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, interface_type)
);

create table if not exists public.employee_login_otp_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  interface_type text not null check (interface_type in ('cashier', 'mobile', 'desktop')),
  otp_hash text not null,
  delivery_mode text not null check (delivery_mode in ('email', 'whatsapp', 'both')),
  email_attempted boolean not null default false,
  email_delivered boolean not null default false,
  whatsapp_attempted boolean not null default false,
  whatsapp_delivered boolean not null default false,
  status text not null default 'pending_delivery' check (status in ('pending_delivery', 'active', 'delivery_failed', 'verified', 'expired', 'superseded')),
  expires_at timestamptz not null,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists employee_login_otp_requests_user_idx
  on public.employee_login_otp_requests (user_id, interface_type, created_at desc);

alter table public.employee_login_otp_settings enable row level security;
alter table public.employee_login_otp_state enable row level security;
alter table public.employee_login_otp_requests enable row level security;
revoke all on public.employee_login_otp_settings, public.employee_login_otp_state, public.employee_login_otp_requests from public, anon, authenticated;
grant all on public.employee_login_otp_settings, public.employee_login_otp_state, public.employee_login_otp_requests to service_role;

create or replace function public.prepare_employee_login_otp(p_user_id uuid, p_interface_type text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_mode text;
  v_user public.users%rowtype;
  v_state public.employee_login_otp_state%rowtype;
  v_otp text;
  v_request_id uuid;
  v_now timestamptz := clock_timestamp();
  v_retry integer;
  v_email text;
  v_whatsapp_number text;
begin
  if p_interface_type not in ('cashier', 'mobile', 'desktop') then
    return jsonb_build_object('success', false, 'error', 'invalid_interface');
  end if;

  select * into v_user from public.users where id = p_user_id for update;
  if v_user.id is null or v_user.status <> 'active' then
    return jsonb_build_object('success', false, 'error', 'account_inactive');
  end if;

  select
    coalesce(nullif(btrim(v_user.email), ''), nullif(btrim(employee.email), '')),
    coalesce(nullif(btrim(v_user.whatsapp_number), ''), nullif(btrim(employee.whatsapp_number), ''))
  into v_email, v_whatsapp_number
  from (values (1)) as seed(value)
  left join public.hr_employee_master employee on employee.user_id = p_user_id;

  select delivery_mode into v_mode
  from public.employee_login_otp_settings where interface_type = p_interface_type;
  v_mode := coalesce(v_mode, 'both');
  if v_mode = 'disabled' then
    return jsonb_build_object('success', true, 'otp_required', false);
  end if;

  insert into public.employee_login_otp_state (user_id, interface_type)
  values (p_user_id, p_interface_type)
  on conflict (user_id, interface_type) do nothing;
  select * into v_state from public.employee_login_otp_state
  where user_id = p_user_id and interface_type = p_interface_type for update;

  if v_state.delivery_window_started_at is null
     or v_state.delivery_window_started_at + interval '30 minutes' <= v_now then
    update public.employee_login_otp_state
    set delivery_count = 0, delivery_window_started_at = v_now, last_sent_at = null, updated_at = v_now
    where user_id = p_user_id and interface_type = p_interface_type
    returning * into v_state;
  end if;

  if v_state.last_sent_at is not null and v_state.last_sent_at + interval '30 seconds' > v_now then
    v_retry := greatest(1, ceil(extract(epoch from (v_state.last_sent_at + interval '30 seconds' - v_now)))::integer);
    return jsonb_build_object('success', false, 'error', 'resend_cooldown', 'retry_after_seconds', v_retry);
  end if;
  if v_state.delivery_count >= 3 then
    v_retry := greatest(1, ceil(extract(epoch from (v_state.delivery_window_started_at + interval '30 minutes' - v_now)))::integer);
    return jsonb_build_object('success', false, 'error', 'delivery_limit', 'retry_after_seconds', v_retry);
  end if;

  update public.employee_login_otp_requests
  set status = 'superseded'
  where user_id = p_user_id and interface_type = p_interface_type and status in ('pending_delivery', 'active');

  v_otp := lpad(((get_byte(gen_random_bytes(4), 0)::integer * 65536
    + get_byte(gen_random_bytes(4), 1)::integer * 256
    + get_byte(gen_random_bytes(4), 2)::integer) % 1000000)::text, 6, '0');

  insert into public.employee_login_otp_requests
    (user_id, interface_type, otp_hash, delivery_mode, expires_at)
  values
    (p_user_id, p_interface_type, encode(digest(v_otp::bytea, 'sha256'), 'hex'), v_mode, v_now + interval '2 minutes')
  returning id into v_request_id;

  update public.employee_login_otp_state
  set delivery_count = delivery_count + 1,
      delivery_window_started_at = coalesce(delivery_window_started_at, v_now),
      last_sent_at = v_now,
      updated_at = v_now
  where user_id = p_user_id and interface_type = p_interface_type;

  return jsonb_build_object(
    'success', true, 'otp_required', true, 'request_id', v_request_id,
    'otp', v_otp, 'delivery_mode', v_mode, 'email', v_email,
    'whatsapp_number', v_whatsapp_number, 'expires_in_seconds', 120,
    'resend_after_seconds', 30, 'deliveries_remaining', 2 - v_state.delivery_count
  );
end;
$$;

create or replace function public.complete_employee_login_otp_delivery(
  p_request_id uuid, p_email_attempted boolean, p_email_delivered boolean,
  p_whatsapp_attempted boolean, p_whatsapp_delivered boolean
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_request public.employee_login_otp_requests%rowtype;
begin
  select * into v_request from public.employee_login_otp_requests where id = p_request_id for update;
  if v_request.id is null or v_request.status <> 'pending_delivery' then
    return jsonb_build_object('success', false, 'error', 'request_not_pending');
  end if;
  if not coalesce(p_email_delivered, false) and not coalesce(p_whatsapp_delivered, false) then
    update public.employee_login_otp_requests set status = 'delivery_failed',
      email_attempted = coalesce(p_email_attempted, false), whatsapp_attempted = coalesce(p_whatsapp_attempted, false)
    where id = p_request_id;
    update public.employee_login_otp_state
    set delivery_count = greatest(0, delivery_count - 1),
        last_sent_at = case when delivery_count <= 1 then null else last_sent_at end,
        delivery_window_started_at = case when delivery_count <= 1 then null else delivery_window_started_at end,
        updated_at = now()
    where user_id = v_request.user_id and interface_type = v_request.interface_type;
    return jsonb_build_object('success', false, 'error', 'delivery_failed');
  end if;
  update public.employee_login_otp_requests set status = 'active',
    email_attempted = coalesce(p_email_attempted, false), email_delivered = coalesce(p_email_delivered, false),
    whatsapp_attempted = coalesce(p_whatsapp_attempted, false), whatsapp_delivered = coalesce(p_whatsapp_delivered, false)
  where id = p_request_id;
  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.verify_employee_login_otp(p_request_id uuid, p_interface_type text, p_otp text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_request public.employee_login_otp_requests%rowtype;
  v_state public.employee_login_otp_state%rowtype;
  v_attempts integer;
begin
  select * into v_request from public.employee_login_otp_requests where id = p_request_id for update;
  if v_request.id is null or v_request.interface_type <> p_interface_type or v_request.status <> 'active' then
    return jsonb_build_object('success', false, 'error', 'otp_not_found');
  end if;
  if v_request.expires_at <= now() then
    update public.employee_login_otp_requests set status = 'expired' where id = p_request_id;
    return jsonb_build_object('success', false, 'error', 'otp_expired');
  end if;

  insert into public.employee_login_otp_state (user_id, interface_type)
  values (v_request.user_id, p_interface_type) on conflict do nothing;
  select * into v_state from public.employee_login_otp_state
  where user_id = v_request.user_id and interface_type = p_interface_type for update;

  if encode(digest(coalesce(p_otp, '')::bytea, 'sha256'), 'hex') <> v_request.otp_hash then
    v_attempts := least(3, v_state.failed_attempts + 1);
    update public.employee_login_otp_state set failed_attempts = v_attempts, updated_at = now()
    where user_id = v_request.user_id and interface_type = p_interface_type;
    if v_attempts >= 3 then
      update public.users set status = 'inactive', updated_at = now() where id = v_request.user_id;
      update public.employee_login_otp_requests set status = 'superseded'
      where user_id = v_request.user_id and status in ('pending_delivery', 'active');
      delete from public.cashier_device_bindings where user_id = v_request.user_id;
      update public.user_device_sessions set is_active = false, updated_at = now() where user_id = v_request.user_id;
      update public.user_sessions set is_active = false where user_id = v_request.user_id;
      return jsonb_build_object('success', false, 'error', 'account_deactivated', 'user_id', v_request.user_id, 'attempts_remaining', 0);
    end if;
    return jsonb_build_object('success', false, 'error', 'invalid_otp', 'attempts_remaining', 3 - v_attempts);
  end if;

  update public.employee_login_otp_requests set status = 'verified', verified_at = now() where id = p_request_id;
  update public.employee_login_otp_state set failed_attempts = 0, updated_at = now() where user_id = v_request.user_id;
  update public.employee_login_otp_state
  set delivery_count = 0, delivery_window_started_at = null, last_sent_at = null, updated_at = now()
  where user_id = v_request.user_id and interface_type = p_interface_type;
  return jsonb_build_object('success', true, 'user_id', v_request.user_id);
end;
$$;

create or replace function public.reset_employee_login_otp_on_activation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'active' and old.status is distinct from 'active' then
    update public.employee_login_otp_state
    set failed_attempts = 0, delivery_count = 0, delivery_window_started_at = null, last_sent_at = null, updated_at = now()
    where user_id = new.id;
    update public.employee_login_otp_requests set status = 'superseded'
    where user_id = new.id and status in ('pending_delivery', 'active');
  end if;
  return new;
end;
$$;

drop trigger if exists reset_employee_login_otp_on_activation on public.users;
create trigger reset_employee_login_otp_on_activation
after update of status on public.users for each row
execute function public.reset_employee_login_otp_on_activation();

revoke all on function public.prepare_employee_login_otp(uuid, text) from public, anon, authenticated;
revoke all on function public.complete_employee_login_otp_delivery(uuid, boolean, boolean, boolean, boolean) from public, anon, authenticated;
revoke all on function public.verify_employee_login_otp(uuid, text, text) from public, anon, authenticated;
grant execute on function public.prepare_employee_login_otp(uuid, text) to service_role;
grant execute on function public.complete_employee_login_otp_delivery(uuid, boolean, boolean, boolean, boolean) to service_role;
grant execute on function public.verify_employee_login_otp(uuid, text, text) to service_role;

comment on table public.employee_login_otp_settings is 'Per-interface employee login OTP delivery controls.';
comment on table public.employee_login_otp_state is 'Persistent per-user, per-interface OTP failures and delivery throttles.';
comment on table public.employee_login_otp_requests is 'Short-lived hashed OTP challenges for employee interface login.';

commit;
