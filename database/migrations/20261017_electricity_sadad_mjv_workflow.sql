begin;

alter table public.statement_mjvs drop constraint if exists statement_mjvs_mjv_type_check;
alter table public.statement_mjvs add constraint statement_mjvs_mjv_type_check
  check (mjv_type in ('pos','iqama-work-permit','electricity'));

create or replace function public.save_statement_mjv(
  p_bank text, p_bank_account_id uuid, p_statement_date date, p_source_file_name text, p_branches jsonb, p_mjv_type text
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id(); v_id uuid; v_branch jsonb; v_debit numeric; v_credit numeric;
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  if p_bank not in ('al-ahli','riyad') or p_mjv_type not in ('pos','iqama-work-permit','electricity') or p_bank_account_id is null or p_statement_date is null or p_branches is null or jsonb_typeof(p_branches)<>'array' or jsonb_array_length(p_branches)=0 then raise exception 'Bank account, MJV type, date, and balanced branch entries are required.'; end if;
  if not exists(select 1 from public.statement_bank_accounts where id=p_bank_account_id and bank=p_bank) then raise exception 'The selected account is not configured for this bank.'; end if;
  if exists(select 1 from public.statement_mjvs where bank=p_bank and bank_account_id=p_bank_account_id and statement_date=p_statement_date and mjv_type=p_mjv_type) then raise exception 'An MJV of this type is already saved for this bank account and statement date.'; end if;
  insert into public.statement_mjvs(bank,bank_account_id,statement_date,source_file_name,created_by,mjv_type) values(p_bank,p_bank_account_id,p_statement_date,nullif(btrim(p_source_file_name),''),v_actor,p_mjv_type) returning id into v_id;
  for v_branch in select value from jsonb_array_elements(p_branches) loop
    v_debit := (v_branch->>'debit')::numeric; v_credit := (v_branch->>'credit')::numeric;
    if (v_branch->>'branch_id') is null or jsonb_typeof(v_branch->'lines')<>'array' or jsonb_array_length(v_branch->'lines')=0 or abs(v_debit-v_credit)>=0.005 then raise exception 'Every branch MJV must contain balanced lines.'; end if;
    insert into public.statement_mjv_branches(statement_mjv_id,branch_id,branch_name,lines,debit_total,credit_total)
    values(v_id,(v_branch->>'branch_id')::bigint,v_branch->>'branch_name',v_branch->'lines',v_debit,v_credit);
  end loop;
  return v_id;
end;
$$;

create or replace function public.get_electricity_statement_tasks()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'statement_mjv_id',m.id,'statement_date',m.statement_date,'bank',m.bank,'statement_status',m.status,
      'bank_account',concat_ws(' - ',a.ledger_name,nullif(a.ledger_code,'')),
      'branch_tasks',coalesce(tasks.items,'[]'::jsonb)
    ) order by m.statement_date desc,m.created_at desc)
    from public.statement_mjvs m
    join public.statement_bank_accounts a on a.id=m.bank_account_id
    left join lateral (
      select jsonb_agg(jsonb_build_object(
        'branch_id',b.branch_id,'branch_name',coalesce(br.name_en,br.name_ar,b.branch_name),
        'branch_location',coalesce(br.location_en,br.location_ar,''),'task_id',b.task_id,
        'task_status',b.task_status,'assigned_user_id',t.assigned_to,
        'assigned_user_name',coalesce(emp.name_en,emp.name_ar,u.username,case when b.task_id is null then 'Not assigned' else 'Unknown user' end),
        'debit_total',b.debit_total,'credit_total',b.credit_total
      ) order by coalesce(br.name_en,br.name_ar,b.branch_name)) items
      from public.statement_mjv_branches b
      left join public.branches br on br.id=b.branch_id
      left join public.assistant_workflow_tasks t on t.id=b.task_id
      left join public.hr_employee_master emp on emp.user_id=t.assigned_to and emp.is_removed=false
      left join public.users u on u.id=t.assigned_to
      where b.statement_mjv_id=m.id
    ) tasks on true
    where m.mjv_type='electricity' and m.status<>'completed'
  ),'[]'::jsonb);
end;
$$;

revoke all on function public.get_electricity_statement_tasks() from public,anon;
grant execute on function public.get_electricity_statement_tasks() to authenticated;
notify pgrst,'reload schema';
commit;
