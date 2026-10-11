begin;

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

revoke all on function public.prepare_employee_login_otp(uuid, text) from public, anon, authenticated;
grant execute on function public.prepare_employee_login_otp(uuid, text) to service_role;

commit;
