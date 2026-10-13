begin;

create or replace function public.get_receiving_bank_slips(p_record_ids uuid[])
returns table (
  id uuid,
  receiving_record_id uuid,
  storage_path text,
  original_file_name text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.users u
    where u.id = public.aqura_current_user_id()
      and u.status = 'active'
      and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp
        where bp.user_id = u.id and bp.button_code = 'RECEIVING_RECORDS' and bp.is_enabled = true
      ))
  ) then
    raise exception 'Receiving Records permission required';
  end if;

  return query
  select s.id, s.receiving_record_id, s.storage_path, s.original_file_name, s.created_at
  from public.receiving_record_bank_slips s
  where s.receiving_record_id = any(coalesce(p_record_ids, '{}'::uuid[]))
  order by s.created_at desc;
end;
$$;

revoke all on function public.get_receiving_bank_slips(uuid[]) from public;
grant execute on function public.get_receiving_bank_slips(uuid[]) to authenticated, service_role;

commit;
