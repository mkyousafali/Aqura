begin;

create table if not exists public.attendance_monitoring_employees (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.hr_employee_master(id) on delete cascade,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id),
  unique (employee_id)
);

create table if not exists public.attendance_notification_recipients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  delivery_mode text not null default 'whatsapp_only'
    check (delivery_mode in ('whatsapp_only', 'whatsapp_and_email')),
  all_branches boolean not null default false,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id),
  unique (user_id)
);

create table if not exists public.attendance_notification_recipient_branches (
  recipient_id uuid not null references public.attendance_notification_recipients(id) on delete cascade,
  branch_id bigint not null references public.branches(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (recipient_id, branch_id)
);

create table if not exists public.attendance_no_show_alerts (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.hr_employee_master(id),
  branch_id bigint references public.branches(id),
  shift_date date not null,
  shift_key text not null,
  shift_name text,
  shift_start_at timestamptz not null,
  shift_end_at timestamptz,
  candidate_at timestamptz not null default now(),
  eligible_to_send_at timestamptz not null,
  last_checked_at timestamptz not null default now(),
  alert_type text not null default 'not_reported_for_duty',
  status text not null default 'pending_wait'
    check (status in (
      'pending_wait', 'cancelled_checked_in', 'cancelled_leave',
      'cancelled_day_off', 'cancelled_holiday', 'cancelled_ineligible',
      'ready', 'notification_created', 'completed',
      'completed_with_failures', 'no_matching_recipients'
    )),
  cancel_reason text,
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (employee_id, shift_date, shift_key, alert_type)
);

create table if not exists public.attendance_no_show_deliveries (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.attendance_no_show_alerts(id) on delete cascade,
  recipient_user_id uuid not null references public.users(id),
  channel text not null check (channel in ('in_app', 'whatsapp', 'email')),
  destination_snapshot text,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'retry_wait', 'permanent_failed', 'skipped')),
  attempt_count integer not null default 0 check (attempt_count between 0 and 3),
  next_retry_at timestamptz,
  provider_message_id text,
  sent_at timestamptz,
  last_error_code text,
  last_error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (alert_id, recipient_user_id, channel)
);

create index if not exists attendance_monitoring_enabled_idx
  on public.attendance_monitoring_employees (employee_id) where is_enabled;
create index if not exists attendance_recipients_enabled_idx
  on public.attendance_notification_recipients (user_id) where is_enabled;
create index if not exists attendance_recipient_branches_branch_idx
  on public.attendance_notification_recipient_branches (branch_id, recipient_id);
create index if not exists attendance_no_show_alerts_due_idx
  on public.attendance_no_show_alerts (status, eligible_to_send_at);
create index if not exists attendance_no_show_deliveries_retry_idx
  on public.attendance_no_show_deliveries (status, next_retry_at);

alter table public.attendance_monitoring_employees enable row level security;
alter table public.attendance_notification_recipients enable row level security;
alter table public.attendance_notification_recipient_branches enable row level security;
alter table public.attendance_no_show_alerts enable row level security;
alter table public.attendance_no_show_deliveries enable row level security;

revoke all on public.attendance_monitoring_employees from public, anon, authenticated;
revoke all on public.attendance_notification_recipients from public, anon, authenticated;
revoke all on public.attendance_notification_recipient_branches from public, anon, authenticated;
revoke all on public.attendance_no_show_alerts from public, anon, authenticated;
revoke all on public.attendance_no_show_deliveries from public, anon, authenticated;
grant all on public.attendance_monitoring_employees to service_role;
grant all on public.attendance_notification_recipients to service_role;
grant all on public.attendance_notification_recipient_branches to service_role;
grant all on public.attendance_no_show_alerts to service_role;
grant all on public.attendance_no_show_deliveries to service_role;

create or replace function public.get_attendance_notification_admin_data()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_result jsonb;
begin
  if not exists (
    select 1 from public.users
     where id = public.aqura_current_user_id()
       and status = 'active'
       and coalesce(is_master_admin, false) = true
  ) then
    raise exception 'Master Admin access required';
  end if;

  select jsonb_build_object(
    'employees', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id,
        'name_en', e.name_en,
        'name_ar', e.name_ar,
        'branch_id', e.current_branch_id,
        'branch_name_en', b.name_en,
        'branch_name_ar', b.name_ar,
        'enabled', coalesce(m.is_enabled, false)
      ) order by coalesce(e.name_en, e.name_ar, e.id))
      from public.hr_employee_master_with_status e
      left join public.branches b on b.id = e.current_branch_id
      left join public.attendance_monitoring_employees m on m.employee_id = e.id
      where e.employment_status = 'Job (With Finger)'
    ), '[]'::jsonb),
    'users', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', u.id,
        'username', u.username,
        'status', u.status,
        'name_en', e.name_en,
        'name_ar', e.name_ar,
        'whatsapp_number', e.whatsapp_number,
        'email', e.email,
        'contact_ready', (nullif(trim(e.whatsapp_number), '') is not null and nullif(trim(e.email), '') is not null),
        'recipient_id', r.id,
        'enabled', coalesce(r.is_enabled, false),
        'delivery_mode', coalesce(r.delivery_mode, 'whatsapp_only'),
        'all_branches', coalesce(r.all_branches, false),
        'branch_ids', coalesce((
          select jsonb_agg(rb.branch_id order by rb.branch_id)
          from public.attendance_notification_recipient_branches rb
          where rb.recipient_id = r.id
        ), '[]'::jsonb)
      ) order by u.username)
      from public.users u
      left join public.hr_employee_master e on e.user_id = u.id
      left join public.attendance_notification_recipients r on r.user_id = u.id
      where u.status = 'active'
    ), '[]'::jsonb),
    'branches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id,
        'name_en', b.name_en,
        'name_ar', b.name_ar,
        'location_en', b.location_en,
        'location_ar', b.location_ar
      ) order by b.name_en)
      from public.branches b where b.is_active = true
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$function$;

