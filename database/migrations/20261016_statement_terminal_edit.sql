begin;

create or replace function public.update_statement_terminal_account(
  p_id uuid, p_terminal_id text, p_branch_id bigint, p_active_branch_id bigint,
  p_bank_ledger_id bigint, p_bank_ledger_code text, p_bank_ledger_name text
) returns void language plpgsql security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  if p_id is null or nullif(btrim(p_terminal_id), '') is null or p_branch_id is null
     or p_active_branch_id is null or p_bank_ledger_id is null
     or nullif(btrim(p_bank_ledger_name), '') is null then
    raise exception 'Account branch, active branch, bank account, and terminal ID are required.';
  end if;
  if not exists (select 1 from public.branches b where b.id = p_active_branch_id and b.is_active = true) then
    raise exception 'The Active in branch must be active.';
  end if;
  update public.statement_terminal_accounts set
    terminal_id = btrim(p_terminal_id), branch_id = p_branch_id,
    active_branch_id = p_active_branch_id, bank_ledger_id = p_bank_ledger_id,
    bank_ledger_code = nullif(btrim(p_bank_ledger_code), ''),
    bank_ledger_name = btrim(p_bank_ledger_name)
  where id = p_id;
  if not found then raise exception 'Terminal configuration was not found.'; end if;
exception when unique_violation then
  raise exception 'This terminal ID is already connected to a bank account.';
end;
$$;

grant execute on function public.update_statement_terminal_account(uuid,text,bigint,bigint,bigint,text,text) to authenticated;

commit;
