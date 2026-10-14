begin;

alter table public.bank_payment_planner_schedule_items
  add column if not exists paid_from_branch_id bigint references public.branches(id);

create index if not exists idx_bank_payment_planner_items_paid_from_branch
  on public.bank_payment_planner_schedule_items(paid_from_branch_id);

create or replace function public.set_bank_payment_planner_paid_from_branch(
  p_schedule_date date, p_vendor_id text, p_branch_id bigint
) returns integer language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_updated integer;
begin
  if not public.bank_planner_can_access(v_actor) then
    raise exception 'Bank Payment Planner permission required.';
  end if;
  if p_branch_id is not null and not exists (
    select 1 from public.branches b where b.id = p_branch_id and b.is_active = true
  ) then
    raise exception 'Select an active paying branch.';
  end if;
  update public.bank_payment_planner_schedule_items i
  set paid_from_branch_id = p_branch_id
  from public.bank_payment_planner_schedules s
  where i.schedule_id = s.id and s.schedule_date = p_schedule_date and i.vendor_id = p_vendor_id;
  get diagnostics v_updated = row_count;
  if v_updated = 0 then raise exception 'Scheduled vendor not found.'; end if;
  update public.bank_payment_planner_schedules set updated_by = v_actor, updated_at = now()
    where schedule_date = p_schedule_date;
  return v_updated;
end;
$$;

revoke all on function public.set_bank_payment_planner_paid_from_branch(date, text, bigint) from public, anon;
grant execute on function public.set_bank_payment_planner_paid_from_branch(date, text, bigint) to authenticated;

notify pgrst, 'reload schema';
commit;
