begin;

alter table public.hr_employee_master
  add column if not exists is_removed boolean not null default false,
  add column if not exists removed_at timestamptz,
  add column if not exists removed_by uuid,
  add column if not exists removed_user_status varchar(50);

create index if not exists hr_employee_master_active_idx
  on public.hr_employee_master(id) where is_removed = false;

drop policy if exists employee_master_hide_removed on public.hr_employee_master;
create policy employee_master_hide_removed
  on public.hr_employee_master
  as restrictive
  for select
  to authenticated
  using (is_removed = false);

create or replace function public.sync_removed_employee_user_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status varchar(50);
begin
  if new.is_removed = true and old.is_removed = false then
    select status into v_status from public.users where id = new.user_id;
    new.removed_user_status := v_status;
    new.removed_at := coalesce(new.removed_at, now());
    update public.users set status = 'inactive' where id = new.user_id;
  elsif new.is_removed = false and old.is_removed = true then
    update public.users
       set status = coalesce(old.removed_user_status, 'active')
     where id = new.user_id;
    new.removed_at := null;
    new.removed_by := null;
    new.removed_user_status := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_removed_employee_user_status on public.hr_employee_master;
create trigger trg_sync_removed_employee_user_status
before update of is_removed on public.hr_employee_master
for each row execute function public.sync_removed_employee_user_status();

create or replace function public.remove_employee_from_system(p_employee_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := public.aqura_current_user_id();
begin
  if v_actor is null or not exists (
    select 1 from public.users
    where id = v_actor and is_master_admin = true and status = 'active'
  ) then
    raise exception 'Master Admin access required';
  end if;

  update public.hr_employee_master
     set is_removed = true,
         removed_at = now(),
         removed_by = v_actor
   where id = p_employee_id
     and is_removed = false;

  if not found then
    raise exception 'Employee not found or already removed';
  end if;
end;
$$;

revoke all on function public.remove_employee_from_system(text) from public, anon;
grant execute on function public.remove_employee_from_system(text) to authenticated, service_role;

create or replace view public.hr_employee_master_with_status as
select
  m.id, m.user_id, m.current_branch_id, m.current_position_id, m.name_en, m.name_ar,
  m.employee_id_mapping, m.created_at, m.updated_at, m.nationality_id,
  m.id_expiry_date, m.id_document_url, m.health_card_expiry_date, m.health_card_document_url,
  m.driving_licence_expiry_date, m.driving_licence_document_url, m.id_number,
  m.health_card_number, m.driving_licence_number, m.bank_name, m.iban,
  m.contract_expiry_date, m.contract_document_url, m.sponsorship_status,
  m.insurance_expiry_date, m.insurance_company_id, m.health_educational_renewal_date,
  m.date_of_birth, m.join_date, m.work_permit_expiry_date, m.probation_period_expiry_date,
  m.permitted_early_leave_hours, m.whatsapp_number, m.email, m.privacy_policy_accepted,
  m.erp_employee_id_mapping,
  s.employment_status, s.employment_status_effective_date, s.employment_status_reason
from public.hr_employee_master m
left join public.hr_employee_current_status s on s.employee_id = m.id
where m.is_removed = false;

create or replace view public.user_management_view as
select
  u.id, u.username, u.status, u.is_master_admin, u.is_admin, u.branch_id, u.employee_id,
  u.position_id, u.created_at, u.updated_at, u.failed_login_attempts, u.is_first_login,
  u.last_login_at, e.name as employee_name, b.name_en as branch_name,
  p.position_title_en, p.position_title_ar, u.default_language
from public.users u
left join public.hr_employees e on u.employee_id = e.id
left join public.branches b on u.branch_id = b.id
left join public.hr_positions p on u.position_id = p.id
where not exists (
  select 1 from public.hr_employee_master m where m.user_id = u.id and m.is_removed = true
);

create or replace function public.get_user_management_data()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  users_data jsonb;
  branches_data jsonb;
  employees_data jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(u)::jsonb order by u.created_at desc), '[]'::jsonb)
    into users_data from public.user_management_view u;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id, 'name_en', b.name_en, 'name_ar', b.name_ar,
    'location_en', b.location_en, 'location_ar', b.location_ar
  ) order by b.name_en), '[]'::jsonb)
    into branches_data from public.branches b where b.is_active = true;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id, 'user_id', e.user_id, 'name_en', e.name_en, 'name_ar', e.name_ar,
    'whatsapp_number', e.whatsapp_number, 'email', e.email
  )), '[]'::jsonb)
    into employees_data
    from public.hr_employee_master e
   where e.user_id is not null and e.is_removed = false;

  return jsonb_build_object('users', users_data, 'branches', branches_data, 'employees', employees_data);
end;
$$;

-- Patch the current employee dashboard RPCs without changing their public signatures.
do $$
declare
  v_definition text;
begin
  select pg_get_functiondef(p.oid) into v_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_employee_master_list'
    and pg_get_function_identity_arguments(p.oid) =
      'p_search text, p_page integer, p_limit integer, p_status_filter text, p_branch_filter integer, p_position_filter uuid, p_exclude_statuses text[], p_sponsor_filter bigint';

  if v_definition is null then
    raise exception 'Current get_employee_master_list function was not found';
  end if;
  if position('e.is_removed = false' in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      'and (p_status_filter is null',
      'and e.is_removed = false' || chr(10) || '    and (p_status_filter is null'
    );
    execute v_definition;
  end if;

  select pg_get_functiondef(p.oid) into v_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_employee_master_counts'
    and pg_get_function_identity_arguments(p.oid) =
      'p_search text, p_branch_filter integer, p_sponsor_filter bigint, p_exclude_statuses text[]';

  if v_definition is null then
    raise exception 'Current get_employee_master_counts function was not found';
  end if;
  if position('e.is_removed = false' in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      'and (p_branch_filter is null',
      'and e.is_removed = false' || chr(10) || '    and (p_branch_filter is null'
    );
    execute v_definition;
  end if;
end;
$$;

commit;
