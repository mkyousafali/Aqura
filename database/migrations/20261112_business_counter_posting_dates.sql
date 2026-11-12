begin;

-- Dated overloads preserve existing clients. Dates are posting dates, while
-- created_at remains the original audit timestamp. Existing edit functions
-- retain master-admin checks, row locking, version checks and audit updates.

create or replace function public.record_coffee_other_payment(
  p_id uuid, p_amount numeric, p_narration text, p_posting_date date
) returns setof public.coffee_other_payments
language plpgsql security definer set search_path = public, pg_temp as $function$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_entry public.coffee_other_payments%rowtype;
begin
  if auth.uid() is null or not public.coffee_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  if p_id is null or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000
    or p_posting_date is null or p_posting_date < date '1753-01-01'
    or p_posting_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'Invalid entry details or posting date' using errcode = '22023';
  end if;
  insert into public.coffee_other_payments(id, amount, narration, payment_date, created_by)
  values (p_id, p_amount, btrim(p_narration), p_posting_date, v_actor)
  on conflict (id) do nothing;
  select * into v_entry from public.coffee_other_payments where id = p_id;
  if v_entry.created_by is distinct from v_actor or v_entry.amount is distinct from p_amount
    or v_entry.narration is distinct from btrim(p_narration)
    or v_entry.payment_date is distinct from p_posting_date then
    raise exception 'Request already exists with different details' using errcode = '23505';
  end if;
  return next v_entry;
end;
$function$;
revoke all on function public.record_coffee_other_payment(uuid, numeric, text, date) from public, anon;
grant execute on function public.record_coffee_other_payment(uuid, numeric, text, date) to authenticated;

create or replace function public.edit_coffee_withdrawal(
  p_id uuid, p_expected_version bigint, p_amount numeric, p_narration text, p_posting_date date
) returns setof public.coffee_other_payments
language plpgsql security definer set search_path = public, pg_temp as $function$
begin
  if p_posting_date is null or p_posting_date < date '1753-01-01'
    or p_posting_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'Invalid posting date' using errcode = '22023';
  end if;
  -- The original overload enforces master-admin authorization and obtains
  -- the row lock, then increments the version and updates the audit fields.
  perform 1 from public.edit_coffee_withdrawal(p_id, p_expected_version, p_amount, p_narration);
  return query update public.coffee_other_payments
    set payment_date = p_posting_date where id = p_id returning *;
end;
$function$;
revoke all on function public.edit_coffee_withdrawal(uuid, bigint, numeric, text, date) from public, anon;
grant execute on function public.edit_coffee_withdrawal(uuid, bigint, numeric, text, date) to authenticated;

create or replace function public.record_coffee_other_expense(
  p_id uuid, p_amount numeric, p_narration text, p_paid_from text, p_posting_date date
) returns setof public.coffee_other_expenses
language plpgsql security definer set search_path = public, pg_temp as $function$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_entry public.coffee_other_expenses%rowtype;
begin
  if auth.uid() is null or not public.coffee_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  if p_id is null or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000
    or p_paid_from is null or p_paid_from not in ('sales', 'operator')
    or p_posting_date is null or p_posting_date < date '1753-01-01'
    or p_posting_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'Invalid entry details or posting date' using errcode = '22023';
  end if;
  insert into public.coffee_other_expenses(id, amount, narration, paid_from, expense_date, created_by)
  values (p_id, p_amount, btrim(p_narration), p_paid_from, p_posting_date, v_actor)
  on conflict (id) do nothing;
  select * into v_entry from public.coffee_other_expenses where id = p_id;
  if v_entry.created_by is distinct from v_actor or v_entry.amount is distinct from p_amount
    or v_entry.narration is distinct from btrim(p_narration)
    or v_entry.paid_from is distinct from p_paid_from
    or v_entry.expense_date is distinct from p_posting_date then
    raise exception 'Request already exists with different details' using errcode = '23505';
  end if;
  return next v_entry;
end;
$function$;
revoke all on function public.record_coffee_other_expense(uuid, numeric, text, text, date) from public, anon;
grant execute on function public.record_coffee_other_expense(uuid, numeric, text, text, date) to authenticated;

create or replace function public.edit_coffee_other_expense(
  p_id uuid, p_expected_version bigint, p_amount numeric, p_narration text, p_paid_from text, p_posting_date date
) returns setof public.coffee_other_expenses
language plpgsql security definer set search_path = public, pg_temp as $function$
begin
  if p_posting_date is null or p_posting_date < date '1753-01-01'
    or p_posting_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'Invalid posting date' using errcode = '22023';
  end if;
  -- The original overload enforces master-admin authorization and obtains
  -- the row lock, then increments the version and updates the audit fields.
  perform 1 from public.edit_coffee_other_expense(p_id, p_expected_version, p_amount, p_narration, p_paid_from);
  return query update public.coffee_other_expenses
    set expense_date = p_posting_date where id = p_id returning *;
end;
$function$;
revoke all on function public.edit_coffee_other_expense(uuid, bigint, numeric, text, text, date) from public, anon;
grant execute on function public.edit_coffee_other_expense(uuid, bigint, numeric, text, text, date) to authenticated;

