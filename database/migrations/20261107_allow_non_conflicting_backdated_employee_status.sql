begin;

-- A historical change can fill an unrecorded period, but must not replace a
-- closed period or a later transition. Normal changes still close the open row.
create or replace function public.change_employee_status(
  p_employee_id text, p_new_status text, p_start_date date, p_reason text,
  p_created_by uuid default null
) returns table(id bigint,employee_id text,status text,effective_from date,effective_to date,reason text)
language plpgsql security definer set search_path=public as $f$
declare
  v_valid text[] := array['Job (With Finger)','Remote Job','Vacation','Resigned'];
  v_open record;
  v_conflict record;
  v_next_start date;
  v_end_date date;
  v_actor uuid := public.aqura_current_user_id();
begin
  if auth.role() = 'service_role' and v_actor is null then v_actor := p_created_by; end if;
  if coalesce(trim(p_employee_id),'') = '' then raise exception 'Employee ID is required'; end if;
  if p_new_status is null or not (p_new_status = any(v_valid)) then
    raise exception 'Invalid employment status value: %', p_new_status;
  end if;
  if p_start_date is null then raise exception 'Start date is required'; end if;
  if coalesce(trim(p_reason),'') = '' then raise exception 'Reason is required'; end if;

  -- Serialize changes even when the employee has no open status yet.
  perform 1 from public.hr_employee_master m where m.id = p_employee_id for update;
  if not found then raise exception 'Employee not found'; end if;
  perform 1 from public.hr_employee_status_history h
    where h.employee_id = p_employee_id order by h.id for update;

  select h.* into v_open from public.hr_employee_status_history h
    where h.employee_id = p_employee_id and h.effective_to is null limit 1;

  -- Never overwrite a closed period or a transition already recorded on the
  -- selected date. The open period can still be split by a later transition.
  select h.* into v_conflict from public.hr_employee_status_history h
    where h.employee_id = p_employee_id
      and (
        (h.effective_to is not null
          and (h.effective_from is null or h.effective_from <= p_start_date)
          and h.effective_to >= p_start_date)
        or h.effective_from = p_start_date
      )
    order by h.effective_from desc nulls last, h.id desc limit 1;
  if v_conflict.id is not null then
    raise exception 'This date conflicts with an existing "%" period (% to %)',
      v_conflict.status, coalesce(v_conflict.effective_from::text, 'unknown'),
      coalesce(v_conflict.effective_to::text, 'ongoing');
  end if;

  -- Bound a historical insertion by the next existing transition, preserving
  -- every later status. In a gap this fills only the unrecorded days.
  select min(h.effective_from) into v_next_start
    from public.hr_employee_status_history h
    where h.employee_id = p_employee_id and h.effective_from > p_start_date;
  v_end_date := v_next_start - 1;

  if v_open.id is not null
    and (v_open.effective_from is null or v_open.effective_from < p_start_date) then
    update public.hr_employee_status_history h
      set effective_to = p_start_date - 1 where h.id = v_open.id;
  end if;

  return query insert into public.hr_employee_status_history
    (employee_id,status,effective_from,effective_to,reason,created_by)
    values(p_employee_id,p_new_status,p_start_date,v_end_date,trim(p_reason),v_actor)
    returning hr_employee_status_history.id,hr_employee_status_history.employee_id,
      hr_employee_status_history.status,hr_employee_status_history.effective_from,
      hr_employee_status_history.effective_to,hr_employee_status_history.reason;
end $f$;

revoke execute on function public.change_employee_status(text,text,date,text,uuid) from public,anon;
grant execute on function public.change_employee_status(text,text,date,text,uuid) to authenticated,service_role;

comment on function public.change_employee_status(text,text,date,text,uuid) is
  'Changes employment status atomically. Backdated changes fill unrecorded periods up to the next transition; existing closed periods and later transitions are preserved.';

commit;
