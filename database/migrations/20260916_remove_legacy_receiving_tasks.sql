begin;

-- Retire only the superseded Receiving Tasks subsystem. The operational
-- receiving, payment-schedule, regular-task, quick-task, and Autotask data are
-- deliberately outside the delete/drop targets in this migration.
do $$
begin
  if to_regclass('public.receiving_records') is null
     or to_regclass('public.pending_receiving_records') is null
     or to_regclass('public.vendor_payment_schedule') is null
     or to_regclass('public."Autotask_tasks"') is null then
    raise exception 'Protected receiving/payment/Autotask tables are missing; aborting legacy cleanup';
  end if;
end $$;

create temporary table legacy_receiving_cleanup_guard as
select
  (select count(*) from public.receiving_records) receiving_records_count,
  (select count(*) from public.pending_receiving_records) pending_receiving_records_count,
  (select count(*) from public.vendor_payment_schedule) vendor_payment_schedule_count,
  (select count(*) from public."Autotask_tasks") autotask_tasks_count;

-- Remove only notifications whose metadata points to a legacy receiving task.
delete from public.notifications n
where n.metadata->>'task_id' in (select id::text from public.receiving_tasks)
   or n.metadata->>'receiving_task_id' in (select id::text from public.receiving_tasks);

-- Remove the RPC surface that could create, reassign, complete, or report the
-- retired tasks. Drop by regprocedure so every deployed overload is covered.
do $$
declare v record;
begin
  for v in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prokind='f' and p.proname = any(array[
      'check_receiving_task_dependencies','complete_receiving_task',
      'complete_receiving_task_fixed','complete_receiving_task_simple',
      'count_completed_receiving_tasks','count_finished_receiving_tasks',
      'count_incomplete_receiving_tasks','count_incomplete_receiving_tasks_detailed',
      'debug_get_dependency_photos','debug_receiving_tasks_data',
      'get_all_receiving_tasks','get_completed_receiving_tasks',
      'get_dependency_completion_photos','get_incomplete_receiving_tasks',
      'get_incomplete_receiving_tasks_breakdown','get_receiving_task_statistics',
      'get_receiving_tasks_for_user','get_tasks_for_pending_receiving_record',
      'get_tasks_for_receiving_record','get_user_receiving_tasks_dashboard',
      'process_clearance_certificate_generation',
      'process_pending_clearance_certificate_generation','reassign_receiving_task',
      'sync_all_missing_erp_references','sync_all_pending_erp_references',
      'sync_erp_references_from_task_completions',
      'update_receiving_task_completion',
      'validate_task_completion_requirements'
    ])
  loop
    execute format('drop function if exists %s',v.signature);
  end loop;
end $$;

drop table public.receiving_tasks;
drop table public.receiving_task_templates;

-- Compatibility views intentionally contain no rows and are read-only. They
-- keep older shared reporting RPCs from failing while all active UI/API paths
-- use regular tasks, quick tasks, and Autotask RPCs. The legacy tables and data
-- are gone; writes through these views are not possible.
create view public.receiving_tasks as
select
  null::uuid id,null::uuid receiving_record_id,null::varchar role_type,
  null::uuid assigned_user_id,null::boolean requires_erp_reference,
  null::boolean requires_original_bill_upload,null::boolean requires_reassignment,
  null::boolean requires_task_finished_mark,null::varchar erp_reference_number,
  null::boolean original_bill_uploaded,null::text original_bill_file_path,
  null::boolean task_completed,null::timestamptz completed_at,
  null::text clearance_certificate_url,null::timestamptz created_at,
  null::timestamptz updated_at,null::uuid template_id,null::varchar task_status,
  null::text title,null::text description,null::varchar priority,
  null::timestamptz due_date,null::uuid completed_by_user_id,
  null::text completion_photo_url,null::text completion_notes,
  null::timestamptz rule_effective_date
where false;

create view public.receiving_task_templates as
select
  null::uuid id,null::varchar role_type,null::text title_template,
  null::text description_template,null::boolean require_erp_reference,
  null::boolean require_original_bill_upload,null::boolean require_task_finished_mark,
  null::varchar priority,null::integer deadline_hours,null::timestamptz created_at,
  null::timestamptz updated_at,null::text[] depends_on_role_types,
  null::boolean require_photo_upload
where false;

revoke insert,update,delete,truncate,references,trigger
  on public.receiving_tasks,public.receiving_task_templates from public,anon,authenticated;
grant select on public.receiving_tasks,public.receiving_task_templates to anon,authenticated;

-- ERP information now lives on the receiving record itself.
create or replace function public.check_erp_sync_status_for_record(receiving_record_id_param uuid)
returns jsonb language sql stable as $$
  select case when rr.id is null then
    jsonb_build_object('success',false,'error','Receiving record not found')
  else jsonb_build_object(
    'success',true,'receiving_record_id',rr.id,
    'current_erp_reference',rr.erp_purchase_invoice_reference,
    'task_erp_reference',null,'task_erp_completed',null,
    'task_completed_at',null,'task_completed_by',null,
    'receiving_task_completed',null,
    'sync_status',case when nullif(trim(rr.erp_purchase_invoice_reference),'') is null then 'NO_ERP_REFERENCE' else 'RECORD_WITH_ERP' end,
    'sync_needed',false,
    'can_sync',nullif(trim(rr.erp_purchase_invoice_reference),'') is not null,
    'has_tasks',false)
  end
  from (select 1) x left join public.receiving_records rr on rr.id=receiving_record_id_param;
$$;

create or replace function public.sync_erp_reference_for_receiving_record(receiving_record_id_param uuid)
returns jsonb language sql stable as $$
  select case when rr.id is null then
    jsonb_build_object('success',false,'error','Receiving record not found')
  when nullif(trim(rr.erp_purchase_invoice_reference),'') is null then
    jsonb_build_object('success',true,'synced',false,'updated_count',0,'message','No ERP reference is stored on the receiving record')
  else jsonb_build_object('success',true,'synced',false,'updated_count',0,
    'erp_reference',rr.erp_purchase_invoice_reference,'message','ERP reference already exists on the receiving record') end
  from (select 1) x left join public.receiving_records rr on rr.id=receiving_record_id_param;
$$;

grant execute on function public.check_erp_sync_status_for_record(uuid) to anon,authenticated;
grant execute on function public.sync_erp_reference_for_receiving_record(uuid) to anon,authenticated;

do $$
declare g record;
begin
  select * into g from legacy_receiving_cleanup_guard;
  if g.receiving_records_count<>(select count(*) from public.receiving_records)
     or g.pending_receiving_records_count<>(select count(*) from public.pending_receiving_records)
     or g.vendor_payment_schedule_count<>(select count(*) from public.vendor_payment_schedule)
     or g.autotask_tasks_count<>(select count(*) from public."Autotask_tasks") then
    raise exception 'Protected operational data changed; rolling back legacy cleanup';
  end if;
end $$;

commit;
