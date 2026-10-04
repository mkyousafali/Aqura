begin;

create or replace function public.aqura_current_user_id()
returns uuid
language sql
stable
set search_path to 'public'
as $function$
  select case
    when coalesce(auth.jwt() -> 'user_metadata' ->> 'aqura_user_id', '')
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then (auth.jwt() -> 'user_metadata' ->> 'aqura_user_id')::uuid
    else auth.uid()
  end
$function$;

comment on function public.aqura_current_user_id() is
  'Returns the Aqura public.users.id represented by the current Supabase Auth session.';

revoke all on function public.aqura_current_user_id() from public, anon;
grant execute on function public.aqura_current_user_id() to authenticated, service_role;

do $migration$
declare
  v_function record;
  v_definition text;
begin
  for v_function in
    select p.oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = any (array[
         'Autotask_can_read_evidence',
         'Autotask_can_upload_evidence',
         'Autotask_set_pr_excel_verified',
         'check_helper_apps_permission',
         'create_action_followup_other',
         'create_action_followup_po',
         'create_email_account',
         'create_email_campaign',
         'create_email_group',
         'create_email_signature',
         'create_email_template',
         'create_hr_salary_note',
         'create_salary_statement',
         'delete_email_account',
         'delete_email_signature',
         'delete_email_template',
         'is_current_user_admin',
         'queue_email_send',
         'reopen_incident_cascade',
         'save_action_followup_approver',
         'save_email_draft',
         'save_internal_expense_approver',
         'set_biometric_edge_sync_enabled',
         'store_email_credentials',
         'update_email_account',
         'update_email_setting',
         'update_email_signature',
         'update_email_template',
         'upsert_app_icon'
       ])
       and pg_get_functiondef(p.oid) like '%auth.uid()%'
  loop
    v_definition := replace(
      pg_get_functiondef(v_function.oid),
      'auth.uid()',
      'public.aqura_current_user_id()'
    );
    execute v_definition;
  end loop;
end
$migration$;

commit;
