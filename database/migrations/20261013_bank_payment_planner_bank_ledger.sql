begin;

alter table public.bank_payment_planner_schedule_items
  add column if not exists bank_ledger_id bigint,
  add column if not exists bank_ledger_name text;

create or replace function public.set_bank_payment_planner_branch_bank(
  p_schedule_date date,
  p_vendor_id text,
  p_branch_id bigint,
  p_bank_ledger_id bigint,
  p_bank_ledger_name text
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
  ) then
    raise exception 'Select an active paying branch.';
  end if;
  if p_bank_ledger_id is null or nullif(trim(p_bank_ledger_name), '') is null then
    raise exception 'Select a bank ledger.';
  end if;
  update public.bank_payment_planner_schedule_items i
  set paid_from_branch_id = p_branch_id,
      bank_ledger_id = p_bank_ledger_id,
      bank_ledger_name = trim(p_bank_ledger_name)
  from public.bank_payment_planner_schedules s
  where i.schedule_id = s.id and s.schedule_date = p_schedule_date and i.vendor_id = p_vendor_id;
  get diagnostics v_updated = row_count;
  if v_updated = 0 then raise exception 'Scheduled vendor not found.'; end if;
  update public.bank_payment_planner_schedules set updated_by = v_actor, updated_at = now()
    where schedule_date = p_schedule_date;
  return v_updated;
end;
$$;

revoke all on function public.set_bank_payment_planner_branch_bank(date, text, bigint, bigint, text) from public, anon;
grant execute on function public.set_bank_payment_planner_branch_bank(date, text, bigint, bigint, text) to authenticated;

notify pgrst, 'reload schema';
commit;
