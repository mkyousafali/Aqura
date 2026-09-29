begin;

create extension if not exists btree_gist;

create table if not exists public.day_off_weekday_versions (
  id bigint generated always as identity primary key,
  employee_id text not null references public.hr_employee_master(id) on delete cascade,
  date_from date not null,
  date_to date,
  created_at timestamptz not null default now(),
  created_by uuid,
  change_reason text,
  constraint day_off_weekday_versions_dates_check check (date_to is null or date_to >= date_from),
  constraint day_off_weekday_versions_no_overlap exclude using gist (
    employee_id with =,
    daterange(date_from, coalesce(date_to, 'infinity'::date), '[]') with &&
  )
);

create table if not exists public.day_off_weekday_version_days (
  version_id bigint not null references public.day_off_weekday_versions(id) on delete cascade,
  weekday integer not null check (weekday between 0 and 6),
  primary key (version_id, weekday)
);

create table if not exists public.day_off_weekday_version_audit (
  id bigint generated always as identity primary key,
  version_id bigint,
  employee_id text not null,
  action text not null check (action in ('created', 'deleted')),
  snapshot jsonb not null,
  performed_at timestamptz not null default now(),
  performed_by uuid,
  reason text
);

create index if not exists idx_day_off_weekday_versions_employee_dates
  on public.day_off_weekday_versions(employee_id, date_from, date_to);

-- Preserve the legacy configuration as the baseline requested by the business.
insert into public.day_off_weekday_versions(employee_id, date_from, date_to, change_reason)
select distinct d.employee_id, date '2024-01-01', null::date, 'Migrated from legacy day_off_weekday'
from public.day_off_weekday d
where not exists (
  select 1 from public.day_off_weekday_versions v where v.employee_id = d.employee_id
);

insert into public.day_off_weekday_version_days(version_id, weekday)
select v.id, d.weekday
from public.day_off_weekday_versions v
join public.day_off_weekday d on d.employee_id = v.employee_id
where v.date_from = date '2024-01-01'
on conflict do nothing;

create or replace function public.set_day_off_weekday_version(
  p_employee_id text,
  p_date_from date,
  p_weekdays integer[],
  p_created_by uuid default null,
  p_change_reason text default null
) returns bigint
language plpgsql security definer set search_path = public
as $$
declare
  v_previous public.day_off_weekday_versions%rowtype;
  v_new_id bigint;
  v_weekday integer;
begin
  if p_date_from is null then raise exception 'Effective start date is required'; end if;
  if exists (select 1 from unnest(coalesce(p_weekdays, '{}'::integer[])) d where d not between 0 and 6) then
    raise exception 'Weekday must be between 0 and 6';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_employee_id));

  if exists (select 1 from public.day_off_weekday_versions where employee_id = p_employee_id and date_from >= p_date_from) then
    raise exception 'A version already starts on or after this date. Delete the conflicting version first.';
  end if;

  select * into v_previous
  from public.day_off_weekday_versions
  where employee_id = p_employee_id and date_from < p_date_from
  order by date_from desc limit 1 for update;

  if found then
    update public.day_off_weekday_versions set date_to = p_date_from - 1 where id = v_previous.id;
  end if;

  insert into public.day_off_weekday_versions(employee_id, date_from, date_to, created_by, change_reason)
  values (p_employee_id, p_date_from, null, p_created_by, p_change_reason)
  returning id into v_new_id;

  foreach v_weekday in array coalesce(p_weekdays, '{}'::integer[]) loop
    insert into public.day_off_weekday_version_days(version_id, weekday)
    values (v_new_id, v_weekday) on conflict do nothing;
  end loop;

  insert into public.day_off_weekday_version_audit(version_id, employee_id, action, snapshot, performed_by, reason)
  values (v_new_id, p_employee_id, 'created', jsonb_build_object(
    'date_from', p_date_from, 'date_to', null, 'weekdays', coalesce(p_weekdays, '{}'::integer[])
  ), p_created_by, p_change_reason);

  return v_new_id;
end;
$$;

create or replace function public.delete_day_off_weekday_version(
  p_version_id bigint,
  p_deleted_by uuid default null,
  p_reason text default null
) returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  v_target public.day_off_weekday_versions%rowtype;
  v_previous_id bigint;
  v_next_from date;
  v_days integer[];
