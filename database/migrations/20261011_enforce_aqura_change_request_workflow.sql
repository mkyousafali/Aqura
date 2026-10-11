begin;

alter table public.aqura_change_requests
  drop constraint if exists aqura_change_requests_status_check;

alter table public.aqura_change_requests
  add constraint aqura_change_requests_status_check check (
    status = any (array[
      'Pending'::text,
      'Cash Received'::text,
      'Safe Box Printed'::text,
      'Ready for Cashier Confirmation'::text,
      'Cashier Confirmed'::text,
      'Completed'::text,
      'Cancelled'::text
    ])
  );

create table if not exists public.aqura_change_request_admin_actions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.aqura_change_requests(id),
  request_number text not null,
  previous_status text not null,
  new_status text not null check (new_status in ('Completed', 'Cancelled')),
  reason text not null check (length(btrim(reason)) between 5 and 1000),
  acted_by uuid references public.users(id),
  action_source text not null default 'finance_manager',
  created_at timestamptz not null default now()
);

create index if not exists aqura_change_request_admin_actions_request_idx
  on public.aqura_change_request_admin_actions(request_id, created_at desc);

alter table public.aqura_change_request_admin_actions enable row level security;
revoke all on table public.aqura_change_request_admin_actions from public, anon, authenticated;
grant select, insert on table public.aqura_change_request_admin_actions to service_role;

with legacy as (
  select id, request_number, status
  from public.aqura_change_requests
  where request_number in (
    '2809202619', '0110202632', '0110202633', '0310202611',
    '0310202612', '0610202613', '0710202631', '0810202611'
  )
    and status not in ('Completed', 'Cancelled')
), logged as (
  insert into public.aqura_change_request_admin_actions
    (request_id, request_number, previous_status, new_status, reason, acted_by, action_source)
  select id, request_number, status, 'Cancelled',
    'Legacy open request administratively closed during change-request workflow enforcement deployment.',
    null, 'deployment'
  from legacy
  returning request_id
)
update public.aqura_change_requests r
set status = 'Cancelled'
where r.id in (select request_id from logged);

create unique index if not exists aqura_change_requests_one_active_per_cashier_idx
  on public.aqura_change_requests(requested_by_user_id)
  where status not in ('Completed', 'Cancelled');

create unique index if not exists aqura_change_requests_one_active_per_receiver_idx
  on public.aqura_change_requests(requested_to_user_id)
  where status not in ('Completed', 'Cancelled');

create or replace function public.aqura_validate_change_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing record;
begin
  if not exists (
    select 1 from public.box_operations bo
    where bo.user_id = new.requested_by_user_id
      and bo.branch_id = new.branch_id
      and bo.status = 'in_use'
  ) then
    raise exception 'Start an Aqura POS counter operation before creating a change request.';
  end if;

  select r.request_number, r.status into v_existing
  from public.aqura_change_requests r
  where r.requested_by_user_id = new.requested_by_user_id
    and r.status not in ('Completed', 'Cancelled')
  order by r.requested_at
  limit 1;
  if found then
    raise exception 'Complete or cancel your existing request % (%) before creating a new request.',
      v_existing.request_number, v_existing.status;
  end if;

  select r.request_number, r.status,
         coalesce(e.name_en, u.username, r.requested_by_user_id::text) as cashier_name
    into v_existing
  from public.aqura_change_requests r
  left join public.users u on u.id = r.requested_by_user_id
  left join public.hr_employee_master e on e.user_id = r.requested_by_user_id and e.is_removed = false
  where r.requested_to_user_id = new.requested_to_user_id
    and r.status not in ('Completed', 'Cancelled')
  order by r.requested_at
  limit 1;
  if found then
    raise exception 'This receiver is handling request % from %. Close that request first.',
      v_existing.request_number, v_existing.cashier_name;
  end if;

  return new;
end;
$$;

drop trigger if exists aqura_validate_change_request_insert_trigger on public.aqura_change_requests;
create trigger aqura_validate_change_request_insert_trigger
before insert on public.aqura_change_requests
for each row execute function public.aqura_validate_change_request_insert();

