begin;

alter table public.bank_payment_planner_schedule_items
  add column if not exists source_branch_id bigint references public.branches(id);

update public.bank_payment_planner_schedule_items i
set source_branch_id = case
  when i.source_type = 'Bill' then (
    select v.branch_id from public.vendor_payment_schedule v where v.id::text = i.source_id limit 1
  )
  when i.source_type = 'Expense' then (
    select e.branch_id from public.expense_scheduler e where e.id::text = i.source_id limit 1
  )
end
where i.source_branch_id is null;

create index if not exists idx_bank_payment_planner_items_source_branch
  on public.bank_payment_planner_schedule_items(source_branch_id);

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
       or nullif(v_item->>'source_branch_id', '') is null
       or not exists (select 1 from public.branches b where b.id = (v_item->>'source_branch_id')::bigint)
       or coalesce((v_item->>'amount')::numeric, 0) <= 0 then
      raise exception 'Invalid schedule item.';
    end if;
    insert into public.bank_payment_planner_schedule_items(
      schedule_id, source_type, source_id, source_branch_id, vendor_id, vendor_name,
      branch_location, bill_number, description, bill_date, entered_date, due_date,
      payment_method, approval_status, amount, created_by
    ) values (
      v_schedule_id, v_item->>'source_type', v_item->>'source_id',
      (v_item->>'source_branch_id')::bigint, v_item->>'vendor_id', v_item->>'vendor_name',
      nullif(v_item->>'branch_location', ''), nullif(v_item->>'bill_number', ''),
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

create or replace function public.get_bank_planner_cross_branch_accounts(
  p_paying_branch_id bigint,
  p_other_branch_ids bigint[]
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
begin
  if not public.bank_planner_can_access(v_actor) then
    raise exception 'Bank Payment Planner permission required.';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(d))
    from public.default_accounts_other_branches d
    where (d.source_branch_id = p_paying_branch_id and d.target_branch_id = any(p_other_branch_ids))
       or (d.target_branch_id = p_paying_branch_id and d.source_branch_id = any(p_other_branch_ids))
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_bank_planner_cross_branch_accounts(bigint, bigint[]) from public, anon;
grant execute on function public.get_bank_planner_cross_branch_accounts(bigint, bigint[]) to authenticated;

notify pgrst, 'reload schema';
commit;
