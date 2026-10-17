begin;

create table if not exists public.statement_posting_accounts (
  branch_id bigint primary key references public.branches(id) on delete restrict,
  input_vat_ledger_id bigint not null,
  input_vat_ledger_code text,
  input_vat_ledger_name text not null,
  riyad_fee_ledger_id bigint not null,
  riyad_fee_ledger_code text,
  riyad_fee_ledger_name text not null,
  ahli_fee_ledger_id bigint not null,
  ahli_fee_ledger_code text,
  ahli_fee_ledger_name text not null,
  updated_by uuid not null references public.users(id),
  updated_at timestamptz not null default now()
);

alter table public.statement_posting_accounts enable row level security;
revoke all on public.statement_posting_accounts from public, anon, authenticated;

create or replace function public.get_statement_posting_accounts()
returns table (
  branch_id bigint, branch_name text,
  input_vat_ledger_id bigint, input_vat_ledger_code text, input_vat_ledger_name text,
  riyad_fee_ledger_id bigint, riyad_fee_ledger_code text, riyad_fee_ledger_name text,
  ahli_fee_ledger_id bigint, ahli_fee_ledger_code text, ahli_fee_ledger_name text,
  updated_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  return query
    select p.branch_id, coalesce(b.name_en, b.name_ar, 'Branch ' || p.branch_id)::text,
      p.input_vat_ledger_id, p.input_vat_ledger_code, p.input_vat_ledger_name,
      p.riyad_fee_ledger_id, p.riyad_fee_ledger_code, p.riyad_fee_ledger_name,
      p.ahli_fee_ledger_id, p.ahli_fee_ledger_code, p.ahli_fee_ledger_name, p.updated_at
    from public.statement_posting_accounts p
    join public.branches b on b.id = p.branch_id
    order by b.name_en nulls last, b.name_ar nulls last;
end;
$$;

create or replace function public.save_statement_posting_accounts(
  p_branch_id bigint,
  p_input_vat_ledger_id bigint, p_input_vat_ledger_code text, p_input_vat_ledger_name text,
  p_riyad_fee_ledger_id bigint, p_riyad_fee_ledger_code text, p_riyad_fee_ledger_name text,
  p_ahli_fee_ledger_id bigint, p_ahli_fee_ledger_code text, p_ahli_fee_ledger_name text
) returns void language plpgsql security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  if not exists (select 1 from public.branches b where b.id = p_branch_id and b.is_active = true) then
    raise exception 'Select an active branch.';
  end if;
  if p_input_vat_ledger_id is null or nullif(btrim(p_input_vat_ledger_name), '') is null
    or p_riyad_fee_ledger_id is null or nullif(btrim(p_riyad_fee_ledger_name), '') is null
    or p_ahli_fee_ledger_id is null or nullif(btrim(p_ahli_fee_ledger_name), '') is null then
    raise exception 'Input VAT, Riyad fee, and Al Ahli fee accounts are required.';
  end if;
  insert into public.statement_posting_accounts (
    branch_id, input_vat_ledger_id, input_vat_ledger_code, input_vat_ledger_name,
    riyad_fee_ledger_id, riyad_fee_ledger_code, riyad_fee_ledger_name,
    ahli_fee_ledger_id, ahli_fee_ledger_code, ahli_fee_ledger_name, updated_by, updated_at
  ) values (
    p_branch_id, p_input_vat_ledger_id, nullif(btrim(p_input_vat_ledger_code), ''), btrim(p_input_vat_ledger_name),
    p_riyad_fee_ledger_id, nullif(btrim(p_riyad_fee_ledger_code), ''), btrim(p_riyad_fee_ledger_name),
    p_ahli_fee_ledger_id, nullif(btrim(p_ahli_fee_ledger_code), ''), btrim(p_ahli_fee_ledger_name), v_actor, now()
  ) on conflict (branch_id) do update set
    input_vat_ledger_id = excluded.input_vat_ledger_id, input_vat_ledger_code = excluded.input_vat_ledger_code,
    input_vat_ledger_name = excluded.input_vat_ledger_name, riyad_fee_ledger_id = excluded.riyad_fee_ledger_id,
    riyad_fee_ledger_code = excluded.riyad_fee_ledger_code, riyad_fee_ledger_name = excluded.riyad_fee_ledger_name,
    ahli_fee_ledger_id = excluded.ahli_fee_ledger_id, ahli_fee_ledger_code = excluded.ahli_fee_ledger_code,
    ahli_fee_ledger_name = excluded.ahli_fee_ledger_name, updated_by = v_actor, updated_at = now();
end;
$$;

grant execute on function public.get_statement_posting_accounts() to authenticated;
grant execute on function public.save_statement_posting_accounts(bigint,bigint,text,text,bigint,text,text,bigint,text,text) to authenticated;

commit;
