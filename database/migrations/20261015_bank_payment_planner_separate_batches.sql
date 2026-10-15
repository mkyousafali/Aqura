begin;

alter table public.bank_payment_planner_schedule_items
  add column if not exists application_batch_id uuid;

update public.bank_payment_planner_schedule_items
set application_batch_id = md5(schedule_id::text || ':' || vendor_id)::uuid
where application_batch_id is null;

alter table public.bank_payment_planner_schedule_items
  alter column application_batch_id set default gen_random_uuid(),
  alter column application_batch_id set not null;

create index if not exists idx_bank_payment_planner_items_application_batch
  on public.bank_payment_planner_schedule_items(application_batch_id);

create or replace function public.add_bank_payment_planner_schedule_items(
  p_schedule_date date, p_items jsonb
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_schedule_id uuid;
  v_batch_id uuid := gen_random_uuid();
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
       or nullif(v_item->>'source_branch_id', '') is null
       or not exists (select 1 from public.branches b where b.id = (v_item->>'source_branch_id')::bigint)
       or coalesce((v_item->>'amount')::numeric, 0) <= 0 then
      raise exception 'Invalid schedule item.';
    end if;
    insert into public.bank_payment_planner_schedule_items(
      schedule_id, application_batch_id, source_type, source_id, source_branch_id,
      vendor_id, vendor_name, branch_location, bill_number, description, bill_date,
      entered_date, due_date, payment_method, approval_status, amount, created_by
    ) values (
      v_schedule_id, v_batch_id, v_item->>'source_type', v_item->>'source_id',
      (v_item->>'source_branch_id')::bigint, v_item->>'vendor_id', v_item->>'vendor_name',
      nullif(v_item->>'branch_location', ''), nullif(v_item->>'bill_number', ''),
      nullif(v_item->>'description', ''), nullif(v_item->>'bill_date', '')::date,
      nullif(v_item->>'entered_date', '')::timestamptz, nullif(v_item->>'due_date', '')::date,
      nullif(v_item->>'payment_method', ''), nullif(v_item->>'approval_status', ''),
      (v_item->>'amount')::numeric, v_actor
    ) on conflict (schedule_id, source_type, source_id) do nothing;
    if found then v_added := v_added + 1; end if;
  end loop;
  return jsonb_build_object('schedule_id', v_schedule_id, 'application_batch_id', v_batch_id, 'added', v_added);
end;
$$;

drop function if exists public.remove_bank_payment_planner_scheduled_vendor(date, text);
create function public.remove_bank_payment_planner_scheduled_vendor(
  p_schedule_date date, p_vendor_id text, p_application_batch_id uuid
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
  where i.schedule_id = s.id and s.schedule_date = p_schedule_date
    and i.vendor_id = p_vendor_id and i.application_batch_id = p_application_batch_id;
  get diagnostics v_removed = row_count;
  update public.bank_payment_planner_schedules set updated_by = v_actor, updated_at = now()
    where schedule_date = p_schedule_date;
  return v_removed;
end;
$$;

drop function if exists public.set_bank_payment_planner_branch_bank(date, text, bigint, bigint, text);
create function public.set_bank_payment_planner_branch_bank(
  p_schedule_date date, p_vendor_id text, p_application_batch_id uuid,
  p_branch_id bigint, p_bank_ledger_id bigint, p_bank_ledger_name text
) returns integer language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_updated integer;
begin
  if not public.bank_planner_can_access(v_actor) then
    raise exception 'Bank Payment Planner permission required.';
  end if;
  if p_branch_id is null or not exists (
    select 1 from public.branches b where b.id = p_branch_id and b.is_active = true
  ) then raise exception 'Select an active paying branch.'; end if;
  if p_bank_ledger_id is null or nullif(trim(p_bank_ledger_name), '') is null then
    raise exception 'Select a bank ledger.';
  end if;
  update public.bank_payment_planner_schedule_items i
  set paid_from_branch_id = p_branch_id, bank_ledger_id = p_bank_ledger_id,
      bank_ledger_name = trim(p_bank_ledger_name)
  from public.bank_payment_planner_schedules s
  where i.schedule_id = s.id and s.schedule_date = p_schedule_date
    and i.vendor_id = p_vendor_id and i.application_batch_id = p_application_batch_id;
  get diagnostics v_updated = row_count;
  if v_updated = 0 then raise exception 'Scheduled application not found.'; end if;
  update public.bank_payment_planner_schedules set updated_by = v_actor, updated_at = now()
    where schedule_date = p_schedule_date;
  return v_updated;
end;
$$;

revoke all on function public.remove_bank_payment_planner_scheduled_vendor(date, text, uuid) from public, anon;
revoke all on function public.set_bank_payment_planner_branch_bank(date, text, uuid, bigint, bigint, text) from public, anon;
grant execute on function public.remove_bank_payment_planner_scheduled_vendor(date, text, uuid) to authenticated;
grant execute on function public.set_bank_payment_planner_branch_bank(date, text, uuid, bigint, bigint, text) to authenticated;

notify pgrst, 'reload schema';
commit;
