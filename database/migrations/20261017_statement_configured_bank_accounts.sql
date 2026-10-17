begin;

create table if not exists public.statement_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  branch_id bigint not null references public.branches(id) on delete restrict,
  bank text not null check (bank in ('al-ahli','riyad')),
  ledger_id bigint not null,
  ledger_code text,
  ledger_name text not null,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_by uuid references public.users(id),
  updated_at timestamptz not null default now(),
  unique (bank, branch_id, ledger_id)
);

alter table public.statement_bank_accounts enable row level security;
revoke all on public.statement_bank_accounts from public, anon, authenticated;
grant all on public.statement_bank_accounts to service_role;

insert into public.statement_bank_accounts(branch_id,bank,ledger_id,ledger_code,ledger_name,created_by)
select distinct t.branch_id,
  case when t.terminal_id like '117%' then 'riyad' when t.terminal_id like '640%' then 'al-ahli' end,
  t.bank_ledger_id,t.bank_ledger_code,t.bank_ledger_name,t.created_by
from public.statement_terminal_accounts t
where t.terminal_id like '117%' or t.terminal_id like '640%'
on conflict (bank,branch_id,ledger_id) do nothing;

create or replace function public.get_statement_bank_accounts()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id', a.id, 'branch_id', a.branch_id,
    'branch_name', concat_ws(' - ', coalesce(b.name_en,b.name_ar,'Branch '||b.id), nullif(coalesce(b.location_en,b.location_ar,''),'')),
    'bank', a.bank, 'ledger_id', a.ledger_id, 'ledger_code', a.ledger_code, 'ledger_name', a.ledger_name
  ) order by a.bank, b.name_en, b.location_en, a.ledger_name)
  from public.statement_bank_accounts a join public.branches b on b.id=a.branch_id), '[]'::jsonb);
end;
$$;

create or replace function public.save_statement_bank_account(
  p_id uuid, p_branch_id bigint, p_bank text, p_ledger_id bigint, p_ledger_code text, p_ledger_name text
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id(); v_id uuid;
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  if p_bank not in ('al-ahli','riyad') or p_branch_id is null or p_ledger_id is null or nullif(btrim(p_ledger_name),'') is null then
    raise exception 'Active branch, bank, and SQL bank account are required.';
  end if;
  if not exists(select 1 from public.branches where id=p_branch_id and is_active=true) then raise exception 'The selected branch is not active.'; end if;
  if p_id is null then
    insert into public.statement_bank_accounts(branch_id,bank,ledger_id,ledger_code,ledger_name,created_by)
    values(p_branch_id,p_bank,p_ledger_id,nullif(btrim(p_ledger_code),''),btrim(p_ledger_name),v_actor) returning id into v_id;
  else
    update public.statement_bank_accounts set branch_id=p_branch_id,bank=p_bank,ledger_id=p_ledger_id,ledger_code=nullif(btrim(p_ledger_code),''),ledger_name=btrim(p_ledger_name),updated_by=v_actor,updated_at=now()
    where id=p_id returning id into v_id;
    if v_id is null then raise exception 'Configured bank account was not found.'; end if;
  end if;
  return v_id;
end;
$$;

alter table public.statement_mjvs add column if not exists bank_account_id uuid references public.statement_bank_accounts(id) on delete restrict;
alter table public.statement_mjvs drop constraint if exists statement_mjvs_bank_statement_date_key;
create unique index if not exists statement_mjvs_bank_account_date_unique on public.statement_mjvs(bank,bank_account_id,statement_date);

drop function if exists public.save_statement_mjv(text,date,text,jsonb);
drop function if exists public.get_statement_mjv(text,date);

create function public.save_statement_mjv(
  p_bank text, p_bank_account_id uuid, p_statement_date date, p_source_file_name text, p_branches jsonb
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id(); v_id uuid; v_branch jsonb; v_debit numeric; v_credit numeric;
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  if p_bank not in ('al-ahli','riyad') or p_bank_account_id is null or p_statement_date is null or p_branches is null or jsonb_typeof(p_branches)<>'array' or jsonb_array_length(p_branches)=0 then raise exception 'Bank account, date, and balanced branch entries are required.'; end if;
  if not exists(select 1 from public.statement_bank_accounts where id=p_bank_account_id and bank=p_bank) then raise exception 'The selected account is not configured for this bank.'; end if;
  if exists(select 1 from public.statement_mjvs where bank=p_bank and bank_account_id=p_bank_account_id and statement_date=p_statement_date) then raise exception 'An MJV is already saved for this bank account and statement date.'; end if;
  insert into public.statement_mjvs(bank,bank_account_id,statement_date,source_file_name,created_by) values(p_bank,p_bank_account_id,p_statement_date,nullif(btrim(p_source_file_name),''),v_actor) returning id into v_id;
  for v_branch in select value from jsonb_array_elements(p_branches) loop
    v_debit := (v_branch->>'debit')::numeric; v_credit := (v_branch->>'credit')::numeric;
    if (v_branch->>'branch_id') is null or jsonb_typeof(v_branch->'lines')<>'array' or jsonb_array_length(v_branch->'lines')=0 or abs(v_debit-v_credit)>=0.005 then raise exception 'Every branch MJV must contain balanced lines.'; end if;
    insert into public.statement_mjv_branches(statement_mjv_id,branch_id,branch_name,lines,debit_total,credit_total)
    values(v_id,(v_branch->>'branch_id')::bigint,v_branch->>'branch_name',v_branch->'lines',v_debit,v_credit);
  end loop;
  return v_id;
end;
$$;

create function public.get_statement_mjv(p_bank text,p_bank_account_id uuid,p_statement_date date)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  return (select to_jsonb(m)||jsonb_build_object('branches',coalesce((select jsonb_agg(to_jsonb(b) order by b.branch_name) from public.statement_mjv_branches b where b.statement_mjv_id=m.id),'[]'::jsonb))
    from public.statement_mjvs m where m.bank=p_bank and m.bank_account_id=p_bank_account_id and m.statement_date=p_statement_date);
end;
$$;

revoke all on function public.get_statement_bank_accounts(), public.save_statement_bank_account(uuid,bigint,text,bigint,text,text), public.save_statement_mjv(text,uuid,date,text,jsonb), public.get_statement_mjv(text,uuid,date) from public,anon;
grant execute on function public.get_statement_bank_accounts(), public.save_statement_bank_account(uuid,bigint,text,bigint,text,text), public.save_statement_mjv(text,uuid,date,text,jsonb), public.get_statement_mjv(text,uuid,date) to authenticated;
notify pgrst,'reload schema';
commit;
