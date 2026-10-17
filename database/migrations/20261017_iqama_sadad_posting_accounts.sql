begin;

create table if not exists public.iqama_sadad_posting_accounts (
  id uuid primary key default gen_random_uuid(),
  branch_id bigint not null references public.branches(id) on delete restrict,
  payment_type text not null,
  ledger_id bigint not null,
  ledger_code text,
  ledger_name text not null,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_by uuid not null references public.users(id),
  updated_at timestamptz not null default now(),
  constraint iqama_sadad_posting_accounts_type_check check (payment_type in ('iqama-renewal')),
  constraint iqama_sadad_posting_accounts_branch_type_key unique (branch_id, payment_type),
  constraint iqama_sadad_posting_accounts_ledger_name_check check (btrim(ledger_name) <> '')
);

alter table public.iqama_sadad_posting_accounts enable row level security;
revoke all on public.iqama_sadad_posting_accounts from public, anon, authenticated;
grant all on public.iqama_sadad_posting_accounts to service_role;

create or replace function public.get_iqama_sadad_posting_accounts()
returns table (
  id uuid,
  branch_id bigint,
  branch_name text,
  branch_location text,
  payment_type text,
  ledger_id bigint,
  ledger_code text,
  ledger_name text,
  updated_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  return query
    select a.id, a.branch_id,
      coalesce(b.name_en, b.name_ar, 'Branch ' || a.branch_id)::text,
      coalesce(b.location_en, b.location_ar, '')::text,
      a.payment_type, a.ledger_id, a.ledger_code, a.ledger_name, a.updated_at
    from public.iqama_sadad_posting_accounts a
    join public.branches b on b.id = a.branch_id
    order by b.name_en nulls last, b.name_ar nulls last, a.payment_type;
end;
$$;

create or replace function public.save_iqama_sadad_posting_account(
  p_branch_id bigint,
  p_payment_type text,
  p_ledger_id bigint,
  p_ledger_code text,
  p_ledger_name text
) returns void language plpgsql security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  if not exists (select 1 from public.branches b where b.id = p_branch_id and b.is_active = true) then
    raise exception 'Select an active branch.';
  end if;
  if p_payment_type <> 'iqama-renewal' then
    raise exception 'Iqama Renewal is the only supported SADAD type.';
  end if;
  if p_ledger_id is null or nullif(btrim(p_ledger_name), '') is null then
    raise exception 'Select a posting ledger.';
  end if;
  insert into public.iqama_sadad_posting_accounts (
    branch_id, payment_type, ledger_id, ledger_code, ledger_name,
    created_by, updated_by, updated_at
  ) values (
    p_branch_id, p_payment_type, p_ledger_id, nullif(btrim(p_ledger_code), ''), btrim(p_ledger_name),
    v_actor, v_actor, now()
  ) on conflict (branch_id, payment_type) do update set
    ledger_id = excluded.ledger_id,
    ledger_code = excluded.ledger_code,
    ledger_name = excluded.ledger_name,
    updated_by = v_actor,
    updated_at = now();
end;
$$;

revoke all on function public.get_iqama_sadad_posting_accounts(), public.save_iqama_sadad_posting_account(bigint,text,bigint,text,text) from public, anon;
grant execute on function public.get_iqama_sadad_posting_accounts(), public.save_iqama_sadad_posting_account(bigint,text,bigint,text,text) to authenticated;

commit;
