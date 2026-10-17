begin;

alter table public.statement_mjvs add column if not exists mjv_type text not null default 'pos';
alter table public.statement_mjvs drop constraint if exists statement_mjvs_mjv_type_check;
alter table public.statement_mjvs add constraint statement_mjvs_mjv_type_check check (mjv_type in ('pos','iqama-work-permit'));
drop index if exists public.statement_mjvs_bank_account_date_unique;
create unique index if not exists statement_mjvs_bank_account_date_type_unique
  on public.statement_mjvs(bank,bank_account_id,statement_date,mjv_type);

alter table public.iqama_sadad_documents add column if not exists statement_mjv_id uuid references public.statement_mjvs(id) on delete set null;
create index if not exists iqama_sadad_documents_mjv_idx on public.iqama_sadad_documents(statement_mjv_id);

create or replace function public.save_statement_mjv(
  p_bank text, p_bank_account_id uuid, p_statement_date date, p_source_file_name text, p_branches jsonb, p_mjv_type text
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id(); v_id uuid; v_branch jsonb; v_debit numeric; v_credit numeric;
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  if p_bank not in ('al-ahli','riyad') or p_mjv_type not in ('pos','iqama-work-permit') or p_bank_account_id is null or p_statement_date is null or p_branches is null or jsonb_typeof(p_branches)<>'array' or jsonb_array_length(p_branches)=0 then raise exception 'Bank account, MJV type, date, and balanced branch entries are required.'; end if;
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

create or replace function public.get_statement_mjv(p_bank text,p_bank_account_id uuid,p_statement_date date,p_mjv_type text)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  return (select to_jsonb(m)||jsonb_build_object('branches',coalesce((select jsonb_agg(to_jsonb(b) order by b.branch_name) from public.statement_mjv_branches b where b.statement_mjv_id=m.id),'[]'::jsonb))
    from public.statement_mjvs m where m.bank=p_bank and m.bank_account_id=p_bank_account_id and m.statement_date=p_statement_date and m.mjv_type=p_mjv_type);
end;
$$;

create or replace function public.link_iqama_sadad_documents_to_mjv(p_statement_mjv_id uuid,p_document_ids uuid[])
returns void language plpgsql security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  if not exists(select 1 from public.statement_mjvs where id=p_statement_mjv_id and mjv_type='iqama-work-permit') then raise exception 'Iqama and work-permit MJV was not found.'; end if;
  update public.iqama_sadad_documents set statement_mjv_id=p_statement_mjv_id,updated_by=v_actor,updated_at=now() where id=any(p_document_ids);
end;
$$;

drop function if exists public.get_iqama_sadad_documents();
create function public.get_iqama_sadad_documents()
returns table (
  id uuid, source_file_name text, employee_name text, employee_branch_id bigint, employee_branch text,
  iqama_number text, sadad_number text, duration_months integer, detected_amount numeric, created_at timestamptz,
  statement_mjv_id uuid, task_issued boolean, task_status text
) language plpgsql stable security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  return query
    select d.id,d.source_file_name,d.employee_name,d.employee_branch_id,
      case when b.id is null then 'No branch configured'::text else concat_ws(' - ',coalesce(b.name_en,b.name_ar,'Branch '||b.id),nullif(coalesce(b.location_en,b.location_ar,''),''))::text end,
      d.iqama_number,d.sadad_number,d.duration_months,d.detected_amount,d.created_at,d.statement_mjv_id,
      coalesce(m.status in ('tasks_posted','partially_posted','completed'),false),coalesce(m.status,'not_issued')::text
    from public.iqama_sadad_documents d
    left join public.branches b on b.id=d.employee_branch_id
    left join public.statement_mjvs m on m.id=d.statement_mjv_id
    where coalesce(m.status,'') <> 'completed'
    order by d.created_at desc;
end;
$$;

revoke all on function public.save_statement_mjv(text,uuid,date,text,jsonb,text), public.get_statement_mjv(text,uuid,date,text), public.link_iqama_sadad_documents_to_mjv(uuid,uuid[]), public.get_iqama_sadad_documents() from public,anon;
grant execute on function public.save_statement_mjv(text,uuid,date,text,jsonb,text), public.get_statement_mjv(text,uuid,date,text), public.link_iqama_sadad_documents_to_mjv(uuid,uuid[]), public.get_iqama_sadad_documents() to authenticated;
notify pgrst,'reload schema';
commit;