create or replace function public.set_attendance_monitored_employee(
  p_employee_id text,
  p_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_actor uuid := public.aqura_current_user_id();
begin
  if not exists (
    select 1 from public.users
     where id = v_actor and status = 'active' and coalesce(is_master_admin, false) = true
  ) then
    raise exception 'Master Admin access required';
  end if;

  if coalesce(p_enabled, false) and not exists (
    select 1 from public.hr_employee_master_with_status
     where id = p_employee_id and employment_status = 'Job (With Finger)'
  ) then
    raise exception 'Only Job (With Finger) employees can be monitored';
  end if;

  insert into public.attendance_monitoring_employees (
    employee_id, is_enabled, created_by, updated_by
  ) values (
    p_employee_id, coalesce(p_enabled, false), v_actor, v_actor
  )
  on conflict (employee_id) do update set
    is_enabled = excluded.is_enabled,
    updated_at = now(),
    updated_by = v_actor;

  return jsonb_build_object('success', true);
end;
$function$;

create or replace function public.set_attendance_notification_recipient(
  p_user_id uuid,
  p_enabled boolean,
  p_delivery_mode text,
  p_all_branches boolean,
  p_branch_ids bigint[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_recipient_id uuid;
  v_branch_ids bigint[] := coalesce(p_branch_ids, '{}');
begin
  if not exists (
    select 1 from public.users
     where id = v_actor and status = 'active' and coalesce(is_master_admin, false) = true
  ) then
    raise exception 'Master Admin access required';
  end if;

  if p_delivery_mode not in ('whatsapp_only', 'whatsapp_and_email') then
    raise exception 'Invalid delivery mode';
  end if;

  if coalesce(p_enabled, false) and not exists (
    select 1
      from public.users u
      join public.hr_employee_master e on e.user_id = u.id
     where u.id = p_user_id
       and u.status = 'active'
       and nullif(trim(e.whatsapp_number), '') is not null
       and nullif(trim(e.email), '') is not null
  ) then
    raise exception 'Recipient must be active and have both WhatsApp and email';
  end if;

  if coalesce(p_enabled, false) and not coalesce(p_all_branches, false)
     and cardinality(v_branch_ids) = 0 then
    raise exception 'Select at least one branch';
  end if;

  if exists (
    select 1 from unnest(v_branch_ids) branch_id
     where not exists (
       select 1 from public.branches b where b.id = branch_id and b.is_active = true
     )
  ) then
    raise exception 'One or more selected branches are invalid';
  end if;

  insert into public.attendance_notification_recipients (
    user_id, delivery_mode, all_branches, is_enabled, created_by, updated_by
  ) values (
    p_user_id, p_delivery_mode, coalesce(p_all_branches, false), coalesce(p_enabled, false), v_actor, v_actor
  )
  on conflict (user_id) do update set
    delivery_mode = excluded.delivery_mode,
    all_branches = excluded.all_branches,
    is_enabled = excluded.is_enabled,
    updated_at = now(),
    updated_by = v_actor
  returning id into v_recipient_id;

  delete from public.attendance_notification_recipient_branches
   where recipient_id = v_recipient_id;

  if not coalesce(p_all_branches, false) then
    insert into public.attendance_notification_recipient_branches (recipient_id, branch_id)
    select v_recipient_id, branch_id from unnest(v_branch_ids) branch_id
    on conflict do nothing;
  end if;

  return jsonb_build_object('success', true, 'recipient_id', v_recipient_id);
end;
$function$;

revoke all on function public.get_attendance_notification_admin_data() from public, anon;
revoke all on function public.set_attendance_monitored_employee(text, boolean) from public, anon;
revoke all on function public.set_attendance_notification_recipient(uuid, boolean, text, boolean, bigint[]) from public, anon;
grant execute on function public.get_attendance_notification_admin_data() to authenticated, service_role;
grant execute on function public.set_attendance_monitored_employee(text, boolean) to authenticated, service_role;
grant execute on function public.set_attendance_notification_recipient(uuid, boolean, text, boolean, bigint[]) to authenticated, service_role;

commit;
