begin;

create table if not exists public.statement_mjvs (
  id uuid primary key default gen_random_uuid(),
  bank text not null check (bank in ('al-ahli','riyad')),
  statement_date date not null,
  source_file_name text,
  status text not null default 'saved' check (status in ('saved','tasks_posted','partially_posted','completed')),
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (bank, statement_date)
);

create table if not exists public.statement_mjv_branches (
  id uuid primary key default gen_random_uuid(),
  statement_mjv_id uuid not null references public.statement_mjvs(id) on delete cascade,
  branch_id bigint not null references public.branches(id),
  branch_name text not null,
  lines jsonb not null,
  debit_total numeric(18,2) not null,
  credit_total numeric(18,2) not null,
  task_id uuid references public.assistant_workflow_tasks(id) on delete set null,
  task_status text not null default 'saved' check (task_status in ('saved','pending','in_progress','completed','failed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (statement_mjv_id, branch_id),
  check (abs(debit_total - credit_total) < 0.005)
);

alter table public.statement_mjvs enable row level security;
alter table public.statement_mjv_branches enable row level security;
revoke all on public.statement_mjvs, public.statement_mjv_branches from public, anon, authenticated;
grant all on public.statement_mjvs, public.statement_mjv_branches to service_role;

create or replace function public.save_statement_mjv(
  p_bank text, p_statement_date date, p_source_file_name text, p_branches jsonb
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_id uuid;
  v_branch jsonb;
  v_debit numeric;
  v_credit numeric;
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  if p_bank not in ('al-ahli','riyad') or p_statement_date is null or p_branches is null or jsonb_typeof(p_branches) <> 'array' or jsonb_array_length(p_branches) = 0 then
    raise exception 'Bank, statement date, and balanced branch entries are required.';
  end if;
  if exists (select 1 from public.statement_mjvs where bank = p_bank and statement_date = p_statement_date) then
    raise exception 'An MJV is already saved for this bank and statement date.';
  end if;
  insert into public.statement_mjvs(bank, statement_date, source_file_name, created_by)
  values (p_bank, p_statement_date, nullif(btrim(p_source_file_name), ''), v_actor) returning id into v_id;
  for v_branch in select value from jsonb_array_elements(p_branches) loop
    v_debit := (v_branch->>'debit')::numeric;
    v_credit := (v_branch->>'credit')::numeric;
    if (v_branch->>'branch_id') is null or jsonb_typeof(v_branch->'lines') <> 'array' or jsonb_array_length(v_branch->'lines') = 0
       or abs(v_debit - v_credit) >= 0.005 then raise exception 'Every branch MJV must contain balanced lines.'; end if;
    insert into public.statement_mjv_branches(statement_mjv_id, branch_id, branch_name, lines, debit_total, credit_total)
    values (v_id, (v_branch->>'branch_id')::bigint, v_branch->>'branch_name', v_branch->'lines', v_debit, v_credit);
  end loop;
  return v_id;
end;
$$;

create or replace function public.get_statement_mjv(p_bank text, p_statement_date date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  return (
    select to_jsonb(m) || jsonb_build_object('branches', coalesce((
      select jsonb_agg(to_jsonb(b) order by b.branch_name) from public.statement_mjv_branches b where b.statement_mjv_id = m.id
    ), '[]'::jsonb)) from public.statement_mjvs m where m.bank = p_bank and m.statement_date = p_statement_date
  );
end;
$$;

create or replace function public.sync_statement_mjv_task_status()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_mjv_id uuid;
begin
  update public.statement_mjv_branches set task_status = new.status, updated_at = now() where task_id = new.id returning statement_mjv_id into v_mjv_id;
  if v_mjv_id is not null then
    update public.statement_mjvs m set status = case
      when not exists (select 1 from public.statement_mjv_branches b where b.statement_mjv_id=m.id and b.task_status <> 'completed') then 'completed'
      when exists (select 1 from public.statement_mjv_branches b where b.statement_mjv_id=m.id and b.task_status = 'completed') then 'partially_posted'
      else 'tasks_posted' end, updated_at = now() where m.id = v_mjv_id;
  end if;
  return new;
end;
$$;

drop trigger if exists sync_statement_mjv_task_status on public.assistant_workflow_tasks;
create trigger sync_statement_mjv_task_status after update of status on public.assistant_workflow_tasks
for each row execute function public.sync_statement_mjv_task_status();

revoke all on function public.save_statement_mjv(text,date,text,jsonb), public.get_statement_mjv(text,date) from public, anon;
grant execute on function public.save_statement_mjv(text,date,text,jsonb), public.get_statement_mjv(text,date) to authenticated;
notify pgrst, 'reload schema';
commit;
