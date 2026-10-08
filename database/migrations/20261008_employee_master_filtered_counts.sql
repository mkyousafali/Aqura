begin;

create or replace function public.get_employee_master_counts(
  p_search text default ''::text,
  p_branch_filter integer default null::integer,
  p_sponsor_filter bigint default null::bigint,
  p_exclude_statuses text[] default null::text[]
)
returns table(total_count bigint, saudi_count bigint, non_saudi_count bigint)
language sql
security definer
set search_path to 'public'
as $$
  select
    count(*) as total_count,
    count(*) filter (
      where lower(trim(coalesce(n.name_en, ''))) in ('saudi arabia', 'saudi')
         or coalesce(n.name_ar, '') like '%السعودية%'
    ) as saudi_count,
    count(*) filter (
      where not (
        lower(trim(coalesce(n.name_en, ''))) in ('saudi arabia', 'saudi')
        or coalesce(n.name_ar, '') like '%السعودية%'
      )
    ) as non_saudi_count
  from public.hr_employee_master e
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
    and (p_branch_filter is null or e.current_branch_id = p_branch_filter)
    and (p_sponsor_filter is null or e.sponsor_id = p_sponsor_filter)
    and (p_exclude_statuses is null
         or array_length(p_exclude_statuses, 1) is null
         or not (s.employment_status = any(p_exclude_statuses)));
$$;

revoke all on function public.get_employee_master_counts(text, integer, bigint, text[]) from public, anon;
grant execute on function public.get_employee_master_counts(text, integer, bigint, text[]) to authenticated, service_role;

commit;
