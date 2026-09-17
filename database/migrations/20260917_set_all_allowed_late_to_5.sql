begin;

alter table public.hr_regular_shift_slots
  alter column allowed_late_start_minutes set default 5;
alter table public.hr_special_shift_weekday_slots
  alter column allowed_late_start_minutes set default 5;
alter table public.hr_special_shift_date_wise_slots
  alter column allowed_late_start_minutes set default 5;

-- Apply a universal five-minute late allowance from 2026-08-25 without
-- changing the shift configuration applicable before that date.
do $$
declare
  v_cutoff constant date := date '2026-08-25';
  v_rec record;
  v_new_id bigint;
begin
  -- Regular shifts: split any version that crosses the effective-date boundary.
  for v_rec in
    select * from public.hr_regular_shift_versions
    where date_from < v_cutoff and (date_to is null or date_to >= v_cutoff)
    order by id
  loop
    insert into public.hr_regular_shift_versions(employee_id,date_from,date_to)
    values(v_rec.employee_id,v_cutoff,v_rec.date_to) returning id into v_new_id;

    insert into public.hr_regular_shift_slots(
      version_id,slot_order,shift_start_time,shift_start_buffer,shift_end_time,
      shift_end_buffer,is_shift_overlapping_next_day,working_hours,
      allowed_late_start_minutes,allowed_early_end_minutes)
    select v_new_id,slot_order,shift_start_time,shift_start_buffer,shift_end_time,
      shift_end_buffer,is_shift_overlapping_next_day,working_hours,5,
      allowed_early_end_minutes
    from public.hr_regular_shift_slots where version_id=v_rec.id;

    update public.hr_regular_shift_versions
    set date_to=v_cutoff-1,updated_at=now() where id=v_rec.id;
  end loop;

  -- Weekday-specific shifts use the same version-boundary strategy.
  for v_rec in
    select * from public.hr_special_shift_weekday_versions
    where date_from < v_cutoff and (date_to is null or date_to >= v_cutoff)
    order by id
  loop
    insert into public.hr_special_shift_weekday_versions(employee_id,weekday,date_from,date_to)
    values(v_rec.employee_id,v_rec.weekday,v_cutoff,v_rec.date_to) returning id into v_new_id;

    insert into public.hr_special_shift_weekday_slots(
      version_id,slot_order,shift_start_time,shift_start_buffer,shift_end_time,
      shift_end_buffer,is_shift_overlapping_next_day,working_hours,
      allowed_late_start_minutes,allowed_early_end_minutes)
    select v_new_id,slot_order,shift_start_time,shift_start_buffer,shift_end_time,
      shift_end_buffer,is_shift_overlapping_next_day,working_hours,5,
      allowed_early_end_minutes
    from public.hr_special_shift_weekday_slots where version_id=v_rec.id;

    update public.hr_special_shift_weekday_versions
    set date_to=v_cutoff-1,updated_at=now() where id=v_rec.id;
  end loop;

  -- Date-wise special shifts may span a range and must also be split.
  for v_rec in
    select * from public.hr_special_shift_date_wise_versions
    where date_from < v_cutoff and date_to >= v_cutoff
    order by id
  loop
    insert into public.hr_special_shift_date_wise_versions(employee_id,date_from,date_to)
    values(v_rec.employee_id,v_cutoff,v_rec.date_to) returning id into v_new_id;

    insert into public.hr_special_shift_date_wise_slots(
      version_id,slot_order,shift_start_time,shift_start_buffer,shift_end_time,
      shift_end_buffer,is_shift_overlapping_next_day,working_hours,
      allowed_late_start_minutes,allowed_early_end_minutes)
    select v_new_id,slot_order,shift_start_time,shift_start_buffer,shift_end_time,
      shift_end_buffer,is_shift_overlapping_next_day,working_hours,5,
      allowed_early_end_minutes
    from public.hr_special_shift_date_wise_slots where version_id=v_rec.id;

    update public.hr_special_shift_date_wise_versions
    set date_to=v_cutoff-1,updated_at=now() where id=v_rec.id;
  end loop;

  -- Force every slot effective from the cutoff onward to exactly five minutes.
  update public.hr_regular_shift_slots s set allowed_late_start_minutes=5,updated_at=now()
  from public.hr_regular_shift_versions v
  where v.id=s.version_id and v.date_from>=v_cutoff
    and s.allowed_late_start_minutes is distinct from 5;

  update public.hr_special_shift_weekday_slots s set allowed_late_start_minutes=5,updated_at=now()
  from public.hr_special_shift_weekday_versions v
  where v.id=s.version_id and v.date_from>=v_cutoff
    and s.allowed_late_start_minutes is distinct from 5;

  update public.hr_special_shift_date_wise_slots s set allowed_late_start_minutes=5,updated_at=now()
  from public.hr_special_shift_date_wise_versions v
  where v.id=s.version_id and v.date_from>=v_cutoff
    and s.allowed_late_start_minutes is distinct from 5;
end $$;

-- Safety assertions: no slot effective on/after the cutoff may have another
-- allowance, and no version may continue across the boundary unsplit.
do $$
begin
  if exists(
    select 1 from public.hr_regular_shift_versions v
    join public.hr_regular_shift_slots s on s.version_id=v.id
    where v.date_from>=date '2026-08-25' and s.allowed_late_start_minutes is distinct from 5
  ) or exists(
    select 1 from public.hr_special_shift_weekday_versions v
    join public.hr_special_shift_weekday_slots s on s.version_id=v.id
    where v.date_from>=date '2026-08-25' and s.allowed_late_start_minutes is distinct from 5
  ) or exists(
    select 1 from public.hr_special_shift_date_wise_versions v
    join public.hr_special_shift_date_wise_slots s on s.version_id=v.id
    where v.date_from>=date '2026-08-25' and s.allowed_late_start_minutes is distinct from 5
  ) then
    raise exception 'Five-minute allowance validation failed';
  end if;

  if exists(select 1 from public.hr_regular_shift_versions where date_from<date '2026-08-25' and (date_to is null or date_to>=date '2026-08-25'))
    or exists(select 1 from public.hr_special_shift_weekday_versions where date_from<date '2026-08-25' and (date_to is null or date_to>=date '2026-08-25'))
    or exists(select 1 from public.hr_special_shift_date_wise_versions where date_from<date '2026-08-25' and date_to>=date '2026-08-25') then
    raise exception 'A shift version still crosses the effective-date boundary';
  end if;
end $$;

commit;
