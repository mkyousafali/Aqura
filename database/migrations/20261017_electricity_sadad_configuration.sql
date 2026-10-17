begin;

create table if not exists public.electricity_sadad_posting_accounts (
  id uuid primary key default gen_random_uuid(),
  branch_id bigint not null references public.branches(id) on delete restrict,
  ledger_id bigint not null,
  ledger_code text,
  ledger_name text not null,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_by uuid not null references public.users(id),
  updated_at timestamptz not null default now(),
  constraint electricity_sadad_posting_accounts_branch_key unique (branch_id),
  constraint electricity_sadad_posting_accounts_ledger_name_check check (btrim(ledger_name) <> '')
);

create table if not exists public.electricity_sadad_accounts (
  id uuid primary key default gen_random_uuid(),
  electricity_account_number text not null,
  branch_id bigint not null references public.branches(id) on delete restrict,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_by uuid not null references public.users(id),
  updated_at timestamptz not null default now(),
  constraint electricity_sadad_accounts_number_key unique (electricity_account_number),
  constraint electricity_sadad_accounts_number_check check (electricity_account_number ~ '^[0-9]+$')
);

alter table public.electricity_sadad_posting_accounts enable row level security;
alter table public.electricity_sadad_accounts enable row level security;
revoke all on public.electricity_sadad_posting_accounts, public.electricity_sadad_accounts from public, anon, authenticated;
grant all on public.electricity_sadad_posting_accounts, public.electricity_sadad_accounts to service_role;

create or replace function public.get_electricity_sadad_configuration()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  return jsonb_build_object(
    'posting_accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'branch_id', p.branch_id,
        'branch_name', coalesce(b.name_en, b.name_ar, 'Branch ' || p.branch_id),
        'branch_location', coalesce(b.location_en, b.location_ar, ''),
        'ledger_id', p.ledger_id,
        'ledger_code', p.ledger_code,
        'ledger_name', p.ledger_name
      ) order by b.name_en nulls last, b.name_ar nulls last)
      from public.electricity_sadad_posting_accounts p
      join public.branches b on b.id = p.branch_id
    ), '[]'::jsonb),
    'electricity_accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'electricity_account_number', a.electricity_account_number,
        'branch_id', a.branch_id,
        'branch_name', coalesce(b.name_en, b.name_ar, 'Branch ' || a.branch_id),
        'branch_location', coalesce(b.location_en, b.location_ar, '')
      ) order by a.electricity_account_number)
      from public.electricity_sadad_accounts a
      join public.branches b on b.id = a.branch_id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.save_electricity_sadad_posting_account(
  p_branch_id bigint,
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
  if p_ledger_id is null or nullif(btrim(p_ledger_name), '') is null then
    raise exception 'Select an electricity posting ledger.';
  end if;
  insert into public.electricity_sadad_posting_accounts (
    branch_id, ledger_id, ledger_code, ledger_name, created_by, updated_by, updated_at
  ) values (
    p_branch_id, p_ledger_id, nullif(btrim(p_ledger_code), ''), btrim(p_ledger_name), v_actor, v_actor, now()
  ) on conflict (branch_id) do update set
    ledger_id = excluded.ledger_id,
    ledger_code = excluded.ledger_code,
    ledger_name = excluded.ledger_name,
    updated_by = v_actor,
    updated_at = now();
end;
$$;

create or replace function public.save_electricity_sadad_account(
  p_electricity_account_number text,
  p_branch_id bigint
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_number text := regexp_replace(coalesce(p_electricity_account_number, ''), '\D', '', 'g');
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  if not exists (select 1 from public.branches b where b.id = p_branch_id and b.is_active = true) then
    raise exception 'Select an active branch.';
  end if;
  if v_number = '' then
    raise exception 'Enter a valid electricity account number.';
  end if;
  insert into public.electricity_sadad_accounts (
    electricity_account_number, branch_id, created_by, updated_by, updated_at
  ) values (v_number, p_branch_id, v_actor, v_actor, now())
  on conflict (electricity_account_number) do update set
    branch_id = excluded.branch_id,
    updated_by = v_actor,
    updated_at = now();
end;
$$;

revoke all on function public.get_electricity_sadad_configuration(), public.save_electricity_sadad_posting_account(bigint,bigint,text,text), public.save_electricity_sadad_account(text,bigint) from public, anon;
grant execute on function public.get_electricity_sadad_configuration(), public.save_electricity_sadad_posting_account(bigint,bigint,text,text), public.save_electricity_sadad_account(text,bigint) to authenticated;

commit;
