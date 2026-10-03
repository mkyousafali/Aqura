begin;

-- Extend verified user creation so the selected attendance employee is also
-- represented in hr_employee_master in the same transaction.
create or replace function public.create_verified_user(
  p_verification_id uuid,
  p_username varchar,
  p_password varchar,
  p_is_master_admin boolean default false,
  p_is_admin boolean default false,
  p_user_type varchar default 'branch_specific',
  p_branch_id bigint default null,
  p_position_id uuid default null,
  p_quick_access_code varchar default null,
  p_avatar text default null,
  p_requesting_user_id uuid default null,
  p_name_en varchar default null,
  p_name_ar varchar default null,
  p_erp_branch_id integer default null,
  p_erp_user_id text default null,
  p_erp_username text default null,
  p_erp_login_password text default null,
  p_erp_authorization_password text default null,
  p_erp_bulk_rotation_enabled boolean default false
) returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_verification public.user_creation_verifications%rowtype;
  v_attendance_employee public.hr_employees%rowtype;
  v_result json;
  v_user_id uuid;
  v_master_id text;
  v_expected_erp_branch_id integer;
begin
  if length(trim(coalesce(p_name_en, ''))) = 0 then
    return json_build_object('success', false, 'message', 'English employee name is required');
  end if;
  if length(trim(coalesce(p_name_ar, ''))) = 0 then
    return json_build_object('success', false, 'message', 'Arabic employee name is required');
  end if;

  select * into v_verification
  from public.user_creation_verifications
  where id = p_verification_id;

  if v_verification.id is null then
    return json_build_object('success', false, 'message', 'Verification session not found');
  end if;

  select * into v_attendance_employee
  from public.hr_employees
  where id = v_verification.employee_id;

  if v_attendance_employee.id is null then
    return json_build_object('success', false, 'message', 'Attendance employee not found');
  end if;

  if exists (
    select 1
    from public.hr_employee_master m
    where m.employee_id_mapping ->> v_attendance_employee.branch_id::text = v_attendance_employee.employee_id
  ) then
    return json_build_object('success', false, 'message', 'Attendance employee is already linked in HR Employee Master');
  end if;

  if p_erp_user_id is not null then
    if length(trim(coalesce(p_erp_username, ''))) = 0
       or length(coalesce(p_erp_login_password, '')) = 0
       or length(coalesce(p_erp_authorization_password, '')) = 0 then
      return json_build_object('success', false, 'message', 'Complete ERP login and authorization credentials are required');
    end if;

    select erp_branch_id into v_expected_erp_branch_id
    from public.erp_connections
    where branch_id = v_attendance_employee.branch_id and is_active = true
    limit 1;

    if v_expected_erp_branch_id is null or p_erp_branch_id is distinct from v_expected_erp_branch_id then
      return json_build_object('success', false, 'message', 'ERP branch does not match the selected employee branch');
    end if;
  end if;

  -- Call the existing verified-user implementation explicitly. Any failure in
  -- the HR insert below rolls this work back because both run in one function call.
  v_result := public.create_verified_user(
    p_verification_id,
    p_username,
    p_password,
    p_is_master_admin,
    p_is_admin,
    p_user_type,
    p_branch_id,
    p_position_id,
    p_quick_access_code,
    p_avatar,
    p_requesting_user_id
  );

  if not coalesce((v_result ->> 'success')::boolean, false) then
    return v_result;
  end if;

  v_user_id := (v_result ->> 'user_id')::uuid;

  -- Serialize EMP-number allocation so simultaneous user creation cannot
  -- generate the same hr_employee_master primary key.
  perform pg_advisory_xact_lock(hashtext('hr_employee_master_id_sequence'));
  select 'EMP' || (coalesce(max(substring(id from 4)::integer), 0) + 1)::text
  into v_master_id
  from public.hr_employee_master
  where id ~ '^EMP[0-9]+$';

  insert into public.hr_employee_master (
    id,
    user_id,
    current_branch_id,
    current_position_id,
    name_en,
    name_ar,
    employee_id_mapping,
    email,
    whatsapp_number
  ) values (
    v_master_id,
    v_user_id,
    v_attendance_employee.branch_id::integer,
    p_position_id,
    trim(p_name_en),
    trim(p_name_ar),
    jsonb_build_object(v_attendance_employee.branch_id::text, v_attendance_employee.employee_id),
    v_verification.email,
    v_verification.whatsapp_number
  );

  if p_erp_user_id is not null then
    insert into public.user_erp_credentials (
      user_id,
      aqura_branch_id,
      erp_branch_id,
      erp_user_id,
      erp_username,
      erp_login_password,
      erp_password,
      bulk_rotation_enabled
    ) values (
      v_user_id,
      v_attendance_employee.branch_id,
      p_erp_branch_id,
      trim(p_erp_user_id),
      trim(p_erp_username),
      p_erp_login_password,
      p_erp_authorization_password,
      coalesce(p_erp_bulk_rotation_enabled, false)
    );
  end if;

  return (v_result::jsonb || jsonb_build_object(
    'hr_employee_master_id', v_master_id,
    'erp_credentials_linked', p_erp_user_id is not null
  ))::json;
exception when others then
  return json_build_object('success', false, 'message', sqlerrm);
end;
$$;

revoke all on function public.create_verified_user(uuid, varchar, varchar, boolean, boolean, varchar, bigint, uuid, varchar, text, uuid, varchar, varchar, integer, text, text, text, text, boolean)
  from public, anon, authenticated;
grant execute on function public.create_verified_user(uuid, varchar, varchar, boolean, boolean, varchar, bigint, uuid, varchar, text, uuid, varchar, varchar, integer, text, text, text, text, boolean)
  to service_role;

commit;
