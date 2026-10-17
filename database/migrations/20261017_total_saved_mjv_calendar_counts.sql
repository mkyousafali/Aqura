begin;

create or replace function public.get_statement_task_month_counts(p_month date)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_month_start date := date_trunc('month',p_month)::date;
  v_configured_count int;
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  if p_month is null then raise exception 'Month is required.'; end if;
  select count(*)::int into v_configured_count from public.statement_bank_accounts;
  return jsonb_build_object(
    'configured_bank_count',v_configured_count,
    'dates',coalesce((
      select jsonb_agg(jsonb_build_object(
        'date',d.day::date,
        'saved_mjv_count',coalesce(m.saved_mjv_count,0),
        'completed_mjv_count',coalesce(m.completed_mjv_count,0)
      ) order by d.day)
      from generate_series(v_month_start,(v_month_start+interval '1 month - 1 day')::date,interval '1 day') d(day)
      left join lateral (
        select count(*)::int saved_mjv_count,
          count(*) filter(where sm.status='completed')::int completed_mjv_count
        from public.statement_mjvs sm where sm.statement_date=d.day::date
      ) m on true
    ),'[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_statement_task_month_counts(date) from public,anon;
grant execute on function public.get_statement_task_month_counts(date) to authenticated;
notify pgrst,'reload schema';
commit;
