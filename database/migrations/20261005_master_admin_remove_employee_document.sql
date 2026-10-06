begin;

create or replace function public.remove_employee_document(p_employee_id text, p_document_field text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated_rows integer;
begin
  if auth.uid() is null or not exists (
    select 1
      from public.users
     where id = public.aqura_current_user_id()
       and coalesce(is_master_admin, false) = true
       and status = 'active'
  ) then
    raise exception 'Master Admin access required';
  end if;

  if p_document_field not in (
    'id_document_url',
    'health_card_document_url',
    'driving_licence_document_url',
    'contract_document_url'
  ) then
    raise exception 'Unsupported employee document field';
  end if;

  case p_document_field
    when 'id_document_url' then
      update public.hr_employee_master
         set id_document_url = null,
             id_number = null,
             id_expiry_date = null
       where id = p_employee_id;
    when 'health_card_document_url' then
      update public.hr_employee_master
         set health_card_document_url = null,
             health_card_number = null,
             health_card_expiry_date = null
       where id = p_employee_id;
    when 'driving_licence_document_url' then
      update public.hr_employee_master
         set driving_licence_document_url = null,
             driving_licence_number = null,
             driving_licence_expiry_date = null
       where id = p_employee_id;
    when 'contract_document_url' then
      update public.hr_employee_master
         set contract_document_url = null,
             contract_expiry_date = null
       where id = p_employee_id;
  end case;

  get diagnostics v_updated_rows = row_count;
  if v_updated_rows = 0 then
    raise exception 'Employee not found';
  end if;
end;
$$;

revoke all on function public.remove_employee_document(text, text) from public, anon;
grant execute on function public.remove_employee_document(text, text) to authenticated, service_role;

commit;