begin
  select * into v_target from public.day_off_weekday_versions where id = p_version_id for update;
  if not found then raise exception 'Day-off weekday version not found'; end if;

  perform pg_advisory_xact_lock(hashtext(v_target.employee_id));
  select array_agg(weekday order by weekday) into v_days
  from public.day_off_weekday_version_days where version_id = p_version_id;

  insert into public.day_off_weekday_version_audit(version_id, employee_id, action, snapshot, performed_by, reason)
  values (v_target.id, v_target.employee_id, 'deleted', jsonb_build_object(
    'date_from', v_target.date_from, 'date_to', v_target.date_to, 'weekdays', coalesce(v_days, '{}'::integer[])
  ), p_deleted_by, p_reason);

  select id into v_previous_id from public.day_off_weekday_versions
  where employee_id = v_target.employee_id and date_from < v_target.date_from
  order by date_from desc limit 1;
  select date_from into v_next_from from public.day_off_weekday_versions
  where employee_id = v_target.employee_id and date_from > v_target.date_from
  order by date_from limit 1;

  delete from public.day_off_weekday_versions where id = p_version_id;
  if v_previous_id is not null then
    update public.day_off_weekday_versions
    set date_to = case when v_next_from is null then null else v_next_from - 1 end
    where id = v_previous_id;
  end if;
  return true;
end;
$$;

create or replace function public.is_day_off_weekday(p_employee_id text, p_date date)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.day_off_weekday_versions v
    join public.day_off_weekday_version_days d on d.version_id = v.id
    where v.employee_id = p_employee_id
      and v.date_from <= p_date
      and (v.date_to is null or v.date_to >= p_date)
      and d.weekday = extract(dow from p_date)::integer
  );
$$;

alter table public.day_off_weekday_versions enable row level security;
alter table public.day_off_weekday_version_days enable row level security;
alter table public.day_off_weekday_version_audit enable row level security;
create policy day_off_weekday_versions_read on public.day_off_weekday_versions for select using (true);
create policy day_off_weekday_version_days_read on public.day_off_weekday_version_days for select using (true);
create policy day_off_weekday_version_audit_read on public.day_off_weekday_version_audit for select using (true);

grant select on public.day_off_weekday_versions, public.day_off_weekday_version_days, public.day_off_weekday_version_audit to anon, authenticated, service_role;
grant all on public.day_off_weekday_versions, public.day_off_weekday_version_days, public.day_off_weekday_version_audit to service_role;
grant usage, select on sequence public.day_off_weekday_versions_id_seq, public.day_off_weekday_version_audit_id_seq to service_role;
grant execute on function public.set_day_off_weekday_version(text,date,integer[],uuid,text) to authenticated, service_role;
grant execute on function public.delete_day_off_weekday_version(bigint,uuid,text) to authenticated, service_role;
grant execute on function public.is_day_off_weekday(text,date) to anon, authenticated, service_role;

create or replace function public.get_break_schedule_status(p_date_from date, p_date_to date, p_branch_id integer default null) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare v_result jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_result
  from (
    select e.id employee_id, e.name_en, e.name_ar, e.current_branch_id branch_id,
      b.name_en branch_name_en, b.name_ar branch_name_ar, d.dt::date shift_date,
      (
        exists (select 1 from hr_special_shift_date_wise_versions v where v.employee_id=e.id and v.date_from<=d.dt::date and (v.date_to is null or v.date_to>=d.dt::date))
        or (
          not exists (select 1 from day_off o where o.employee_id=e.id and o.day_off_date=d.dt::date and o.approval_status='approved')
          and not public.is_day_off_weekday(e.id, d.dt::date)
          and (
            exists (select 1 from hr_special_shift_weekday_versions v where v.employee_id=e.id and v.weekday=extract(dow from d.dt::date)::integer and v.date_from<=d.dt::date and (v.date_to is null or v.date_to>=d.dt::date))
            or exists (select 1 from hr_regular_shift_versions v where v.employee_id=e.id and v.date_from<=d.dt::date and (v.date_to is null or v.date_to>=d.dt::date))
          )
        )
      ) scheduled
    from hr_employee_master e
    left join hr_employee_current_status s on s.employee_id=e.id
    left join branches b on b.id=e.current_branch_id
    cross join generate_series(p_date_from,p_date_to,interval '1 day') d(dt)
    where e.user_id is not null
      and coalesce(s.employment_status,'') not in ('Remote Job','Vacation','Resigned')
      and (p_branch_id is null or e.current_branch_id=p_branch_id)
  ) t;
  return jsonb_build_object('success',true,'rows',v_result);
exception when others then return jsonb_build_object('success',false,'error',sqlerrm);
end;
$$;

commit;
