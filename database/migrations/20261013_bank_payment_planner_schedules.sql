begin;

create table if not exists public.bank_payment_planner_schedules (
  id uuid primary key default gen_random_uuid(),
  schedule_date date not null unique,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_by uuid references public.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.bank_payment_planner_schedule_items (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.bank_payment_planner_schedules(id) on delete cascade,
  source_type text not null check (source_type in ('Bill', 'Expense')),
  source_id text not null,
  vendor_id text not null,
  vendor_name text not null,
  branch_location text,
  bill_number text,
  description text,
  bill_date date,
  entered_date timestamptz,
  due_date date,
  payment_method text,
  approval_status text,
  amount numeric(15,2) not null check (amount > 0),
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  unique (schedule_id, source_type, source_id)
);

create index if not exists idx_bank_payment_planner_items_schedule
  on public.bank_payment_planner_schedule_items(schedule_id);
create index if not exists idx_bank_payment_planner_items_vendor
  on public.bank_payment_planner_schedule_items(vendor_id);

alter table public.bank_payment_planner_schedules enable row level security;
alter table public.bank_payment_planner_schedule_items enable row level security;
revoke all on public.bank_payment_planner_schedules from public, anon, authenticated;
revoke all on public.bank_payment_planner_schedule_items from public, anon, authenticated;

create or replace function public.bank_planner_can_access(p_actor uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.users u
    where u.id = p_actor and u.status = 'active'
      and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp
        where bp.user_id = u.id and bp.button_code = 'BANK_PAYMENT_PLANNER' and bp.is_enabled
      ))
  );
$$;

create or replace function public.get_bank_payment_planner_schedule(p_schedule_date date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_schedule_id uuid;
begin
  if not public.bank_planner_can_access(v_actor) then
    raise exception 'Bank Payment Planner permission required.';
  end if;
  select id into v_schedule_id from public.bank_payment_planner_schedules
    where schedule_date = p_schedule_date;
  return jsonb_build_object(
    'schedule_id', v_schedule_id,
    'schedule_date', p_schedule_date,
    'items', coalesce((
      select jsonb_agg(to_jsonb(i) order by i.vendor_name, i.created_at)
      from public.bank_payment_planner_schedule_items i
      where i.schedule_id = v_schedule_id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.add_bank_payment_planner_schedule_items(
  p_schedule_date date, p_items jsonb
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_schedule_id uuid;
  v_item jsonb;
  v_added integer := 0;
begin
  if not public.bank_planner_can_access(v_actor) then
    raise exception 'Bank Payment Planner permission required.';
  end if;
  if p_schedule_date is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'A schedule date and at least one item are required.';
  end if;
  insert into public.bank_payment_planner_schedules(schedule_date, created_by, updated_by)
  values (p_schedule_date, v_actor, v_actor)
  on conflict (schedule_date) do update set updated_by = v_actor, updated_at = now()
  returning id into v_schedule_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    if v_item->>'source_type' not in ('Bill', 'Expense')
       or nullif(trim(v_item->>'source_id'), '') is null
       or nullif(trim(v_item->>'vendor_id'), '') is null
       or nullif(trim(v_item->>'vendor_name'), '') is null
       or coalesce((v_item->>'amount')::numeric, 0) <= 0 then
      raise exception 'Invalid schedule item.';
    end if;
    insert into public.bank_payment_planner_schedule_items(
      schedule_id, source_type, source_id, vendor_id, vendor_name, branch_location,
      bill_number, description, bill_date, entered_date, due_date, payment_method,
      approval_status, amount, created_by
    ) values (
      v_schedule_id, v_item->>'source_type', v_item->>'source_id', v_item->>'vendor_id',
      v_item->>'vendor_name', nullif(v_item->>'branch_location', ''), nullif(v_item->>'bill_number', ''),
      nullif(v_item->>'description', ''), nullif(v_item->>'bill_date', '')::date,
      nullif(v_item->>'entered_date', '')::timestamptz, nullif(v_item->>'due_date', '')::date,
      nullif(v_item->>'payment_method', ''), nullif(v_item->>'approval_status', ''),
      (v_item->>'amount')::numeric, v_actor
    ) on conflict (schedule_id, source_type, source_id) do nothing;
    if found then v_added := v_added + 1; end if;
  end loop;
  return jsonb_build_object('schedule_id', v_schedule_id, 'added', v_added);
end;
$$;

create or replace function public.remove_bank_payment_planner_scheduled_vendor(
  p_schedule_date date, p_vendor_id text
) returns integer language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_removed integer;
begin
  if not public.bank_planner_can_access(v_actor) then
    raise exception 'Bank Payment Planner permission required.';
  end if;
  delete from public.bank_payment_planner_schedule_items i
  using public.bank_payment_planner_schedules s
  where i.schedule_id = s.id and s.schedule_date = p_schedule_date and i.vendor_id = p_vendor_id;
  get diagnostics v_removed = row_count;
  update public.bank_payment_planner_schedules set updated_by = v_actor, updated_at = now()
    where schedule_date = p_schedule_date;
  return v_removed;
end;
$$;

revoke all on function public.bank_planner_can_access(uuid) from public, anon;
revoke all on function public.get_bank_payment_planner_schedule(date) from public, anon;
revoke all on function public.add_bank_payment_planner_schedule_items(date, jsonb) from public, anon;
revoke all on function public.remove_bank_payment_planner_scheduled_vendor(date, text) from public, anon;
grant execute on function public.bank_planner_can_access(uuid) to authenticated;
grant execute on function public.get_bank_payment_planner_schedule(date) to authenticated;
grant execute on function public.add_bank_payment_planner_schedule_items(date, jsonb) to authenticated;
grant execute on function public.remove_bank_payment_planner_scheduled_vendor(date, text) to authenticated;

notify pgrst, 'reload schema';
commit;
