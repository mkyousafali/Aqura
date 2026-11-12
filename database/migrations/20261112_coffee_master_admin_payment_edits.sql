begin;

alter table public.coffee_other_payments
  add column version bigint not null default 1 check (version > 0),
  add column updated_at timestamptz not null default now(),
  add column updated_by uuid references public.users(id);
alter table public.coffee_other_expenses
  add column version bigint not null default 1 check (version > 0),
  add column updated_at timestamptz not null default now(),
  add column updated_by uuid references public.users(id);

create function public.coffee_master_admin_allowed() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.users
    where id = public.aqura_current_user_id() and status = 'active' and is_master_admin = true);
$$;
revoke all on function public.coffee_master_admin_allowed() from public, anon;
grant execute on function public.coffee_master_admin_allowed() to authenticated, service_role;

-- Direct table UPDATE privileges remain revoked. These functions check the
-- server-side master-admin identity and reject stale edits under a row lock.
create function public.edit_coffee_withdrawal(p_id uuid, p_expected_version bigint, p_amount numeric, p_narration text)
returns setof public.coffee_other_payments
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_payment public.coffee_other_payments%rowtype;
begin
  if auth.uid() is null or not public.coffee_master_admin_allowed() then
    raise exception 'Master admin required' using errcode = '42501';
  end if;
  if p_id is null or p_expected_version is null or p_expected_version < 1
    or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000 then
    raise exception 'Invalid withdrawal details' using errcode = '22023';
  end if;
  select * into v_payment from public.coffee_other_payments where id = p_id for update;
  if not found then raise exception 'Withdrawal not found' using errcode = 'P0002'; end if;
  if v_payment.version <> p_expected_version then
    raise exception 'Withdrawal changed; refresh before editing' using errcode = '40001';
  end if;
  update public.coffee_other_payments
  set amount = p_amount, narration = btrim(p_narration),
    version = version + 1, updated_at = now(), updated_by = v_actor
  where id = p_id returning * into v_payment;
  return next v_payment;
end;
$$;
revoke all on function public.edit_coffee_withdrawal(uuid, bigint, numeric, text) from public, anon;
grant execute on function public.edit_coffee_withdrawal(uuid, bigint, numeric, text) to authenticated;

create function public.edit_coffee_other_expense(p_id uuid, p_expected_version bigint, p_amount numeric, p_narration text, p_paid_from text)
returns setof public.coffee_other_expenses
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_expense public.coffee_other_expenses%rowtype;
begin
  if auth.uid() is null or not public.coffee_master_admin_allowed() then
    raise exception 'Master admin required' using errcode = '42501';
  end if;
  if p_id is null or p_expected_version is null or p_expected_version < 1
    or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000
    or p_paid_from is null or p_paid_from not in ('sales', 'operator') then
    raise exception 'Invalid expense details' using errcode = '22023';
  end if;
  select * into v_expense from public.coffee_other_expenses where id = p_id for update;
  if not found then raise exception 'Expense not found' using errcode = 'P0002'; end if;
  if v_expense.version <> p_expected_version then
    raise exception 'Expense changed; refresh before editing' using errcode = '40001';
  end if;
  update public.coffee_other_expenses
  set amount = p_amount, narration = btrim(p_narration), paid_from = p_paid_from,
    version = version + 1, updated_at = now(), updated_by = v_actor
  where id = p_id returning * into v_expense;
  return next v_expense;
end;
$$;
revoke all on function public.edit_coffee_other_expense(uuid, bigint, numeric, text, text) from public, anon;
grant execute on function public.edit_coffee_other_expense(uuid, bigint, numeric, text, text) to authenticated;

notify pgrst, 'reload schema';
commit;
