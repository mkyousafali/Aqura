begin;

create table if not exists public.default_accounts_other_branches (
  id uuid primary key default gen_random_uuid(),
  source_branch_id bigint not null references public.branches(id),
  target_branch_id bigint not null references public.branches(id),
  target_ledger_id bigint not null,
  target_ledger_name text not null,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_by uuid references public.users(id),
  updated_at timestamptz not null default now(),
  constraint default_accounts_other_branches_distinct_branches
    check (source_branch_id <> target_branch_id),
  unique (source_branch_id, target_branch_id)
);

alter table public.default_accounts_other_branches enable row level security;
revoke all on public.default_accounts_other_branches from public, anon, authenticated;

create or replace function public.list_default_accounts_other_branches()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
begin
  if v_actor is null or not exists (
    select 1 from public.users u
    where u.id = v_actor and u.status = 'active' and coalesce(u.is_master_admin, false)
  ) then
    raise exception 'Master administrator access required.';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', d.id,
      'source_branch_id', d.source_branch_id,
      'source_branch_name', concat_ws(' - ', s.name_en, nullif(s.location_en, '')),
      'target_branch_id', d.target_branch_id,
      'target_branch_name', concat_ws(' - ', t.name_en, nullif(t.location_en, '')),
      'target_ledger_id', d.target_ledger_id,
      'target_ledger_name', d.target_ledger_name,
      'updated_at', d.updated_at
    ) order by s.name_en, t.name_en)
    from public.default_accounts_other_branches d
    join public.branches s on s.id = d.source_branch_id
    join public.branches t on t.id = d.target_branch_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.save_default_account_other_branch(
  p_source_branch_id bigint,
  p_target_branch_id bigint,
  p_target_ledger_id bigint,
  p_target_ledger_name text
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
  v_id uuid;
begin
  if v_actor is null or not exists (
    select 1 from public.users u
    where u.id = v_actor and u.status = 'active' and coalesce(u.is_master_admin, false)
  ) then
    raise exception 'Master administrator access required.';
  end if;
  if p_source_branch_id is null or p_target_branch_id is null then
    raise exception 'Select source and target branches.';
  end if;
  if p_source_branch_id = p_target_branch_id then
    raise exception 'Source and target branches must be different.';
  end if;
  if not exists (select 1 from public.branches where id = p_source_branch_id and is_active = true)
     or not exists (select 1 from public.branches where id = p_target_branch_id and is_active = true) then
    raise exception 'Select active source and target branches.';
  end if;
  if p_target_ledger_id is null or nullif(trim(coalesce(p_target_ledger_name, '')), '') is null then
    raise exception 'Select the source branch ledger from the target branch.';
  end if;

  insert into public.default_accounts_other_branches (
    source_branch_id, target_branch_id, target_ledger_id, target_ledger_name,
    created_by, updated_by
  ) values (
    p_source_branch_id, p_target_branch_id, p_target_ledger_id,
    trim(p_target_ledger_name), v_actor, v_actor
  )
  on conflict (source_branch_id, target_branch_id) do update
  set target_ledger_id = excluded.target_ledger_id,
      target_ledger_name = excluded.target_ledger_name,
      updated_by = v_actor,
      updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.remove_default_account_other_branch(p_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
begin
  if v_actor is null or not exists (
    select 1 from public.users u
    where u.id = v_actor and u.status = 'active' and coalesce(u.is_master_admin, false)
  ) then
    raise exception 'Master administrator access required.';
  end if;

  delete from public.default_accounts_other_branches where id = p_id;
  return found;
end;
$$;

revoke all on function public.list_default_accounts_other_branches() from public, anon;
revoke all on function public.save_default_account_other_branch(bigint, bigint, bigint, text) from public, anon;
revoke all on function public.remove_default_account_other_branch(uuid) from public, anon;
grant execute on function public.list_default_accounts_other_branches() to authenticated;
grant execute on function public.save_default_account_other_branch(bigint, bigint, bigint, text) to authenticated;
grant execute on function public.remove_default_account_other_branch(uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
