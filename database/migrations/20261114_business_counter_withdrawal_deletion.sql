begin;

-- Deleted withdrawals remain as audit records. Reports and lists include
-- active withdrawals only. Existing creation and edit RPCs cannot restore a
-- deleted entry through a stale request or a retried Save.

alter table public.coffee_other_payments
  add column deleted_at timestamptz,
  add column deleted_by uuid references public.users(id);

alter policy coffee_other_payments_read on public.coffee_other_payments
  using (deleted_at is null and (select public.coffee_payments_allowed()));

create function public.coffee_protect_deleted_withdrawal() returns trigger
language plpgsql set search_path = public, pg_temp as $function$
begin
  if tg_op = 'INSERT' then
    if exists (select 1 from public.coffee_other_payments
      where id = new.id and deleted_at is not null) then
      raise exception 'Withdrawal has been deleted' using errcode = '23505';
    end if;
  elsif old.deleted_at is not null then
    raise exception 'Withdrawal has been deleted' using errcode = 'P0002';
  end if;
  return new;
end;
$function$;
revoke all on function public.coffee_protect_deleted_withdrawal() from public, anon, authenticated;

create trigger coffee_protect_deleted_withdrawal
before insert or update on public.coffee_other_payments
for each row execute function public.coffee_protect_deleted_withdrawal();

create function public.delete_coffee_withdrawal(p_id uuid, p_expected_version bigint)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $function$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_entry public.coffee_other_payments%rowtype;
begin
  if auth.uid() is null or not public.coffee_master_admin_allowed() then
    raise exception 'Master admin required' using errcode = '42501';
  end if;
  if p_id is null or p_expected_version is null or p_expected_version < 1 then
    raise exception 'Invalid withdrawal details' using errcode = '22023';
  end if;
  select * into v_entry from public.coffee_other_payments where id = p_id for update;
  -- A repeated Delete succeeds without changing the totals a second time.
  if not found or v_entry.deleted_at is not null then return true; end if;
  if v_entry.version <> p_expected_version then
    raise exception 'Withdrawal changed; refresh before deleting' using errcode = '40001';
  end if;
  update public.coffee_other_payments
    set deleted_at = now(), deleted_by = v_actor,
      version = version + 1, updated_at = now(), updated_by = v_actor
    where id = p_id;
  return true;
end;
$function$;
revoke all on function public.delete_coffee_withdrawal(uuid, bigint) from public, anon;
grant execute on function public.delete_coffee_withdrawal(uuid, bigint) to authenticated;

create or replace function public.coffee_other_payment_total(p_through date) returns numeric
language plpgsql stable security definer set search_path = public, pg_temp as $function$
begin
  if auth.uid() is null or not public.coffee_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  return (select coalesce(sum(amount), 0) from public.coffee_other_payments
    where payment_date <= p_through and deleted_at is null);
end;
$function$;

alter table public.bakery_other_payments
  add column deleted_at timestamptz,
  add column deleted_by uuid references public.users(id);

alter policy bakery_other_payments_read on public.bakery_other_payments
  using (deleted_at is null and (select public.bakery_payments_allowed()));

create function public.bakery_protect_deleted_withdrawal() returns trigger
language plpgsql set search_path = public, pg_temp as $function$
begin
  if tg_op = 'INSERT' then
    if exists (select 1 from public.bakery_other_payments
      where id = new.id and deleted_at is not null) then
      raise exception 'Withdrawal has been deleted' using errcode = '23505';
    end if;
  elsif old.deleted_at is not null then
    raise exception 'Withdrawal has been deleted' using errcode = 'P0002';
  end if;
  return new;
end;
$function$;
revoke all on function public.bakery_protect_deleted_withdrawal() from public, anon, authenticated;

create trigger bakery_protect_deleted_withdrawal
before insert or update on public.bakery_other_payments
for each row execute function public.bakery_protect_deleted_withdrawal();

create function public.delete_bakery_withdrawal(p_id uuid, p_expected_version bigint)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $function$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_entry public.bakery_other_payments%rowtype;
begin
  if auth.uid() is null or not public.bakery_master_admin_allowed() then
    raise exception 'Master admin required' using errcode = '42501';
  end if;
  if p_id is null or p_expected_version is null or p_expected_version < 1 then
    raise exception 'Invalid withdrawal details' using errcode = '22023';
  end if;
  select * into v_entry from public.bakery_other_payments where id = p_id for update;
  -- A repeated Delete succeeds without changing the totals a second time.
  if not found or v_entry.deleted_at is not null then return true; end if;
  if v_entry.version <> p_expected_version then
    raise exception 'Withdrawal changed; refresh before deleting' using errcode = '40001';
  end if;
  update public.bakery_other_payments
    set deleted_at = now(), deleted_by = v_actor,
      version = version + 1, updated_at = now(), updated_by = v_actor
    where id = p_id;
  return true;
end;
$function$;
revoke all on function public.delete_bakery_withdrawal(uuid, bigint) from public, anon;
grant execute on function public.delete_bakery_withdrawal(uuid, bigint) to authenticated;

create or replace function public.bakery_other_payment_total(p_through date) returns numeric
language plpgsql stable security definer set search_path = public, pg_temp as $function$
begin
  if auth.uid() is null or not public.bakery_payments_allowed() then
    raise exception 'Active Aqura user required' using errcode = '42501';
  end if;
  return (select coalesce(sum(amount), 0) from public.bakery_other_payments
    where payment_date <= p_through and deleted_at is null);
end;
$function$;

notify pgrst, 'reload schema';
commit;

