begin;

create table public.bakery_other_payments (
  id uuid primary key default gen_random_uuid(),
  amount numeric(14,2) not null check (amount > 0 and amount < 'Infinity'::numeric),
  narration text not null check (narration = btrim(narration) and length(narration) between 1 and 2000),
  payment_date date not null default (now() at time zone 'Asia/Riyadh')::date check (payment_date >= date '2026-11-12'),
  created_by uuid not null default public.aqura_current_user_id() references public.users(id),
  created_at timestamptz not null default now()
);

comment on table public.bakery_other_payments is
  'Counter-level payments to bakery operators outside supplier ledgers; deducted once from combined monthly net payable.';
create index bakery_other_payments_date_idx on public.bakery_other_payments(payment_date, created_at, id);

create function public.bakery_payments_allowed() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.users
    where id = public.aqura_current_user_id() and status = 'active');
$$;
revoke all on function public.bakery_payments_allowed() from public, anon;
grant execute on function public.bakery_payments_allowed() to authenticated, service_role;

alter table public.bakery_other_payments enable row level security;
revoke all on public.bakery_other_payments from public, anon, authenticated;
grant select on public.bakery_other_payments to authenticated;
grant all on public.bakery_other_payments to service_role;
create policy bakery_other_payments_read on public.bakery_other_payments
  for select to authenticated using ((select public.bakery_payments_allowed()));

-- The request UUID makes a retried Save idempotent. Amount, narration, date,
-- and creator are immutable through the browser API.
create function public.record_bakery_other_payment(p_id uuid, p_amount numeric, p_narration text)
returns setof public.bakery_other_payments
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_payment public.bakery_other_payments%rowtype;
begin
  if auth.uid() is null or not public.bakery_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  if p_id is null or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000 then
    raise exception 'A positive amount with at most two decimals and a narration are required' using errcode = '22023';
  end if;
  insert into public.bakery_other_payments(id, amount, narration, created_by)
  values (p_id, p_amount, btrim(p_narration), v_actor) on conflict (id) do nothing;
  select * into v_payment from public.bakery_other_payments where id = p_id;
  if v_payment.created_by is distinct from v_actor or v_payment.amount is distinct from p_amount
    or v_payment.narration is distinct from btrim(p_narration) then
    raise exception 'Payment request already exists with different details' using errcode = '23505';
  end if;
  return next v_payment;
end;
$$;
revoke all on function public.record_bakery_other_payment(uuid, numeric, text) from public, anon;
grant execute on function public.record_bakery_other_payment(uuid, numeric, text) to authenticated;

create function public.bakery_other_payment_total(p_through date) returns numeric
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.bakery_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  return (select coalesce(sum(amount), 0) from public.bakery_other_payments where payment_date <= p_through);
end;
$$;
revoke all on function public.bakery_other_payment_total(date) from public, anon;
grant execute on function public.bakery_other_payment_total(date) to authenticated;

comment on table public.bakery_other_payments is
  'Bakery operator withdrawals, retained from Other Payments; deducted once from combined monthly net payable.';

create table public.bakery_other_expenses (
  id uuid primary key default gen_random_uuid(),
  amount numeric(14,2) not null check (amount > 0 and amount < 'Infinity'::numeric),
  narration text not null check (narration = btrim(narration) and length(narration) between 1 and 2000),
  paid_from text not null check (paid_from in ('sales', 'operator')),
  expense_date date not null default (now() at time zone 'Asia/Riyadh')::date check (expense_date >= date '2026-11-12'),
  created_by uuid not null default public.aqura_current_user_id() references public.users(id),
  created_at timestamptz not null default now()
);
comment on table public.bakery_other_expenses is
  'Bakery counter expenses: sales-funded reduces net payable; operator-funded reduces operator profit. No automatic VAT estimate or branch allocation.';
create index bakery_other_expenses_date_idx on public.bakery_other_expenses(expense_date, created_at, id);
alter table public.bakery_other_expenses enable row level security;
revoke all on public.bakery_other_expenses from public, anon, authenticated;
grant select on public.bakery_other_expenses to authenticated;
grant all on public.bakery_other_expenses to service_role;
create policy bakery_other_expenses_read on public.bakery_other_expenses
  for select to authenticated using ((select public.bakery_payments_allowed()));

