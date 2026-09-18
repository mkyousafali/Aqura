begin;

drop function if exists public.reopen_incident_cascade(text);

create or replace function public.reopen_incident_cascade(
  p_incident_id text,
  p_actor_user_id uuid,
  p_session_token text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_incident public.incidents%rowtype;
  v_action_count integer := 0;
  v_task_count integer := 0;
  v_assignment_count integer := 0;
  v_reset_statuses jsonb;
begin
  if v_actor is null or not exists (
    select 1
    from public.users u
    where u.id = v_actor
      and u.status = 'active'
      and coalesce(u.is_master_admin, false)
      and (
        auth.uid() = v_actor
        or exists (
          select 1
          from public.user_sessions us
          where us.user_id = v_actor
            and us.session_token = p_session_token
            and us.is_active = true
            and us.expires_at > now()
        )
      )
  ) then
    raise exception 'A valid active Master Admin session is required to reopen an incident';
  end if;

  select *
  into v_incident
  from public.incidents i
  where i.id::text = p_incident_id
  for update;

  if not found then
    raise exception 'Incident % was not found', p_incident_id;
  end if;

  if v_incident.resolution_status not in ('claimed', 'resolved') then
    raise exception 'Only claimed or resolved incidents can be reopened';
  end if;

  select coalesce(
    jsonb_object_agg(s.user_id, jsonb_build_object('status', 'reported')),
    '{}'::jsonb
  )
  into v_reset_statuses
  from jsonb_each(coalesce(v_incident.user_statuses, '{}'::jsonb)) s(user_id, status_data);

  select count(*)::integer
  into v_assignment_count
  from public.quick_task_assignments qta
  join public.quick_tasks qt on qt.id = qta.quick_task_id
  where qt.incident_id::text = p_incident_id;

  delete from public.quick_task_assignments qta
  using public.quick_tasks qt
  where qta.quick_task_id = qt.id
    and qt.incident_id::text = p_incident_id;

  delete from public.quick_tasks qt
  where qt.incident_id::text = p_incident_id;
  get diagnostics v_task_count = row_count;

  delete from public.incident_actions ia
  where ia.incident_id::text = p_incident_id;
  get diagnostics v_action_count = row_count;

  update public.incidents
  set resolution_status = 'reported',
      claims_status = null,
      claimed_user_id = null,
      user_statuses = v_reset_statuses,
      investigation_report = null,
      resolution_report = null,
      updated_at = now(),
      updated_by = v_actor
  where id::text = p_incident_id;

  return jsonb_build_object(
    'success', true,
    'incident_id', p_incident_id,
    'incident_actions_removed', v_action_count,
    'quick_tasks_removed', v_task_count,
    'task_assignments_removed', v_assignment_count
  );
end;
$$;

revoke all on function public.reopen_incident_cascade(text, uuid, text) from public;
grant execute on function public.reopen_incident_cascade(text, uuid, text) to authenticated, service_role;

commit;
