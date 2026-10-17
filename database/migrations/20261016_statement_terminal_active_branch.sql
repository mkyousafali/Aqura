begin;

alter table public.statement_terminal_accounts
  add column if not exists active_branch_id bigint references public.branches(id) on delete restrict;

update public.statement_terminal_accounts
set active_branch_id = branch_id
where active_branch_id is null;

alter table public.statement_terminal_accounts
  alter column active_branch_id set not null;

drop function if exists public.get_statement_terminal_accounts();
drop function if exists public.add_statement_terminal_account(text, bigint, bigint, text, text);

create function public.get_statement_terminal_accounts()
returns table (
  id uuid, terminal_id text, branch_id bigint, branch_name text,
  active_branch_id bigint, active_branch_name text,
  bank_ledger_id bigint, bank_ledger_code text, bank_ledger_name text, created_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  return query
    select a.id, a.terminal_id, a.branch_id,
      coalesce(owner_branch.name_en, owner_branch.name_ar, 'Branch ' || a.branch_id)::text,
      a.active_branch_id,
      coalesce(active_branch.name_en, active_branch.name_ar, 'Branch ' || a.active_branch_id)::text,
      a.bank_ledger_id, a.bank_ledger_code, a.bank_ledger_name, a.created_at
    from public.statement_terminal_accounts a
    join public.branches owner_branch on owner_branch.id = a.branch_id
    join public.branches active_branch on active_branch.id = a.active_branch_id
    order by a.terminal_id;
end;
$$;

create function public.add_statement_terminal_account(
  p_terminal_id text, p_branch_id bigint, p_active_branch_id bigint,
  p_bank_ledger_id bigint, p_bank_ledger_code text, p_bank_ledger_name text
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_id uuid;
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  if nullif(btrim(p_terminal_id), '') is null or p_branch_id is null or p_active_branch_id is null
     or p_bank_ledger_id is null or nullif(btrim(p_bank_ledger_name), '') is null then
    raise exception 'Account branch, active branch, bank account, and terminal ID are required.';
  end if;
  if not exists (select 1 from public.branches b where b.id = p_active_branch_id and b.is_active = true) then
    raise exception 'The Active in branch must be active.';
  end if;
  insert into public.statement_terminal_accounts (
    terminal_id, branch_id, active_branch_id, bank_ledger_id, bank_ledger_code, bank_ledger_name, created_by
  ) values (
    btrim(p_terminal_id), p_branch_id, p_active_branch_id, p_bank_ledger_id,
    nullif(btrim(p_bank_ledger_code), ''), btrim(p_bank_ledger_name), v_actor
  ) returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'This terminal ID is already connected to a bank account.';
end;
$$;

grant execute on function public.get_statement_terminal_accounts() to authenticated;
grant execute on function public.add_statement_terminal_account(text, bigint, bigint, bigint, text, text) to authenticated;

commit;