create function public.record_bakery_other_expense(p_id uuid, p_amount numeric, p_narration text, p_paid_from text)
returns setof public.bakery_other_expenses
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_expense public.bakery_other_expenses%rowtype;
begin
  if auth.uid() is null or not public.bakery_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  if p_id is null or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000
    or p_paid_from is null or p_paid_from not in ('sales', 'operator') then
    raise exception 'A positive amount, narration and payment source are required' using errcode = '22023';
  end if;
  insert into public.bakery_other_expenses(id, amount, narration, paid_from, created_by)
  values (p_id, p_amount, btrim(p_narration), p_paid_from, v_actor) on conflict (id) do nothing;
  select * into v_expense from public.bakery_other_expenses where id = p_id;
  if v_expense.created_by is distinct from v_actor or v_expense.amount is distinct from p_amount
    or v_expense.narration is distinct from btrim(p_narration) or v_expense.paid_from is distinct from p_paid_from then
    raise exception 'Expense request already exists with different details' using errcode = '23505';
  end if;
  return next v_expense;
end;
$$;
revoke all on function public.record_bakery_other_expense(uuid, numeric, text, text) from public, anon;
grant execute on function public.record_bakery_other_expense(uuid, numeric, text, text) to authenticated;

create function public.bakery_other_expense_totals(p_through date) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.bakery_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  return (select jsonb_build_object(
    'sales', coalesce(sum(amount) filter (where paid_from = 'sales'), 0),
    'operator', coalesce(sum(amount) filter (where paid_from = 'operator'), 0))
    from public.bakery_other_expenses where expense_date <= p_through);
end;
$$;
revoke all on function public.bakery_other_expense_totals(date) from public, anon;
grant execute on function public.bakery_other_expense_totals(date) to authenticated;

alter table public.bakery_other_payments
  add column version bigint not null default 1 check (version > 0),
  add column updated_at timestamptz not null default now(),
  add column updated_by uuid references public.users(id);
alter table public.bakery_other_expenses
  add column version bigint not null default 1 check (version > 0),
  add column updated_at timestamptz not null default now(),
  add column updated_by uuid references public.users(id);

create function public.bakery_master_admin_allowed() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.users
    where id = public.aqura_current_user_id() and status = 'active' and is_master_admin = true);
$$;
revoke all on function public.bakery_master_admin_allowed() from public, anon;
grant execute on function public.bakery_master_admin_allowed() to authenticated, service_role;

-- Direct table UPDATE privileges remain revoked. These functions check the
-- server-side master-admin identity and reject stale edits under a row lock.
create function public.edit_bakery_withdrawal(p_id uuid, p_expected_version bigint, p_amount numeric, p_narration text)
returns setof public.bakery_other_payments
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_payment public.bakery_other_payments%rowtype;
begin
  if auth.uid() is null or not public.bakery_master_admin_allowed() then
    raise exception 'Master admin required' using errcode = '42501';
  end if;
  if p_id is null or p_expected_version is null or p_expected_version < 1
    or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000 then
    raise exception 'Invalid withdrawal details' using errcode = '22023';
  end if;
  select * into v_payment from public.bakery_other_payments where id = p_id for update;
  if not found then raise exception 'Withdrawal not found' using errcode = 'P0002'; end if;
  if v_payment.version <> p_expected_version then
    raise exception 'Withdrawal changed; refresh before editing' using errcode = '40001';
  end if;
  update public.bakery_other_payments
  set amount = p_amount, narration = btrim(p_narration),
    version = version + 1, updated_at = now(), updated_by = v_actor
  where id = p_id returning * into v_payment;
  return next v_payment;
end;
$$;
revoke all on function public.edit_bakery_withdrawal(uuid, bigint, numeric, text) from public, anon;
grant execute on function public.edit_bakery_withdrawal(uuid, bigint, numeric, text) to authenticated;

create function public.edit_bakery_other_expense(p_id uuid, p_expected_version bigint, p_amount numeric, p_narration text, p_paid_from text)
returns setof public.bakery_other_expenses
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_expense public.bakery_other_expenses%rowtype;
begin
  if auth.uid() is null or not public.bakery_master_admin_allowed() then
    raise exception 'Master admin required' using errcode = '42501';
  end if;
  if p_id is null or p_expected_version is null or p_expected_version < 1
    or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000
    or p_paid_from is null or p_paid_from not in ('sales', 'operator') then
    raise exception 'Invalid expense details' using errcode = '22023';
  end if;
  select * into v_expense from public.bakery_other_expenses where id = p_id for update;
  if not found then raise exception 'Expense not found' using errcode = 'P0002'; end if;
  if v_expense.version <> p_expected_version then
    raise exception 'Expense changed; refresh before editing' using errcode = '40001';
  end if;
  update public.bakery_other_expenses
  set amount = p_amount, narration = btrim(p_narration), paid_from = p_paid_from,
    version = version + 1, updated_at = now(), updated_by = v_actor
  where id = p_id returning * into v_expense;
  return next v_expense;
end;
$$;
revoke all on function public.edit_bakery_other_expense(uuid, bigint, numeric, text, text) from public, anon;
grant execute on function public.edit_bakery_other_expense(uuid, bigint, numeric, text, text) to authenticated;

notify pgrst, 'reload schema';
commit;
