begin;

drop function if exists public.get_employee_master_list(text, integer, integer, text, integer, uuid, text[]);

create function public.get_employee_master_list(
  p_search text default ''::text,
  p_page integer default 1,
  p_limit integer default 50,
  p_status_filter text default null::text,
  p_branch_filter integer default null::integer,
  p_position_filter uuid default null::uuid,
  p_exclude_statuses text[] default null::text[],
  p_sponsor_filter bigint default null::bigint
)
returns table(
  id text,
  name_en character varying,
  name_ar character varying,
  current_branch_id integer,
  branch_name_en character varying,
  branch_name_ar character varying,
  branch_location_en character varying,
  branch_location_ar character varying,
  current_position_id uuid,
  position_title_en character varying,
  position_title_ar character varying,
  employment_status text,
  whatsapp_number text,
  email text,
  total_count bigint
)
language sql
security definer
set search_path to 'public'
as $$
  select
    e.id, e.name_en, e.name_ar, e.current_branch_id,
    b.name_en as branch_name_en, b.name_ar as branch_name_ar,
    b.location_en as branch_location_en, b.location_ar as branch_location_ar,
    e.current_position_id, pos.position_title_en, pos.position_title_ar,
    s.employment_status, e.whatsapp_number, e.email,
    count(*) over() as total_count
  from public.hr_employee_master e
  left join public.branches b on b.id = e.current_branch_id
  left join public.hr_positions pos on pos.id = e.current_position_id
  left join public.hr_employee_current_status s on s.employee_id = e.id
  left join public.nationalities n on n.id = e.nationality_id
  where
    (coalesce(p_search, '') = ''
      or e.name_en ilike '%' || p_search || '%'
      or e.name_ar ilike '%' || p_search || '%'
      or e.id ilike '%' || p_search || '%'
      or e.id_number ilike '%' || p_search || '%'
      or e.whatsapp_number ilike '%' || p_search || '%'
      or e.email ilike '%' || p_search || '%')
    and (p_status_filter is null or p_status_filter = '' or s.employment_status = p_status_filter)
    and (p_branch_filter is null or e.current_branch_id = p_branch_filter)
    and (p_position_filter is null or e.current_position_id = p_position_filter)
    and (p_sponsor_filter is null or e.sponsor_id = p_sponsor_filter)
    and (p_exclude_statuses is null
         or array_length(p_exclude_statuses, 1) is null
         or not (s.employment_status = any(p_exclude_statuses)))
  order by
    case when lower(trim(coalesce(s.employment_status, ''))) = 'resigned' then 1 else 0 end,
    case
      when e.sponsorship_status = true
       and (lower(trim(coalesce(n.name_en, ''))) = 'saudi arabia' or coalesce(n.name_ar, '') like '%السعودية%') then 0
      when e.sponsorship_status = true then 1
      else 2
    end,
    e.name_en asc nulls last,
    e.id asc
  limit greatest(1, least(p_limit, 200))
  offset (greatest(1, p_page) - 1) * greatest(1, least(p_limit, 200));
$$;

revoke all on function public.get_employee_master_list(text, integer, integer, text, integer, uuid, text[], bigint) from public, anon;
grant execute on function public.get_employee_master_list(text, integer, integer, text, integer, uuid, text[], bigint) to authenticated, service_role;

commit;