create or replace function public.aqura_prevent_counter_close_with_open_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request record;
begin
  if old.status = 'in_use' and new.status in ('pending_close', 'completed') then
    select request_number, status into v_request
    from public.aqura_change_requests
    where requested_by_user_id = old.user_id
      and branch_id = old.branch_id
      and status not in ('Completed', 'Cancelled')
    order by requested_at
    limit 1;
    if found then
      raise exception 'Counter cannot be closed. Complete or cancel change request % (%) first.',
        v_request.request_number, v_request.status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists aqura_prevent_counter_close_with_open_request_trigger on public.box_operations;
create trigger aqura_prevent_counter_close_with_open_request_trigger
before update of status on public.box_operations
for each row execute function public.aqura_prevent_counter_close_with_open_request();

create or replace function public.aqura_admin_resolve_change_request(
  p_actor_id uuid,
  p_request_id uuid,
  p_action text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.aqura_change_requests%rowtype;
  v_status text;
begin
  if not exists (
    select 1 from public.users u
    where u.id = p_actor_id and u.status = 'active'
      and (
        coalesce(u.is_master_admin, false)
        or exists (
          select 1 from public.button_permissions bp
          where bp.user_id = u.id
            and bp.button_code = 'CHANGE_REQUESTS'
            and bp.is_enabled = true
        )
      )
  ) then
    raise exception 'Change Requests permission required.';
  end if;

  if p_action not in ('complete', 'cancel') then
    raise exception 'Action must be complete or cancel.';
  end if;
  if length(btrim(coalesce(p_reason, ''))) < 5 then
    raise exception 'A reason of at least 5 characters is required.';
  end if;

  select * into v_request
  from public.aqura_change_requests
  where id = p_request_id
  for update;
  if not found then raise exception 'Change request not found.'; end if;
  if v_request.status in ('Completed', 'Cancelled') then
    raise exception 'This request is already %.', v_request.status;
  end if;

  v_status := case when p_action = 'complete' then 'Completed' else 'Cancelled' end;
  update public.aqura_change_requests
  set status = v_status,
      completed_at = case when v_status = 'Completed' then now() else completed_at end
  where id = v_request.id;

  insert into public.aqura_change_request_admin_actions
    (request_id, request_number, previous_status, new_status, reason, acted_by)
  values
    (v_request.id, v_request.request_number, v_request.status, v_status, btrim(p_reason), p_actor_id);

  return jsonb_build_object('id', v_request.id, 'requestNumber', v_request.request_number, 'status', v_status);
end;
$$;

revoke all on function public.aqura_admin_resolve_change_request(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.aqura_admin_resolve_change_request(uuid, uuid, text, text) to service_role;

create or replace function public.upsert_button_permission(
  p_requesting_user_id uuid,
  p_target_user_id uuid,
  p_button_code text,
  p_is_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_master_admin boolean;
  v_has_access_control boolean;
begin
  select is_master_admin into v_is_master_admin
  from public.users where id = p_requesting_user_id and status = 'active';

  select is_enabled into v_has_access_control
  from public.button_permissions
  where user_id = p_requesting_user_id and button_code = 'BUTTON_ACCESS_CONTROL';

  if p_button_code = 'CHANGE_REQUESTS' and not coalesce(v_is_master_admin, false) then
    return jsonb_build_object('success', false, 'error', 'Only a Master Admin can grant or remove Change Requests permission');
  end if;
  if not coalesce(v_is_master_admin, false) and not coalesce(v_has_access_control, false) then
    return jsonb_build_object('success', false, 'error', 'Access denied: Master Admin or Button Access Control permission required');
  end if;

  insert into public.button_permissions (user_id, button_code, is_enabled, updated_at)
  values (p_target_user_id, p_button_code, p_is_enabled, now())
  on conflict (user_id, button_code)
  do update set is_enabled = excluded.is_enabled, updated_at = now();
  return jsonb_build_object('success', true);
exception when others then
  return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

commit;
