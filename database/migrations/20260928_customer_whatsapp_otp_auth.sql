begin;

create table if not exists public.customer_auth_settings (
  id boolean primary key default true check (id),
  otp_expiry_seconds integer not null default 120 check (otp_expiry_seconds between 30 and 600),
  max_failed_attempts integer not null default 3 check (max_failed_attempts between 1 and 10),
  lockout_hours integer not null default 24 check (lockout_hours between 1 and 168),
  updated_at timestamptz not null default now()
);

insert into public.customer_auth_settings (id)
values (true)
on conflict (id) do nothing;

update public.customer_auth_settings
set otp_expiry_seconds = 120,
    updated_at = now()
where id = true;

create table if not exists public.customer_auth_otp_requests (
  id uuid primary key default gen_random_uuid(),
  whatsapp_number text not null,
  customer_name text,
  purpose text not null check (purpose in ('registration', 'login')),
  otp_hash text not null,
  expires_at timestamptz not null,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists customer_auth_otp_phone_created_idx
  on public.customer_auth_otp_requests (whatsapp_number, created_at desc);

create table if not exists public.customer_auth_lockouts (
  whatsapp_number text primary key,
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.customer_auth_settings enable row level security;
alter table public.customer_auth_otp_requests enable row level security;
alter table public.customer_auth_lockouts enable row level security;

revoke all on public.customer_auth_settings from anon, authenticated;
revoke all on public.customer_auth_otp_requests from anon, authenticated;
revoke all on public.customer_auth_lockouts from anon, authenticated;
grant all on public.customer_auth_settings to service_role;
grant all on public.customer_auth_otp_requests to service_role;
grant all on public.customer_auth_lockouts to service_role;

create or replace function public.issue_customer_auth_otp(
  p_whatsapp_number text,
  p_purpose text,
  p_customer_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_phone text;
  v_customer public.customers%rowtype;
  v_settings public.customer_auth_settings%rowtype;
  v_lock public.customer_auth_lockouts%rowtype;
  v_otp text;
begin
  v_phone := regexp_replace(coalesce(p_whatsapp_number, ''), '[^0-9]', '', 'g');
  if length(v_phone) = 9 then v_phone := '966' || v_phone; end if;
  if v_phone !~ '^9665[0-9]{8}$' then
    return jsonb_build_object('success', false, 'error', 'invalid_phone', 'message', 'Enter a valid Saudi WhatsApp number.');
  end if;
  if p_purpose not in ('registration', 'login') then
    return jsonb_build_object('success', false, 'error', 'invalid_purpose');
  end if;

  select * into v_settings from public.customer_auth_settings where id = true;
  select * into v_lock from public.customer_auth_lockouts where whatsapp_number = v_phone;
  if v_lock.locked_until is not null and v_lock.locked_until > now() then
    return jsonb_build_object('success', false, 'error', 'locked', 'locked_until', v_lock.locked_until,
      'message', 'Too many failed attempts. Contact Customer Service or try again after the lockout ends.');
  end if;

  select * into v_customer
  from public.customers
  where regexp_replace(whatsapp_number, '[^0-9]', '', 'g') = v_phone
  limit 1;

  if p_purpose = 'login' then
    if v_customer.id is null then
      return jsonb_build_object('success', false, 'error', 'not_found', 'message', 'No account was found for this WhatsApp number.');
    end if;
    if v_customer.registration_status = 'deleted' then
      return jsonb_build_object('success', false, 'error', 'account_deleted', 'message', 'This account was deleted. Please register again.');
    end if;
    if v_customer.registration_status <> 'approved' then
      return jsonb_build_object('success', false, 'error', 'not_approved', 'message', 'This account is not active.');
    end if;
  else
    if length(trim(coalesce(p_customer_name, ''))) < 2 then
      return jsonb_build_object('success', false, 'error', 'invalid_name', 'message', 'Enter a valid customer name.');
    end if;
    if v_customer.id is not null and v_customer.registration_status not in ('pre_registered', 'deleted') then
      return jsonb_build_object('success', false, 'error', 'already_exists', 'message', 'An account with this WhatsApp number already exists.');
    end if;
  end if;

  delete from public.customer_auth_otp_requests
  where whatsapp_number = v_phone and verified_at is null;

  v_otp := lpad(floor(random() * 1000000)::integer::text, 6, '0');
  insert into public.customer_auth_otp_requests
    (whatsapp_number, customer_name, purpose, otp_hash, expires_at)
  values
    (v_phone, nullif(trim(p_customer_name), ''), p_purpose,
     encode(digest(v_otp::bytea, 'sha256'), 'hex'),
     now() + make_interval(secs => v_settings.otp_expiry_seconds));

  insert into public.customer_auth_lockouts (whatsapp_number, failed_attempts, locked_until, updated_at)
  values (v_phone, 0, null, now())
  on conflict (whatsapp_number) do update
    set failed_attempts = case when public.customer_auth_lockouts.locked_until <= now() then 0 else public.customer_auth_lockouts.failed_attempts end,
        locked_until = case when public.customer_auth_lockouts.locked_until <= now() then null else public.customer_auth_lockouts.locked_until end,
        updated_at = now();

  return jsonb_build_object('success', true, 'otp', v_otp, 'whatsapp_number', v_phone,
    'customer_name', coalesce(nullif(trim(p_customer_name), ''), v_customer.name),
    'expires_in_seconds', v_settings.otp_expiry_seconds);
end;
$$;

create or replace function public.verify_customer_auth_otp(
  p_whatsapp_number text,
  p_otp text,
  p_purpose text
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_phone text;
  v_request public.customer_auth_otp_requests%rowtype;
  v_customer public.customers%rowtype;
  v_settings public.customer_auth_settings%rowtype;
  v_lock public.customer_auth_lockouts%rowtype;
  v_failed integer;
  v_locked_until timestamptz;
begin
  v_phone := regexp_replace(coalesce(p_whatsapp_number, ''), '[^0-9]', '', 'g');
  if length(v_phone) = 9 then v_phone := '966' || v_phone; end if;
  select * into v_settings from public.customer_auth_settings where id = true;

  insert into public.customer_auth_lockouts (whatsapp_number, failed_attempts, updated_at)
  values (v_phone, 0, now()) on conflict (whatsapp_number) do nothing;
  select * into v_lock from public.customer_auth_lockouts where whatsapp_number = v_phone for update;
  if v_lock.locked_until is not null and v_lock.locked_until > now() then
    return jsonb_build_object('success', false, 'error', 'locked', 'locked_until', v_lock.locked_until,
      'message', 'Too many failed attempts. Contact Customer Service or try again after the lockout ends.');
  end if;
  if v_lock.locked_until is not null and v_lock.locked_until <= now() then
    update public.customer_auth_lockouts set failed_attempts = 0, locked_until = null, updated_at = now()
    where whatsapp_number = v_phone;
  end if;

  select * into v_request
  from public.customer_auth_otp_requests
  where whatsapp_number = v_phone and purpose = p_purpose and verified_at is null
  order by created_at desc limit 1 for update;

  if v_request.id is null then
    return jsonb_build_object('success', false, 'error', 'otp_not_found', 'message', 'Request a new OTP.');
  end if;
  if v_request.expires_at <= now() then
    return jsonb_build_object('success', false, 'error', 'otp_expired', 'message', 'The OTP expired. Request a new one.');
  end if;

  if encode(digest(coalesce(p_otp, '')::bytea, 'sha256'), 'hex') <> v_request.otp_hash then
    update public.customer_auth_lockouts
    set failed_attempts = failed_attempts + 1, updated_at = now()
    where whatsapp_number = v_phone
    returning failed_attempts into v_failed;

    if v_failed >= v_settings.max_failed_attempts then
      v_locked_until := now() + make_interval(hours => v_settings.lockout_hours);
      update public.customer_auth_lockouts set locked_until = v_locked_until where whatsapp_number = v_phone;
      delete from public.customer_auth_otp_requests where whatsapp_number = v_phone and verified_at is null;
      return jsonb_build_object('success', false, 'error', 'locked', 'locked_until', v_locked_until,
        'message', 'Too many failed attempts. Contact Customer Service or try again after the lockout ends.');
    end if;
    return jsonb_build_object('success', false, 'error', 'invalid_otp',
      'attempts_remaining', v_settings.max_failed_attempts - v_failed, 'message', 'Incorrect OTP.');
  end if;

  update public.customer_auth_otp_requests set verified_at = now() where id = v_request.id;
  update public.customer_auth_lockouts set failed_attempts = 0, locked_until = null, updated_at = now()
  where whatsapp_number = v_phone;

  select * into v_customer from public.customers
  where regexp_replace(whatsapp_number, '[^0-9]', '', 'g') = v_phone limit 1;

  if p_purpose = 'registration' then
    if v_customer.id is null then
      insert into public.customers (name, whatsapp_number, access_code, access_code_generated_at,
        registration_status, created_at, updated_at)
      values (v_request.customer_name, v_phone, null, null, 'approved', now(), now())
      returning * into v_customer;
    elsif v_customer.registration_status in ('pre_registered', 'deleted') then
      update public.customers
      set name = v_request.customer_name, whatsapp_number = v_phone, access_code = null,
          access_code_generated_at = null, registration_status = 'approved', updated_at = now()
      where id = v_customer.id returning * into v_customer;
    else
      return jsonb_build_object('success', false, 'error', 'already_exists', 'message', 'This account already exists.');
    end if;
  elsif p_purpose <> 'login' or v_customer.id is null or v_customer.registration_status <> 'approved' then
    return jsonb_build_object('success', false, 'error', 'account_unavailable', 'message', 'This account is not available.');
  end if;

  update public.customers set last_login_at = now() where id = v_customer.id;
  return jsonb_build_object('success', true, 'customer_id', v_customer.id,
    'customer_name', v_customer.name, 'whatsapp_number', v_customer.whatsapp_number,
    'registration_status', v_customer.registration_status);
end;
$$;

revoke all on function public.issue_customer_auth_otp(text, text, text) from public, anon, authenticated;
grant execute on function public.issue_customer_auth_otp(text, text, text) to service_role;
revoke all on function public.verify_customer_auth_otp(text, text, text) from public;
grant execute on function public.verify_customer_auth_otp(text, text, text) to anon, authenticated, service_role;

-- Permanent customer access codes remain in legacy records for administrative
-- compatibility, but are no longer a public Customer Interface login method.
revoke execute on function public.authenticate_customer_access_code(text) from public, anon, authenticated;

comment on table public.customer_auth_settings is 'Configurable WhatsApp OTP authentication limits for the Customer Interface.';
comment on table public.customer_auth_otp_requests is 'Short-lived, hashed Customer Interface registration and login OTPs.';
comment on table public.customer_auth_lockouts is 'Cross-request failed-attempt counters and 24-hour Customer Interface OTP lockouts.';

commit;
