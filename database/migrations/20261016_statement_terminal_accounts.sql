begin;

create table if not exists public.statement_terminal_accounts (
  id uuid primary key default gen_random_uuid(),
  terminal_id text not null,
  branch_id bigint not null references public.branches(id) on delete restrict,
  bank_ledger_id bigint not null,
  bank_ledger_code text,
  bank_ledger_name text not null,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  constraint statement_terminal_accounts_terminal_id_key unique (terminal_id),
  constraint statement_terminal_accounts_terminal_id_not_blank check (btrim(terminal_id) <> ''),
  constraint statement_terminal_accounts_ledger_name_not_blank check (btrim(bank_ledger_name) <> '')
);

create index if not exists idx_statement_terminal_accounts_branch
  on public.statement_terminal_accounts(branch_id);

alter table public.statement_terminal_accounts enable row level security;
revoke all on public.statement_terminal_accounts from public, anon, authenticated;

create or replace function public.statements_manager_can_access(p_actor uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.users u
    where u.id = p_actor and u.status = 'active'
      and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp
        where bp.user_id = u.id and bp.button_code = 'STATEMENTS_MANAGER' and bp.is_enabled
      ))
  );
$$;

create or replace function public.get_statement_terminal_accounts()
returns table (
  id uuid, terminal_id text, branch_id bigint, branch_name text,
  bank_ledger_id bigint, bank_ledger_code text, bank_ledger_name text, created_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  return query
    select a.id, a.terminal_id, a.branch_id, coalesce(b.name_en, b.name_ar, 'Branch ' || a.branch_id)::text,
      a.bank_ledger_id, a.bank_ledger_code, a.bank_ledger_name, a.created_at
    from public.statement_terminal_accounts a
    join public.branches b on b.id = a.branch_id
    order by a.terminal_id;
end;
$$;

create or replace function public.add_statement_terminal_account(
  p_terminal_id text, p_branch_id bigint, p_bank_ledger_id bigint,
  p_bank_ledger_code text, p_bank_ledger_name text
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_id uuid;
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  if nullif(btrim(p_terminal_id), '') is null or p_branch_id is null or p_bank_ledger_id is null
     or nullif(btrim(p_bank_ledger_name), '') is null then
    raise exception 'Branch, bank account, and terminal ID are required.';
  end if;
  insert into public.statement_terminal_accounts (
    terminal_id, branch_id, bank_ledger_id, bank_ledger_code, bank_ledger_name, created_by
  ) values (
    btrim(p_terminal_id), p_branch_id, p_bank_ledger_id, nullif(btrim(p_bank_ledger_code), ''),
    btrim(p_bank_ledger_name), v_actor
  ) returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'This terminal ID is already connected to a bank account.';
end;
$$;

grant execute on function public.get_statement_terminal_accounts() to authenticated;
grant execute on function public.add_statement_terminal_account(text, bigint, bigint, text, text) to authenticated;

commit;
