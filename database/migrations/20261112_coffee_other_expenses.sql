begin;

comment on table public.coffee_other_payments is
  'Coffee operator withdrawals, retained from Other Payments; deducted once from combined all-time net payable.';

create table public.coffee_other_expenses (
  id uuid primary key default gen_random_uuid(),
  amount numeric(14,2) not null check (amount > 0 and amount < 'Infinity'::numeric),
  narration text not null check (narration = btrim(narration) and length(narration) between 1 and 2000),
  paid_from text not null check (paid_from in ('sales', 'operator')),
  expense_date date not null default (now() at time zone 'Asia/Riyadh')::date,
  created_by uuid not null default public.aqura_current_user_id() references public.users(id),
  created_at timestamptz not null default now()
);
comment on table public.coffee_other_expenses is
  'Coffee counter expenses: sales-funded reduces net payable; operator-funded reduces operator profit. No automatic VAT estimate or branch allocation.';
create index coffee_other_expenses_date_idx on public.coffee_other_expenses(expense_date, created_at, id);
alter table public.coffee_other_expenses enable row level security;
revoke all on public.coffee_other_expenses from public, anon, authenticated;
grant select on public.coffee_other_expenses to authenticated;
grant all on public.coffee_other_expenses to service_role;
create policy coffee_other_expenses_read on public.coffee_other_expenses
  for select to authenticated using ((select public.coffee_payments_allowed()));

create function public.record_coffee_other_expense(p_id uuid, p_amount numeric, p_narration text, p_paid_from text)
returns setof public.coffee_other_expenses
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_expense public.coffee_other_expenses%rowtype;
begin
  if auth.uid() is null or not public.coffee_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  if p_id is null or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000
    or p_paid_from is null or p_paid_from not in ('sales', 'operator') then
    raise exception 'A positive amount, narration and payment source are required' using errcode = '22023';
  end if;
  insert into public.coffee_other_expenses(id, amount, narration, paid_from, created_by)
  values (p_id, p_amount, btrim(p_narration), p_paid_from, v_actor) on conflict (id) do nothing;
  select * into v_expense from public.coffee_other_expenses where id = p_id;
  if v_expense.created_by is distinct from v_actor or v_expense.amount is distinct from p_amount
    or v_expense.narration is distinct from btrim(p_narration) or v_expense.paid_from is distinct from p_paid_from then
    raise exception 'Expense request already exists with different details' using errcode = '23505';
  end if;
  return next v_expense;
end;
$$;
revoke all on function public.record_coffee_other_expense(uuid, numeric, text, text) from public, anon;
grant execute on function public.record_coffee_other_expense(uuid, numeric, text, text) to authenticated;

create function public.coffee_other_expense_totals(p_through date) returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.coffee_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  return (select jsonb_build_object(
    'sales', coalesce(sum(amount) filter (where paid_from = 'sales'), 0),
    'operator', coalesce(sum(amount) filter (where paid_from = 'operator'), 0))
    from public.coffee_other_expenses where expense_date <= p_through);
end;
$$;
revoke all on function public.coffee_other_expense_totals(date) from public, anon;
grant execute on function public.coffee_other_expense_totals(date) to authenticated;

notify pgrst, 'reload schema';
commit;
