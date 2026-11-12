begin;

create table public.coffee_other_payments (
  id uuid primary key default gen_random_uuid(),
  amount numeric(14,2) not null check (amount > 0 and amount < 'Infinity'::numeric),
  narration text not null check (narration = btrim(narration) and length(narration) between 1 and 2000),
  payment_date date not null default (now() at time zone 'Asia/Riyadh')::date,
  created_by uuid not null default public.aqura_current_user_id() references public.users(id),
  created_at timestamptz not null default now()
);

comment on table public.coffee_other_payments is
  'Counter-level payments to coffee operators outside supplier ledgers; deducted once from combined all-time net payable.';
create index coffee_other_payments_date_idx on public.coffee_other_payments(payment_date, created_at, id);

create function public.coffee_payments_allowed() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from public.users
    where id = public.aqura_current_user_id() and status = 'active');
$$;
revoke all on function public.coffee_payments_allowed() from public, anon;
grant execute on function public.coffee_payments_allowed() to authenticated, service_role;

alter table public.coffee_other_payments enable row level security;
revoke all on public.coffee_other_payments from public, anon, authenticated;
grant select on public.coffee_other_payments to authenticated;
grant all on public.coffee_other_payments to service_role;
create policy coffee_other_payments_read on public.coffee_other_payments
  for select to authenticated using ((select public.coffee_payments_allowed()));

-- The request UUID makes a retried Save idempotent. Amount, narration, date,
-- and creator are immutable through the browser API.
create function public.record_coffee_other_payment(p_id uuid, p_amount numeric, p_narration text)
returns setof public.coffee_other_payments
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_payment public.coffee_other_payments%rowtype;
begin
  if auth.uid() is null or not public.coffee_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  if p_id is null or p_amount is null or p_amount <= 0 or p_amount >= 1000000000000
    or p_amount <> round(p_amount, 2) or p_narration is null
    or length(btrim(p_narration)) not between 1 and 2000 then
    raise exception 'A positive amount with at most two decimals and a narration are required' using errcode = '22023';
  end if;
  insert into public.coffee_other_payments(id, amount, narration, created_by)
  values (p_id, p_amount, btrim(p_narration), v_actor) on conflict (id) do nothing;
  select * into v_payment from public.coffee_other_payments where id = p_id;
  if v_payment.created_by is distinct from v_actor or v_payment.amount is distinct from p_amount
    or v_payment.narration is distinct from btrim(p_narration) then
    raise exception 'Payment request already exists with different details' using errcode = '23505';
  end if;
  return next v_payment;
end;
$$;
revoke all on function public.record_coffee_other_payment(uuid, numeric, text) from public, anon;
grant execute on function public.record_coffee_other_payment(uuid, numeric, text) to authenticated;

create function public.coffee_other_payment_total(p_through date) returns numeric
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.coffee_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  return (select coalesce(sum(amount), 0) from public.coffee_other_payments where payment_date <= p_through);
end;
$$;
revoke all on function public.coffee_other_payment_total(date) from public, anon;
grant execute on function public.coffee_other_payment_total(date) to authenticated;

notify pgrst, 'reload schema';
commit;
