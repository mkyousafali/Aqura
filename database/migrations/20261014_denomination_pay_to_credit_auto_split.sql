begin;

create or replace function public.denomination_split_vendor_payment(
  p_id text,
  p_amount numeric,
  p_date date,
  p_expected_amount numeric
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_user public.users%rowtype;
  v_permission public.denomination_permissions%rowtype;
  v_bill public.vendor_payment_schedule%rowtype;
  v_total numeric;
  v_new_id uuid;
begin
  select * into v_user
  from public.users
  where id = v_actor and status = 'active';

  if not found then
    raise exception 'Active Aqura user not found.';
  end if;

  if not coalesce(v_user.is_master_admin, false) then
    select * into v_permission
    from public.denomination_permissions
    where user_id = v_actor;

    if not found or not coalesce(v_permission.can_edit, false) then
      raise exception 'Denomination edit permission required.';
    end if;
  end if;

  if p_amount is null or p_amount::text in ('NaN', 'Infinity', '-Infinity')
     or p_amount <= 0 or p_amount <> round(p_amount, 2) or p_date is null then
    raise exception 'Enter a valid split amount with at most two decimal places and a date.';
  end if;

  select * into v_bill
  from public.vendor_payment_schedule
  where id = p_id::uuid
  for update;

  if not found then
    raise exception 'Bill not found.';
  end if;

  if not coalesce(v_user.is_master_admin, false)
     and not coalesce(v_permission.can_see_all_branches, false)
     and v_bill.branch_id is distinct from v_user.branch_id::integer then
    raise exception 'You can split bills only for your assigned branch.';
  end if;

  if coalesce(v_bill.is_paid, false) then
    raise exception 'This bill is already paid.';
  end if;

  if v_bill.approval_status is distinct from 'approved' then
    raise exception 'Only approved bills can be split.';
  end if;

  v_total := coalesce(v_bill.final_bill_amount, v_bill.bill_amount, 0);
  if p_expected_amount is distinct from v_total then
    raise exception 'The amount has changed. Refresh the table before splitting.';
  end if;
  if p_amount >= v_total then
    raise exception 'Split amount must be less than the unpaid amount.';
  end if;

  update public.vendor_payment_schedule
  set final_bill_amount = v_total - p_amount,
      updated_at = now()
  where id = v_bill.id;

  v_new_id := gen_random_uuid();
  v_bill.id := v_new_id;
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

  return jsonb_build_object(
    'source_type', 'Bill',
    'source_id', v_new_id::text,
    'amount', p_amount,
    'due_date', p_date
  );
end;
$$;

revoke all on function public.denomination_split_vendor_payment(text, numeric, date, numeric)
  from public, anon;
grant execute on function public.denomination_split_vendor_payment(text, numeric, date, numeric)
  to authenticated;

notify pgrst, 'reload schema';

commit;
