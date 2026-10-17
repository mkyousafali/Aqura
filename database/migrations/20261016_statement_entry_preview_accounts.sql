begin;

create or replace function public.get_statement_entry_preview_accounts()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  return jsonb_build_object(
    'pos_accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'branch_id', l.branch_id, 'pos_number', l.pos_number,
        'ledger_id', l.erp_ledger_id, 'ledger_code', l.ledger_code, 'ledger_name', l.ledger_name
      ) order by l.branch_id, l.pos_number nulls first)
      from public.erp_posting_ledger_links l where l.account_key = 'pos_bank'
    ), '[]'::jsonb),
    'cross_branch_accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'source_branch_id', d.source_branch_id, 'target_branch_id', d.target_branch_id,
        'ledger_id', d.target_ledger_id, 'ledger_name', d.target_ledger_name
      ) order by d.source_branch_id, d.target_branch_id)
      from public.default_accounts_other_branches d
    ), '[]'::jsonb)
  );
end;
$$;

grant execute on function public.get_statement_entry_preview_accounts() to authenticated;

commit;