create or replace function public.record_bakery_other_payment(
  p_id uuid, p_amount numeric, p_narration text, p_posting_date date
) returns setof public.bakery_other_payments
language plpgsql security definer set search_path = public, pg_temp as $function$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_entry public.bakery_other_payments%rowtype;
begin
  if auth.uid() is null or not public.bakery_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  if p_id is null or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000
    or p_posting_date is null or p_posting_date < date '2026-11-12'
    or p_posting_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'Invalid entry details or posting date' using errcode = '22023';
  end if;
  insert into public.bakery_other_payments(id, amount, narration, payment_date, created_by)
  values (p_id, p_amount, btrim(p_narration), p_posting_date, v_actor)
  on conflict (id) do nothing;
  select * into v_entry from public.bakery_other_payments where id = p_id;
  if v_entry.created_by is distinct from v_actor or v_entry.amount is distinct from p_amount
    or v_entry.narration is distinct from btrim(p_narration)
    or v_entry.payment_date is distinct from p_posting_date then
    raise exception 'Request already exists with different details' using errcode = '23505';
  end if;
  return next v_entry;
end;
$function$;
revoke all on function public.record_bakery_other_payment(uuid, numeric, text, date) from public, anon;
grant execute on function public.record_bakery_other_payment(uuid, numeric, text, date) to authenticated;

create or replace function public.edit_bakery_withdrawal(
  p_id uuid, p_expected_version bigint, p_amount numeric, p_narration text, p_posting_date date
) returns setof public.bakery_other_payments
language plpgsql security definer set search_path = public, pg_temp as $function$
begin
  if p_posting_date is null or p_posting_date < date '2026-11-12'
    or p_posting_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'Invalid posting date' using errcode = '22023';
  end if;
  -- The original overload enforces master-admin authorization and obtains
  -- the row lock, then increments the version and updates the audit fields.
  perform 1 from public.edit_bakery_withdrawal(p_id, p_expected_version, p_amount, p_narration);
  return query update public.bakery_other_payments
    set payment_date = p_posting_date where id = p_id returning *;
end;
$function$;
revoke all on function public.edit_bakery_withdrawal(uuid, bigint, numeric, text, date) from public, anon;
grant execute on function public.edit_bakery_withdrawal(uuid, bigint, numeric, text, date) to authenticated;

create or replace function public.record_bakery_other_expense(
  p_id uuid, p_amount numeric, p_narration text, p_paid_from text, p_posting_date date
) returns setof public.bakery_other_expenses
language plpgsql security definer set search_path = public, pg_temp as $function$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_entry public.bakery_other_expenses%rowtype;
begin
  if auth.uid() is null or not public.bakery_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  if p_id is null or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000
    or p_paid_from is null or p_paid_from not in ('sales', 'operator')
    or p_posting_date is null or p_posting_date < date '2026-11-12'
    or p_posting_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'Invalid entry details or posting date' using errcode = '22023';
  end if;
  insert into public.bakery_other_expenses(id, amount, narration, paid_from, expense_date, created_by)
  values (p_id, p_amount, btrim(p_narration), p_paid_from, p_posting_date, v_actor)
  on conflict (id) do nothing;
  select * into v_entry from public.bakery_other_expenses where id = p_id;
  if v_entry.created_by is distinct from v_actor or v_entry.amount is distinct from p_amount
    or v_entry.narration is distinct from btrim(p_narration)
    or v_entry.paid_from is distinct from p_paid_from
    or v_entry.expense_date is distinct from p_posting_date then
    raise exception 'Request already exists with different details' using errcode = '23505';
  end if;
  return next v_entry;
end;
$function$;
revoke all on function public.record_bakery_other_expense(uuid, numeric, text, text, date) from public, anon;
grant execute on function public.record_bakery_other_expense(uuid, numeric, text, text, date) to authenticated;

create or replace function public.edit_bakery_other_expense(
  p_id uuid, p_expected_version bigint, p_amount numeric, p_narration text, p_paid_from text, p_posting_date date
) returns setof public.bakery_other_expenses
language plpgsql security definer set search_path = public, pg_temp as $function$
begin
  if p_posting_date is null or p_posting_date < date '2026-11-12'
    or p_posting_date > (now() at time zone 'Asia/Riyadh')::date then
    raise exception 'Invalid posting date' using errcode = '22023';
  end if;
  -- The original overload enforces master-admin authorization and obtains
  -- the row lock, then increments the version and updates the audit fields.
  perform 1 from public.edit_bakery_other_expense(p_id, p_expected_version, p_amount, p_narration, p_paid_from);
  return query update public.bakery_other_expenses
    set expense_date = p_posting_date where id = p_id returning *;
end;
$function$;
revoke all on function public.edit_bakery_other_expense(uuid, bigint, numeric, text, text, date) from public, anon;
grant execute on function public.edit_bakery_other_expense(uuid, bigint, numeric, text, text, date) to authenticated;

notify pgrst, 'reload schema';
commit;

