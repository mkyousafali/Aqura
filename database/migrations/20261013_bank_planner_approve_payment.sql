begin;

create or replace function public.bank_planner_approve_payment(p_type text, p_id text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_permissions public.approval_permissions%rowtype;
  v_bill public.vendor_payment_schedule%rowtype;
  v_expense public.expense_scheduler%rowtype;
  v_req public.expense_requisitions%rowtype;
  v_amount numeric;
begin
  if not exists (select 1 from public.users u where u.id = v_actor and u.status = 'active'
    and (coalesce(u.is_master_admin, false) or exists (select 1 from public.button_permissions bp
      where bp.user_id = u.id and bp.button_code = 'BANK_PAYMENT_PLANNER' and bp.is_enabled))) then
    raise exception 'Bank Payment Planner permission required.';
  end if;
  select * into v_permissions from public.approval_permissions
    where user_id = v_actor and is_active = true for share;
  if not found then raise exception 'Active approval permission required.'; end if;

  if p_type = 'Bill' then
    select * into v_bill from public.vendor_payment_schedule where id = p_id::uuid for update;
    if not found then raise exception 'Bill not found.'; end if;
    if v_bill.is_paid then raise exception 'This bill is already paid.'; end if;
    if v_bill.approval_status not in ('pending', 'sent_for_approval') then
      raise exception 'Only pending bills can be approved.';
    end if;
    if v_bill.assigned_approver_id is not null and v_bill.assigned_approver_id <> v_actor then
      raise exception 'This bill is assigned to another approver.';
    end if;
    v_amount := coalesce(v_bill.final_bill_amount, v_bill.bill_amount, 0);
    if not v_permissions.can_approve_vendor_payments
       or v_permissions.vendor_payment_amount_limit is null
       or (v_permissions.vendor_payment_amount_limit <> 0 and v_amount > v_permissions.vendor_payment_amount_limit) then
      raise exception 'This bill exceeds your approval permission or amount limit.';
    end if;
    update public.vendor_payment_schedule set approval_status = 'approved', approved_by = v_actor,
      approved_at = now(), updated_at = now() where id = v_bill.id;
  elsif p_type = 'Expense' then
    select * into v_expense from public.expense_scheduler where id = p_id::bigint for update;
    if not found then raise exception 'Expense not found.'; end if;
    if v_expense.is_paid then raise exception 'This expense is already paid.'; end if;
    if v_expense.requisition_id is null then raise exception 'This expense schedule has already passed approval.'; end if;
    select * into v_req from public.expense_requisitions where id = v_expense.requisition_id for update;
    if not found then raise exception 'Source requisition not found.'; end if;
    if v_req.status <> 'pending' then raise exception 'Only pending requisitions can be approved.'; end if;
    if v_req.approver_id is distinct from v_actor then raise exception 'This requisition is assigned to another approver.'; end if;
    -- Use the full requisition amount, even if its schedule has been split.
    if not v_permissions.can_approve_requisitions or v_permissions.requisition_amount_limit is null
       or (v_permissions.requisition_amount_limit <> 0 and v_req.amount > v_permissions.requisition_amount_limit) then
      raise exception 'This expense exceeds your requisition approval permission or amount limit.';
    end if;
    update public.expense_requisitions set status = 'approved', updated_at = now() where id = v_req.id;
  else
    raise exception 'Invalid payment type.';
  end if;
end;
$$;

revoke all on function public.bank_planner_approve_payment(text, text) from public, anon;
grant execute on function public.bank_planner_approve_payment(text, text) to authenticated;

notify pgrst, 'reload schema';

commit;
