begin;

-- Expense equivalent of denomination_split_vendor_payment; preserve the same
-- denomination permissions rather than requiring Bank Payment Planner access.
create or replace function public.denomination_split_expense_payment(
  p_id text, p_amount numeric, p_date date, p_expected_amount numeric
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_user public.users%rowtype;
  v_permission public.denomination_permissions%rowtype;
  v_expense public.expense_scheduler%rowtype;
  v_total numeric;
begin
  select * into v_user from public.users where id = v_actor and status = 'active';
  if not found then raise exception 'Active Aqura user not found.'; end if;

  if not coalesce(v_user.is_master_admin, false) then
    select * into v_permission from public.denomination_permissions where user_id = v_actor;
    if not found or not coalesce(v_permission.can_edit, false) then
      raise exception 'Denomination edit permission required.';
    end if;
  end if;

  if p_amount is null or p_amount::text in ('NaN', 'Infinity', '-Infinity')
     or p_amount <= 0 or p_amount <> round(p_amount, 2) or p_date is null then
    raise exception 'Enter a valid split amount with at most two decimal places and a date.';
  end if;

  select * into v_expense from public.expense_scheduler where id = p_id::bigint for update;
  if not found then raise exception 'Expense not found.'; end if;
  if not coalesce(v_user.is_master_admin, false)
     and not coalesce(v_permission.can_see_all_branches, false)
     and v_expense.branch_id is distinct from v_user.branch_id::bigint then
    raise exception 'You can split expenses only for your assigned branch.';
  end if;
  if coalesce(v_expense.is_paid, false) then raise exception 'This expense is already paid.'; end if;
  if v_expense.requisition_id is not null and not exists (
    select 1 from public.expense_requisitions
    where id = v_expense.requisition_id and status in ('approved', 'completed')
  ) then
    raise exception 'Only approved expenses can be split.';
  end if;
  v_total := v_expense.amount;
  if p_expected_amount is distinct from v_total then
    raise exception 'The amount has changed. Refresh the table before splitting.';
  end if;
  if p_amount >= v_total then raise exception 'Split amount must be less than the unpaid amount.'; end if;

  update public.expense_scheduler
    set amount = v_total - p_amount, updated_at = now(), updated_by = v_actor
    where id = v_expense.id;
  v_expense.id := nextval(pg_get_serial_sequence('public.expense_scheduler', 'id'));
  v_expense.bill_number := case when v_expense.bill_number is null then null else 'SPLIT_' || v_expense.bill_number end;
  v_expense.requisition_number := case when v_expense.requisition_number is null then null else v_expense.requisition_number || '-SPLIT' end;
  v_expense.amount := p_amount;
  v_expense.due_date := p_date;
  v_expense.is_paid := false;
  v_expense.paid_date := null;
  v_expense.payment_reference := null;
  v_expense.created_at := now();
  v_expense.updated_at := now();
  v_expense.updated_by := v_actor;
  insert into public.expense_scheduler select v_expense.*;

  return jsonb_build_object('source_type', 'Expense', 'source_id', v_expense.id::text,
    'amount', p_amount, 'due_date', p_date);
end;
$$;

revoke all on function public.denomination_split_expense_payment(text, numeric, date, numeric) from public, anon;
grant execute on function public.denomination_split_expense_payment(text, numeric, date, numeric) to authenticated;
notify pgrst, 'reload schema';
commit;
