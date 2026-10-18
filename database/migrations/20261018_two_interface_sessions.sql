begin;

alter table public.user_device_sessions
  drop constraint if exists user_device_sessions_user_interface_key;

create unique index if not exists user_device_sessions_user_interface_device_key
  on public.user_device_sessions(user_id, device_type, device_id);

create or replace function public.claim_interface_session(
  p_user_id uuid,
  p_device_type text,
  p_device_id text,
  p_device_name text default null,
  p_user_agent text default null,
  p_ip_address text default null
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_token text;
  v_id uuid;
  v_expiry timestamptz;
begin
  if p_user_id is null or nullif(btrim(p_device_id), '') is null then
    return jsonb_build_object('success', false, 'error', 'Invalid arguments');
  end if;
  if p_device_type not in ('mobile', 'desktop') then
    return jsonb_build_object('success', false, 'error', 'Invalid device_type');
  end if;

  -- Serialize claims for this user/interface so simultaneous tabs cannot
  -- temporarily exceed the two-session limit.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':' || p_device_type, 0));

  if p_device_type = 'desktop' then
    update public.user_device_sessions
       set is_active = false, session_token = encode(extensions.gen_random_bytes(24), 'hex'), updated_at = now()
     where user_id = p_user_id and device_type = 'desktop' and is_active = true
       and expires_at <= now();
    v_expiry := now() + interval '24 hours';
  else
    v_expiry := null;
  end if;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  insert into public.user_device_sessions
    (user_id, device_id, session_token, device_type, browser_name, user_agent,
     ip_address, is_active, login_at, last_activity, expires_at, updated_at)
  values
    (p_user_id, p_device_id, v_token, p_device_type, p_device_name, p_user_agent,
     nullif(p_ip_address, '')::inet, true, now(), now(), v_expiry, now())
  on conflict (user_id, device_type, device_id) do update
    set session_token = excluded.session_token, browser_name = excluded.browser_name,
        user_agent = excluded.user_agent, ip_address = excluded.ip_address,
        is_active = true, login_at = now(), last_activity = now(),
        expires_at = excluded.expires_at, updated_at = now()
  returning id into v_id;

  -- Rotate rather than delete the oldest token. Realtime clients see the
  -- token change immediately, while heartbeat remains the fallback.
  update public.user_device_sessions s
     set is_active = false,
         session_token = encode(extensions.gen_random_bytes(24), 'hex'),
         updated_at = now()
   where s.id in (
     select id from public.user_device_sessions
      where user_id = p_user_id and device_type = p_device_type
        and is_active = true and id <> v_id
      order by login_at desc, id desc
      offset 1
   );

  return jsonb_build_object('success', true, 'session_token', v_token, 'session_id', v_id);
end;
$$;

create or replace function public.heartbeat_interface_session(
  p_user_id uuid, p_device_type text, p_session_token text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_found boolean;
begin
  update public.user_device_sessions
     set last_activity = now(),
         expires_at = case when p_device_type = 'desktop' then now() + interval '24 hours' else null end,
         updated_at = now()
   where user_id = p_user_id and device_type = p_device_type
     and session_token = p_session_token and is_active = true
     and (p_device_type = 'mobile' or expires_at > now())
  returning true into v_found;
  return jsonb_build_object('valid', coalesce(v_found, false));
end;
$$;

create or replace function public.release_interface_session(
  p_user_id uuid, p_device_type text, p_session_token text
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_released boolean;
begin
  update public.user_device_sessions
     set is_active = false,
         session_token = encode(extensions.gen_random_bytes(24), 'hex'),
         updated_at = now()
   where user_id = p_user_id and device_type = p_device_type
     and session_token = p_session_token and is_active = true
  returning true into v_released;
  return jsonb_build_object('success', coalesce(v_released, false));
end;
$$;

create or replace function public.list_my_interface_sessions(
  p_user_id uuid, p_session_token text
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.user_device_sessions
     where user_id = p_user_id and session_token = p_session_token and is_active = true
  ) then raise insufficient_privilege using message = 'Invalid interface session'; end if;

  update public.user_device_sessions
     set is_active = false, updated_at = now()
   where user_id = p_user_id and device_type = 'desktop' and is_active = true
     and expires_at <= now();

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', id, 'interface_type', device_type, 'login_at', login_at,
      'last_activity', last_activity, 'is_current', session_token = p_session_token
    ) order by login_at desc)
    from public.user_device_sessions
    where user_id = p_user_id and is_active = true
  ), '[]'::jsonb);
end;
$$;

create or replace function public.logout_my_interface_session(
  p_user_id uuid, p_current_session_token text, p_session_id uuid
) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_target_token text;
begin
  if not exists (
    select 1 from public.user_device_sessions
     where user_id = p_user_id and session_token = p_current_session_token and is_active = true
  ) then raise insufficient_privilege using message = 'Invalid interface session'; end if;

  select session_token into v_target_token from public.user_device_sessions
   where id = p_session_id and user_id = p_user_id and is_active = true;
  if v_target_token is null then return jsonb_build_object('success', false, 'error', 'Session not found'); end if;
  if v_target_token = p_current_session_token then return jsonb_build_object('success', false, 'error', 'Current session cannot be logged out here'); end if;

  update public.user_device_sessions
     set is_active = false, session_token = encode(extensions.gen_random_bytes(24), 'hex'), updated_at = now()
   where id = p_session_id and user_id = p_user_id;
  return jsonb_build_object('success', true);
end;
$$;

revoke all on function public.list_my_interface_sessions(uuid, text) from public;
revoke all on function public.logout_my_interface_session(uuid, text, uuid) from public;
grant execute on function public.list_my_interface_sessions(uuid, text) to anon, authenticated;
grant execute on function public.logout_my_interface_session(uuid, text, uuid) to anon, authenticated;

comment on table public.user_device_sessions is
  'Up to two active tab-scoped sessions per user and interface. Desktop expires after 24 hours of inactivity; Mobile persists until logout or eviction.';

commit;
