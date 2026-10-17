begin;

create or replace function public.get_statement_task_status(p_statement_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  if p_statement_date is null then
    raise exception 'Statement date is required.';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'bank_account_id', a.id,
      'bank', a.bank,
      'branch_id', a.branch_id,
      'branch_name', concat_ws(' - ', coalesce(br.name_en, br.name_ar, 'Branch ' || br.id), nullif(coalesce(br.location_en, br.location_ar, ''), '')),
      'ledger_id', a.ledger_id,
      'ledger_code', a.ledger_code,
      'ledger_name', a.ledger_name,
      'statement_mjv_id', m.id,
      'statement_status', m.status,
      'source_file_name', m.source_file_name,
      'saved_at', m.created_at,
      'branch_task_count', coalesce(s.branch_task_count, 0),
      'posted_task_count', coalesce(s.posted_task_count, 0),
      'completed_task_count', coalesce(s.completed_task_count, 0),
      'branch_tasks', coalesce(s.branch_tasks, '[]'::jsonb)
    ) order by a.bank, br.name_en, br.location_en, a.ledger_name)
    from public.statement_bank_accounts a
    join public.branches br on br.id = a.branch_id
    left join public.statement_mjvs m
      on m.bank_account_id = a.id and m.bank = a.bank and m.statement_date = p_statement_date
    left join lateral (
      select
        count(*)::int as branch_task_count,
        count(*) filter (where b.task_id is not null)::int as posted_task_count,
        count(*) filter (where b.task_status = 'completed')::int as completed_task_count,
        jsonb_agg(jsonb_build_object(
          'branch_id', b.branch_id,
          'branch_name', b.branch_name,
          'task_id', b.task_id,
          'task_status', b.task_status,
          'debit_total', b.debit_total,
          'credit_total', b.credit_total
        ) order by b.branch_name) as branch_tasks
      from public.statement_mjv_branches b
      where b.statement_mjv_id = m.id
    ) s on true
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.get_statement_task_status(date) from public, anon;
grant execute on function public.get_statement_task_status(date) to authenticated;

notify pgrst, 'reload schema';
commit;
