begin;

-- Invoker security retains the caller's existing table permissions and RLS.
create or replace function public.bank_planner_split_payment(
  p_type text, p_id text, p_amount numeric, p_date date, p_expected_amount numeric
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_bill public.vendor_payment_schedule%rowtype;
  v_expense public.expense_scheduler%rowtype;
  v_total numeric;
  v_new_id text;
begin
  if not public.bank_planner_can_access(v_actor) then
    raise exception 'Bank Payment Planner permission required.';
  end if;
  if p_amount is null or p_amount::text in ('NaN', 'Infinity', '-Infinity')
     or p_amount <= 0 or p_amount <> round(p_amount, 2) or p_date is null then
    raise exception 'Enter a valid split amount with at most two decimal places and a date.';
  end if;
  if p_type = 'Bill' then
    select * into v_bill from public.vendor_payment_schedule where id = p_id::uuid for update;
    if not found then raise exception 'Bill not found or access denied.'; end if;
    if coalesce(v_bill.is_paid, false) then raise exception 'This bill is already paid.'; end if;
    v_total := coalesce(v_bill.final_bill_amount, v_bill.bill_amount, 0);
  elsif p_type = 'Expense' then
    select * into v_expense from public.expense_scheduler where id = p_id::bigint for update;
    if not found then raise exception 'Expense not found or access denied.'; end if;
    if coalesce(v_expense.is_paid, false) then raise exception 'This expense is already paid.'; end if;
    v_total := v_expense.amount;
  else
    raise exception 'Invalid payment type.';
  end if;
  if p_expected_amount is distinct from v_total then
    raise exception 'The amount has changed. Refresh the table before splitting.';
  end if;
  if p_amount >= v_total then raise exception 'Split amount must be less than the unpaid amount.'; end if;

  if p_type = 'Bill' then
    update public.vendor_payment_schedule set final_bill_amount = v_total - p_amount,
      updated_at = now() where id = v_bill.id;
    if not found then raise exception 'Unable to update the original bill.'; end if;
    v_bill.id := gen_random_uuid();
    v_new_id := v_bill.id::text;
    v_bill.bill_number := 'SPLIT_' || coalesce(v_bill.bill_number, '');
    v_bill.bill_amount := p_amount;
    v_bill.final_bill_amount := p_amount;
    v_bill.original_bill_amount := p_amount;
    v_bill.original_final_amount := p_amount;
    v_bill.discount_amount := 0;
    v_bill.grr_amount := 0;
    v_bill.pri_amount := 0;
    v_bill.discount_notes := null;
    v_bill.grr_reference_number := null;
    v_bill.grr_notes := null;
    v_bill.pri_reference_number := null;
    v_bill.pri_notes := null;
    v_bill.adjustment_history := '[]'::jsonb;
    v_bill.last_adjustment_date := null;
    v_bill.last_adjusted_by := null;
    v_bill.original_due_date := v_bill.due_date;
    v_bill.due_date := p_date;
    v_bill.is_paid := false;
    v_bill.paid_date := null;
    v_bill.payment_reference := null;
    v_bill.transaction_date := null;
    v_bill.created_at := now();
    v_bill.updated_at := now();
    v_bill.scheduled_date := now();
    insert into public.vendor_payment_schedule select v_bill.*;
  else
    update public.expense_scheduler set amount = v_total - p_amount,
      updated_at = now() where id = v_expense.id;
    if not found then raise exception 'Unable to update the original expense.'; end if;
    v_expense.id := nextval(pg_get_serial_sequence('public.expense_scheduler', 'id'));
    v_new_id := v_expense.id::text;
    v_expense.bill_number := case when v_expense.bill_number is null then null else 'SPLIT_' || v_expense.bill_number end;
    v_expense.requisition_number := case when v_expense.requisition_number is null then null else v_expense.requisition_number || '-SPLIT' end;
    v_expense.amount := p_amount;
    v_expense.due_date := p_date;
    v_expense.is_paid := false;
    v_expense.paid_date := null;
    v_expense.payment_reference := null;
    v_expense.created_at := now();
    v_expense.updated_at := now();
    insert into public.expense_scheduler select v_expense.*;
  end if;
  return jsonb_build_object('source_type', p_type, 'source_id', v_new_id, 'amount', p_amount, 'due_date', p_date);
end;
$$;

revoke all on function public.bank_planner_split_payment(text, text, numeric, date, numeric) from public, anon;
grant execute on function public.bank_planner_split_payment(text, text, numeric, date, numeric) to authenticated;

notify pgrst, 'reload schema';

commit;
