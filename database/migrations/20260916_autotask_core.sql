begin;

create extension if not exists pgcrypto;

create table if not exists public."Autotask_rules" (
  id uuid primary key default gen_random_uuid(),
  rule_code text not null unique,
  task_number integer not null unique check (task_number between 1 and 10),
  title_en text not null,
  title_ar text not null,
  trigger_event_type text not null default 'receiving.clearance_certificate_generated',
  assignment_mode text not null check (assignment_mode in ('source_selected_users','branch_default_users')),
  completion_mode text not null check (completion_mode in ('manual','automatic','hybrid')),
  timeline_minutes integer not null check (timeline_minutes > 0),
  dependency_policy jsonb not null default '[]'::jsonb,
  closing_policy jsonb not null default '{}'::jsonb,
  evidence_policy jsonb not null default '{}'::jsonb,
  notification_title_en text not null,
  notification_title_ar text not null,
  notification_body_en text not null,
  notification_body_ar text not null,
  configuration_version integer not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public."Autotask_branch_config" (
  id uuid primary key default gen_random_uuid(),
  branch_id text not null,
  rule_id uuid not null references public."Autotask_rules"(id) on delete cascade,
  default_user_ids uuid[] not null default '{}',
  is_enabled boolean not null default true,
  timeline_minutes_override integer check (timeline_minutes_override is null or timeline_minutes_override > 0),
  row_version integer not null default 1,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, rule_id)
);

create table if not exists public."Autotask_events" (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  source_module text not null,
  source_table text not null check (source_table in ('receiving_records','pending_receiving_records')),
  source_record_id text not null,
  branch_id text,
  idempotency_key text not null unique,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','processing','processed','failed','dead_letter')),
  attempt_count integer not null default 0,
  error_message text,
  processed_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public."Autotask_tasks" (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public."Autotask_events"(id) on delete cascade,
  rule_id uuid not null references public."Autotask_rules"(id),
  rule_code text not null,
  task_number integer not null,
  task_group_key text not null,
  assignee_user_id uuid not null,
  assignment_source text not null,
  branch_id text not null,
  source_module text not null,
  source_table text not null check (source_table in ('receiving_records','pending_receiving_records')),
  source_record_id text not null,
  source_refs jsonb not null default '{}'::jsonb,
  title_en text not null,
  title_ar text not null,
  status text not null default 'open' check (status in ('open','blocked','completed','cancelled')),
  status_reason_code text,
  outcome_code text,
  completion_mode text not null,
  triggered_at timestamptz not null default now(),
  available_at timestamptz not null default now(),
  due_at timestamptz not null,
  started_at timestamptz,
  completed_at timestamptz,
  completed_by_user_id uuid,
  timeline_minutes integer not null,
  dependency_snapshot jsonb not null default '[]'::jsonb,
  closing_snapshot jsonb not null default '{}'::jsonb,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  notification_title_en text not null,
  notification_title_ar text not null,
  notification_body_en text not null,
  notification_body_ar text not null,
  completion_data jsonb not null default '{}'::jsonb,
  row_version integer not null default 1,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists autotask_tasks_assignee_status_idx on public."Autotask_tasks" (assignee_user_id, status, due_at);
create index if not exists autotask_tasks_source_idx on public."Autotask_tasks" (source_table, source_record_id, task_number);

create table if not exists public."Autotask_dependencies" (
  id uuid primary key default gen_random_uuid(),
  dependent_task_id uuid not null references public."Autotask_tasks"(id) on delete cascade,
  prerequisite_task_id uuid not null references public."Autotask_tasks"(id) on delete cascade,
  dependency_type text not null default 'all_completed' check (dependency_type = 'all_completed'),
  created_at timestamptz not null default now(),
  unique (dependent_task_id, prerequisite_task_id),
  check (dependent_task_id <> prerequisite_task_id)
);

create table if not exists public."Autotask_activity" (
  id bigint generated always as identity primary key,
  task_id uuid references public."Autotask_tasks"(id) on delete cascade,
  event_id uuid references public."Autotask_events"(id) on delete cascade,
  activity_type text not null,
  actor_type text not null default 'system' check (actor_type in ('user','system','admin')),
  actor_user_id uuid,
  old_status text,
  new_status text,
  reason_code text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public."Autotask_evidence" (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public."Autotask_tasks"(id) on delete cascade,
  evidence_type text not null default 'photo',
  storage_bucket text,
  storage_path text,
  mime_type text,
  size_bytes bigint,
  file_hash text,
  source_table text,
  source_record_id text,
  source_field text,
  is_required boolean not null default false,
  is_finalized boolean not null default false,
  uploaded_by uuid not null,
  uploaded_at timestamptz not null default now(),
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.receiving_records
  add column if not exists autotask_pr_excel_verified boolean not null default false,
  add column if not exists autotask_advance_approval_status text,
  add column if not exists autotask_advance_approval_approver_ids uuid[] not null default '{}',
  add column if not exists autotask_advance_approval_requested_by uuid,
  add column if not exists autotask_advance_approval_requested_at timestamptz,
  add column if not exists autotask_advance_approval_decided_by uuid,
  add column if not exists autotask_advance_approval_decided_at timestamptz,
  add column if not exists autotask_advance_approval_notes text;

alter table if exists public.pending_receiving_records
  add column if not exists autotask_pr_excel_verified boolean not null default false,
  add column if not exists autotask_advance_approval_status text,
  add column if not exists autotask_advance_approval_approver_ids uuid[] not null default '{}',
  add column if not exists autotask_advance_approval_requested_by uuid,
  add column if not exists autotask_advance_approval_requested_at timestamptz,
  add column if not exists autotask_advance_approval_decided_by uuid,
  add column if not exists autotask_advance_approval_decided_at timestamptz,
  add column if not exists autotask_advance_approval_notes text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'receiving_autotask_approval_status_check') then
    alter table public.receiving_records add constraint receiving_autotask_approval_status_check
      check (autotask_advance_approval_status is null or autotask_advance_approval_status in ('pending','sent_for_approval','approved','rejected'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'pending_receiving_autotask_approval_status_check') then
    alter table public.pending_receiving_records add constraint pending_receiving_autotask_approval_status_check
      check (autotask_advance_approval_status is null or autotask_advance_approval_status in ('pending','sent_for_approval','approved','rejected'));
  end if;
end $$;

insert into public."Autotask_rules" (
  rule_code, task_number, title_en, title_ar, assignment_mode, completion_mode,
  timeline_minutes, dependency_policy, closing_policy, evidence_policy,
  notification_title_en, notification_title_ar, notification_body_en, notification_body_ar
) values
('receiving.place_products_on_shelf',1,'Placing products on shelf','وضع المنتجات على الرف','source_selected_users','hybrid',1440,'[]','{"type":"manual"}','{"min_photos":1}','Receiving task assigned','تم تعيين مهمة استلام','Products from {{vendor_name}} were received on {{receiving_date}}. Place them on shelves, upload at least one photo, then complete the task.','تم استلام منتجات {{vendor_name}} بتاريخ {{receiving_date}}. ضعها على الرفوف وارفع صورة واحدة على الأقل ثم أكمل المهمة.'),
('receiving.follow_up_placing',2,'Follow Up Placing','متابعة وضع المنتجات','branch_default_users','manual',1440,'[{"task_number":1}]','{"type":"manual"}','{}','Receiving follow-up assigned','تم تعيين متابعة الاستلام','Confirm placement for products from {{vendor_name}} after all shelf-placement tasks are complete.','تحقق من وضع منتجات {{vendor_name}} بعد اكتمال جميع مهام وضع المنتجات على الرفوف.'),
('receiving.warehouse_placing_confirmation',3,'Warehouse Placing Confirmation','تأكيد وضع المنتجات في المستودع','branch_default_users','hybrid',1440,'[{"task_number":1}]','{"type":"warehouse_balance_choice"}','{"min_photos_when_balance":1}','Warehouse confirmation assigned','تم تعيين تأكيد المستودع','Confirm whether warehouse stock remains for {{vendor_name}}. A photo is required when balance remains.','أكد ما إذا كان يوجد رصيد متبقٍ في المستودع لمنتجات {{vendor_name}}. الصورة مطلوبة عند وجود رصيد.'),
('receiving.original_bill_ai_check',4,'Original Bill AI Check','فحص الفاتورة الأصلية بالذكاء الاصطناعي','branch_default_users','automatic',1440,'[]','{"source":"original_bill_check_result.status","equals":"matched"}','{}','Original bill check assigned','تم تعيين فحص الفاتورة الأصلية','Upload and match the original bill for {{vendor_name}}.','ارفع الفاتورة الأصلية وتحقق من مطابقتها للمورد {{vendor_name}}.'),
('receiving.pr_excel_upload',5,'PR Excel Upload','رفع ملف PR Excel','branch_default_users','automatic',1440,'[]','{"source":"pr_excel_file_url","not_empty":true}','{}','PR Excel upload assigned','تم تعيين رفع ملف PR Excel','Upload the PR Excel file for {{vendor_name}}.','ارفع ملف PR Excel الخاص بالمورد {{vendor_name}}.'),
('receiving.pricing_cost_verification',6,'Pricing/Cost Verification','التحقق من الأسعار والتكلفة','branch_default_users','automatic',2880,'[]','{"source":"autotask_pr_excel_verified","equals":true}','{}','Pricing verification assigned','تم تعيين التحقق من الأسعار','Verify the PR Excel pricing and cost for {{vendor_name}}.','تحقق من أسعار وتكلفة ملف PR Excel للمورد {{vendor_name}}.'),
('receiving.enter_erp_purchase_invoice_reference',7,'Enter ERP Purchase Invoice Reference','إدخال مرجع فاتورة المشتريات في ERP','branch_default_users','automatic',1440,'[]','{"source":"erp_purchase_invoice_reference","not_empty":true}','{}','ERP reference assigned','تم تعيين إدخال مرجع ERP','Enter the ERP purchase invoice reference for {{vendor_name}}.','أدخل مرجع فاتورة المشتريات في ERP للمورد {{vendor_name}}.'),
('receiving.erp_purchase_invoice_check',8,'ERP Purchase Invoice Check','فحص فاتورة المشتريات في ERP','branch_default_users','automatic',1440,'[]','{"source":"erp_check_result.status","equals":"matched"}','{}','ERP check assigned','تم تعيين فحص ERP','Match the ERP purchase invoice for {{vendor_name}}.','تحقق من مطابقة فاتورة المشتريات في ERP للمورد {{vendor_name}}.'),
('receiving.get_advance_payment_approval',9,'Get Advance Payment Approval','الحصول على موافقة الدفعة المقدمة','branch_default_users','automatic',2880,'[]','{"source":"autotask_advance_approval_status","in":["approved","rejected"]}','{}','Advance approval requested','تم طلب موافقة الدفعة المقدمة','Review the advance-payment approval request for {{vendor_name}}.','راجع طلب موافقة الدفعة المقدمة للمورد {{vendor_name}}.'),
('receiving.final_verification',10,'Final Receiving Verification','التحقق النهائي من الاستلام','branch_default_users','automatic',2880,'[{"task_numbers":[1,2,3,4,5,6,7,8,9]}]','{"type":"all_dependencies_completed"}','{}','Final receiving verification','التحقق النهائي من الاستلام','Final verification closes automatically after all receiving tasks for {{vendor_name}} are complete.','يُغلق التحقق النهائي تلقائيًا بعد اكتمال جميع مهام استلام {{vendor_name}}.')
on conflict (rule_code) do update set
  title_en=excluded.title_en, title_ar=excluded.title_ar,
  completion_mode=excluded.completion_mode, timeline_minutes=excluded.timeline_minutes,
  dependency_policy=excluded.dependency_policy, closing_policy=excluded.closing_policy,
  evidence_policy=excluded.evidence_policy, notification_title_en=excluded.notification_title_en,
  notification_title_ar=excluded.notification_title_ar, notification_body_en=excluded.notification_body_en,
  notification_body_ar=excluded.notification_body_ar, updated_at=now();

create or replace function public."Autotask_list_rules"()
returns setof public."Autotask_rules"
language sql security definer set search_path=public
as $$ select * from public."Autotask_rules" order by task_number $$;

create or replace function public."Autotask_get_branch_config"(p_branch_id text)
returns table(rule_id uuid, rule_code text, task_number integer, title_en text, title_ar text, default_user_ids uuid[], is_enabled boolean, timeline_minutes integer, row_version integer)
language sql security definer set search_path=public
as $$
  select r.id, r.rule_code, r.task_number, r.title_en, r.title_ar,
         coalesce(c.default_user_ids,'{}'::uuid[]), coalesce(c.is_enabled,true),
         coalesce(c.timeline_minutes_override,r.timeline_minutes), coalesce(c.row_version,0)
  from public."Autotask_rules" r
  left join public."Autotask_branch_config" c on c.rule_id=r.id and c.branch_id=p_branch_id
  order by r.task_number;
$$;

drop function if exists public."Autotask_save_branch_config"(text,uuid,uuid[],boolean,integer);

create or replace function public."Autotask_save_branch_config"(p_requesting_user_id uuid, p_branch_id text, p_rule_id uuid, p_user_ids uuid[], p_is_enabled boolean default true, p_expected_version integer default null)
returns public."Autotask_branch_config"
language plpgsql security definer set search_path=public
as $$
declare v_result public."Autotask_branch_config"; v_invalid integer;
begin
  if not exists(select 1 from public.users u where u.id=p_requesting_user_id and u.status='active' and (coalesce(u.is_master_admin,false) or exists(select 1 from public.button_permissions bp where bp.user_id=u.id and bp.button_code in ('DEFAULT_POSITIONS','APP_PERMISSIONS') and bp.is_enabled=true))) then raise exception 'Not authorized to manage Auto Tasks'; end if;
  if not exists(select 1 from public.branches b where b.id::text=p_branch_id and coalesce(b.is_active,true)) then raise exception 'Active branch not found'; end if;
  if exists(select 1 from public."Autotask_rules" where id=p_rule_id and assignment_mode='source_selected_users') then raise exception 'Task 1 uses receiving-selected users'; end if;
  select count(*) into v_invalid from unnest(coalesce(p_user_ids,'{}'::uuid[])) x where not exists(select 1 from public.users u where u.id=x and u.status='active');
  if v_invalid>0 then raise exception 'One or more users are invalid'; end if;
  if p_expected_version is not null and exists(select 1 from public."Autotask_branch_config" where branch_id=p_branch_id and rule_id=p_rule_id and row_version<>p_expected_version) then raise exception 'Configuration was changed by another user'; end if;
  insert into public."Autotask_branch_config"(branch_id,rule_id,default_user_ids,is_enabled,created_by,updated_by)
  values(p_branch_id,p_rule_id,(select coalesce(array_agg(distinct x),'{}'::uuid[]) from unnest(coalesce(p_user_ids,'{}'::uuid[])) x),p_is_enabled,p_requesting_user_id,p_requesting_user_id)
  on conflict(branch_id,rule_id) do update set default_user_ids=excluded.default_user_ids,is_enabled=excluded.is_enabled,row_version=public."Autotask_branch_config".row_version+1,updated_by=p_requesting_user_id,updated_at=now()
  returning * into v_result;
  insert into public."Autotask_activity"(activity_type,actor_type,actor_user_id,details) values('configuration_changed','admin',p_requesting_user_id,jsonb_build_object('branch_id',p_branch_id,'rule_id',p_rule_id,'user_ids',p_user_ids));
  return v_result;
end $$;

create or replace function public."Autotask_refresh_source"(p_source_table text,p_source_record_id text)
returns integer language plpgsql security definer set search_path=public
as $$
declare v_row jsonb; v_posted_row jsonb; v_task record; v_match boolean; v_closed integer:=0;
begin
  if p_source_table not in ('receiving_records','pending_receiving_records') then raise exception 'Unsupported source table'; end if;
  execute format('select to_jsonb(r) from public.%I r where r.id::text=$1',p_source_table) into v_row using p_source_record_id;
  if v_row is null then return 0; end if;
  if p_source_table='pending_receiving_records' and nullif(v_row->>'posted_receiving_record_id','') is not null then
    select to_jsonb(r) into v_posted_row from public.receiving_records r where r.id::text=v_row->>'posted_receiving_record_id';
    if v_posted_row is not null then v_row:=v_row||v_posted_row; end if;
  end if;
  for v_task in select * from public."Autotask_tasks" where source_table=p_source_table and source_record_id=p_source_record_id and status in ('open','blocked') loop
    v_match:=false;
    case v_task.task_number
      when 4 then v_match:=lower(coalesce(v_row#>>'{original_bill_check_result,status}',''))='matched' and nullif(v_row->>'original_bill_url','') is not null;
      when 5 then v_match:=nullif(btrim(coalesce(v_row->>'pr_excel_file_url','')),'') is not null;
      when 6 then v_match:=coalesce((v_row->>'autotask_pr_excel_verified')::boolean,false);
      when 7 then v_match:=nullif(btrim(coalesce(v_row->>'erp_purchase_invoice_reference','')),'') is not null;
      when 8 then v_match:=lower(coalesce(v_row#>>'{erp_check_result,status}',''))='matched';
      when 9 then v_match:=coalesce(v_row->>'autotask_advance_approval_status','') in ('approved','rejected');
      when 10 then v_match:=not exists(select 1 from public."Autotask_dependencies" d join public."Autotask_tasks" p on p.id=d.prerequisite_task_id where d.dependent_task_id=v_task.id and p.status<>'completed');
      else v_match:=false;
    end case;
    if v_match and v_task.task_number between 4 and 10 then
      update public."Autotask_tasks" set status='completed',status_reason_code='source_condition_met',outcome_code=case when v_task.task_number=9 then v_row->>'autotask_advance_approval_status' else 'completed' end,completed_at=now(),completed_by_user_id=null,row_version=row_version+1,updated_at=now() where id=v_task.id and status<>'completed';
      if found then v_closed:=v_closed+1; insert into public."Autotask_activity"(task_id,event_id,activity_type,old_status,new_status,reason_code,details) values(v_task.id,v_task.event_id,'auto_completion','open','completed','source_condition_met',jsonb_build_object('task_number',v_task.task_number)); end if;
    end if;
  end loop;
  if v_closed>0 then perform public."Autotask_refresh_source"(p_source_table,p_source_record_id) where exists(select 1 from public."Autotask_tasks" where source_table=p_source_table and source_record_id=p_source_record_id and task_number=10 and status<>'completed'); end if;
  return v_closed;
end $$;

create or replace function public."Autotask_publish_event_notifications"(p_event_id uuid,p_approval_user_ids uuid[] default '{}')
returns integer language plpgsql security definer set search_path=public
as $$
declare v_task record; v_notification_id uuid; v_count integer:=0; v_title_en text; v_title_ar text; v_body_en text; v_body_ar text; v_details_en text; v_details_ar text;
begin
  for v_task in select * from public."Autotask_tasks" where event_id=p_event_id loop
    v_title_en:=v_task.notification_title_en;
    v_title_ar:=v_task.notification_title_ar;
    v_body_en:=replace(replace(v_task.notification_body_en,'{{vendor_name}}',coalesce(v_task.source_refs->>'vendor_name','')),'{{receiving_date}}',coalesce(v_task.source_refs->>'receiving_date',''));
    v_body_ar:=replace(replace(v_task.notification_body_ar,'{{vendor_name}}',coalesce(v_task.source_refs->>'vendor_name','')),'{{receiving_date}}',coalesce(v_task.source_refs->>'receiving_date',''));
    v_details_en:=E'\n\nTask: '||coalesce(v_task.title_en,'')||E'\nVendor: '||coalesce(v_task.source_refs->>'vendor_name','')||E'\nBill number: '||coalesce(v_task.source_refs->>'bill_number','')||E'\nReceiving date: '||coalesce(v_task.source_refs->>'receiving_date','')||E'\nReceived by: '||coalesce(v_task.source_refs->>'received_by','');
    v_details_ar:=E'\n\nالمهمة: '||coalesce(v_task.title_ar,'')||E'\nالمورد: '||coalesce(v_task.source_refs->>'vendor_name','')||E'\nرقم الفاتورة: '||coalesce(v_task.source_refs->>'bill_number','')||E'\nتاريخ الاستلام: '||coalesce(v_task.source_refs->>'receiving_date','')||E'\nتم الاستلام بواسطة: '||coalesce(v_task.source_refs->>'received_by','');
    v_body_en:=v_body_en||v_details_en;
    v_body_ar:=v_body_ar||v_details_ar;
    insert into public.notifications(title,message,title_en,title_ar,message_en,message_ar,type,priority,target_type,target_users,created_by,created_by_name,created_by_role,status,total_recipients,metadata)
    values(v_title_en||' / '||v_title_ar,v_body_en||E'\n---\n'||v_body_ar,v_title_en,v_title_ar,v_body_en,v_body_ar,'task_assigned','medium','specific_users',to_jsonb(array[v_task.assignee_user_id]),'Auto Task System','Auto Task System','System','published',1,jsonb_build_object('autotask_id',v_task.id,'autotask_event_id',p_event_id,'source_table',v_task.source_table,'source_record_id',v_task.source_record_id))
    returning id into v_notification_id;
    v_count:=v_count+1;
  end loop;
  if cardinality(coalesce(p_approval_user_ids,'{}'::uuid[]))>0 then
    insert into public.notifications(title,message,title_en,title_ar,message_en,message_ar,type,priority,target_type,target_users,created_by,created_by_name,created_by_role,status,total_recipients,metadata)
    values('Advance Payment Approval / موافقة الدفعة المقدمة','An advance-payment approval decision is required. / مطلوب قرار بشأن موافقة الدفعة المقدمة.','Advance Payment Approval','موافقة الدفعة المقدمة','An advance-payment approval decision is required.','مطلوب قرار بشأن موافقة الدفعة المقدمة.','approval_request','high','specific_users',to_jsonb(p_approval_user_ids),'Auto Task System','Auto Task System','System','published',cardinality(p_approval_user_ids),jsonb_build_object('autotask_event_id',p_event_id,'approval_type','receiving_advance_payment'))
    returning id into v_notification_id;
    v_count:=v_count+1;
  end if;
  return v_count;
end $$;

create or replace function public."Autotask_ingest_receiving_certificate"(p_source_table text,p_source_record_id text,p_certificate_url text,p_actor_user_id uuid default auth.uid())
returns jsonb language plpgsql security definer set search_path=public
as $$
declare v_row jsonb; v_event public."Autotask_events"; v_rule record; v_users uuid[]; v_user uuid; v_task_id uuid; v_created integer:=0; v_branch text; v_key text; v_amount numeric; v_approvers uuid[]; v_notifications integer:=0; v_vendor_name text; v_received_by text; v_receiving_date text; v_push_notifications jsonb:='[]'::jsonb;
begin
  if p_source_table not in ('receiving_records','pending_receiving_records') then raise exception 'Unsupported source table'; end if;
  execute format('select to_jsonb(r) from public.%I r where r.id::text=$1',p_source_table) into v_row using p_source_record_id;
  if v_row is null then raise exception 'Receiving record not found'; end if;
  select v.vendor_name into v_vendor_name from public.vendors v where v.erp_vendor_id=(v_row->>'vendor_id')::integer;
  select u.username into v_received_by from public.users u where u.id=(v_row->>'user_id')::uuid;
  v_receiving_date:=coalesce(v_row->>'bill_date',v_row->>'created_at');
  v_branch:=v_row->>'branch_id'; v_key:='receiving.clearance_certificate_generated:'||p_source_table||':'||p_source_record_id||':v1';
  insert into public."Autotask_events"(event_type,source_module,source_table,source_record_id,branch_id,idempotency_key,payload,status,created_by)
  values('receiving.clearance_certificate_generated','receiving',p_source_table,p_source_record_id,v_branch,v_key,jsonb_build_object('certificate_url',p_certificate_url),'processing',p_actor_user_id)
  on conflict(idempotency_key) do update set updated_at=now() returning * into v_event;
  if v_event.status='processed' then return jsonb_build_object('success',true,'duplicate',true,'tasks_created',0,'event_id',v_event.id); end if;
  for v_rule in select r.*,c.default_user_ids,c.is_enabled,coalesce(c.timeline_minutes_override,r.timeline_minutes) effective_timeline from public."Autotask_rules" r left join public."Autotask_branch_config" c on c.rule_id=r.id and c.branch_id=v_branch where r.is_active order by r.task_number loop
    if v_rule.task_number=1 then
      select coalesce(array_agg(x::uuid),'{}'::uuid[]) into v_users from jsonb_array_elements_text(coalesce(v_row->'shelf_stocker_user_ids','[]'::jsonb)) x;
    elsif coalesce(v_rule.is_enabled,true) then v_users:=coalesce(v_rule.default_user_ids,'{}'::uuid[]); else v_users:='{}'::uuid[]; end if;
    if coalesce(v_rule.is_enabled,true) and cardinality(v_users)=0 then raise exception 'No assignee configured for Auto Task % (%)',v_rule.task_number,v_rule.title_en; end if;
    foreach v_user in array v_users loop
      insert into public."Autotask_tasks"(event_id,rule_id,rule_code,task_number,task_group_key,assignee_user_id,assignment_source,branch_id,source_module,source_table,source_record_id,source_refs,title_en,title_ar,status,completion_mode,due_at,timeline_minutes,dependency_snapshot,closing_snapshot,evidence_snapshot,notification_title_en,notification_title_ar,notification_body_en,notification_body_ar,idempotency_key)
      values(v_event.id,v_rule.id,v_rule.rule_code,v_rule.task_number,v_key||':task:'||v_rule.task_number,v_user,case when v_rule.task_number=1 then 'source_selected_users' else 'branch_default_users' end,v_branch,'receiving',p_source_table,p_source_record_id,jsonb_build_object('certificate_url',p_certificate_url,'vendor_name',coalesce(v_vendor_name,'Unknown vendor'),'bill_number',coalesce(v_row->>'bill_number',''),'receiving_date',v_receiving_date,'received_by',coalesce(v_received_by,'Unknown user')),v_rule.title_en,v_rule.title_ar,case when v_rule.task_number in (2,3,10) then 'blocked' else 'open' end,v_rule.completion_mode,now()+make_interval(mins=>v_rule.effective_timeline),v_rule.effective_timeline,v_rule.dependency_policy,v_rule.closing_policy,v_rule.evidence_policy,v_rule.notification_title_en,v_rule.notification_title_ar,v_rule.notification_body_en,v_rule.notification_body_ar,v_key||':'||v_rule.task_number||':'||v_user)
      on conflict(idempotency_key) do nothing returning id into v_task_id;
      if v_task_id is not null then v_created:=v_created+1; insert into public."Autotask_activity"(task_id,event_id,activity_type,new_status,details) values(v_task_id,v_event.id,'task_created',case when v_rule.task_number in (2,3,10) then 'blocked' else 'open' end,jsonb_build_object('assignee_user_id',v_user)); end if;
      v_task_id:=null;
    end loop;
  end loop;
  insert into public."Autotask_dependencies"(dependent_task_id,prerequisite_task_id)
  select d.id,p.id from public."Autotask_tasks" d join public."Autotask_tasks" p on p.event_id=d.event_id where d.event_id=v_event.id and ((d.task_number in (2,3) and p.task_number=1) or (d.task_number=10 and p.task_number between 1 and 9)) on conflict do nothing;
  update public."Autotask_tasks" d set status='open' where d.event_id=v_event.id and d.status='blocked' and not exists(select 1 from public."Autotask_dependencies" x join public."Autotask_tasks" p on p.id=x.prerequisite_task_id where x.dependent_task_id=d.id and p.status<>'completed');
  v_amount:=coalesce(nullif(v_row->>'final_bill_amount','')::numeric,nullif(v_row->>'bill_amount','')::numeric,0);
  select coalesce(array_agg(ap.user_id),'{}'::uuid[]) into v_approvers from public.approval_permissions ap where ap.is_active=true and ap.can_approve_vendor_payments=true and (coalesce(ap.vendor_payment_amount_limit,0)=0 or ap.vendor_payment_amount_limit>=v_amount);
  if cardinality(v_approvers)=0 then select coalesce(array_agg(u.id),'{}'::uuid[]) into v_approvers from public.users u where coalesce(u.is_master_admin,false)=true and u.status='active'; end if;
  execute format('update public.%I set autotask_advance_approval_status=$1,autotask_advance_approval_approver_ids=$2,autotask_advance_approval_requested_by=$3,autotask_advance_approval_requested_at=now() where id::text=$4',p_source_table) using 'sent_for_approval',v_approvers,p_actor_user_id,p_source_record_id;
  v_notifications:=public."Autotask_publish_event_notifications"(v_event.id,v_approvers);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',n.id,'title',n.title,'message',n.message,'title_en',n.title_en,'title_ar',n.title_ar,
    'message_en',n.message_en,'message_ar',n.message_ar,'type',n.type
  ) order by n.created_at,n.id),'[]'::jsonb)
  into v_push_notifications
  from public.notifications n
  where n.metadata->>'autotask_id' in (select t.id::text from public."Autotask_tasks" t where t.event_id=v_event.id)
     or n.metadata->>'autotask_event_id'=v_event.id::text;
  update public."Autotask_events" set status='processed',processed_at=now(),updated_at=now() where id=v_event.id;
  perform public."Autotask_refresh_source"(p_source_table,p_source_record_id);
  return jsonb_build_object('success',true,'duplicate',false,'tasks_created',v_created,'notifications_sent',v_notifications,'event_id',v_event.id,'approval_approver_ids',v_approvers,'push_notifications',v_push_notifications);
exception when others then
  if v_event.id is not null then update public."Autotask_events" set status='failed',attempt_count=attempt_count+1,error_message=sqlerrm,updated_at=now() where id=v_event.id; end if;
  raise;
end $$;

drop function if exists public."Autotask_list_my_tasks"(boolean,integer);

create or replace function public."Autotask_list_my_tasks"(p_user_id uuid,p_include_completed boolean default false,p_limit integer default 100)
returns table(id uuid,rule_code text,task_number integer,title_en text,title_ar text,status text,is_overdue boolean,due_at timestamptz,source_table text,source_record_id text,branch_id text,source_refs jsonb,completion_data jsonb)
language sql security definer set search_path=public
as $$ select t.id,t.rule_code,t.task_number,t.title_en,t.title_ar,t.status,(t.status not in ('completed','cancelled') and t.due_at<now()),t.due_at,t.source_table,t.source_record_id,t.branch_id,t.source_refs,t.completion_data from public."Autotask_tasks" t where t.assignee_user_id=p_user_id and exists(select 1 from public.users u where u.id=p_user_id and u.status='active') and (p_include_completed or t.status not in ('completed','cancelled')) order by t.created_at desc limit least(greatest(p_limit,1),500) $$;

create or replace function public."Autotask_get_source_tasks"(p_source_table text,p_source_record_id text)
returns table(id uuid,title text,assigned_user_name text,role_type text,task_status text,due_date timestamptz,task_number integer)
language sql security definer set search_path=public
as $$
  select t.id,t.title_en,u.username,'auto_task',t.status,t.due_at,t.task_number
  from public."Autotask_tasks" t join public.users u on u.id=t.assignee_user_id
  where t.source_table=p_source_table and t.source_record_id=p_source_record_id
  order by t.task_number,u.username;
$$;

drop function if exists public."Autotask_complete_task"(uuid,jsonb);
create or replace function public."Autotask_complete_task"(p_actor_user_id uuid,p_task_id uuid,p_completion_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare v_task public."Autotask_tasks"; v_photos integer; v_has_balance boolean;
begin
  select * into v_task from public."Autotask_tasks" where id=p_task_id for update;
  if not found then raise exception 'Task not found'; end if;
  if not exists(select 1 from public.users u where u.id=p_actor_user_id and u.status='active') then raise exception 'Active Aqura user not found'; end if;
  if v_task.assignee_user_id<>p_actor_user_id then raise exception 'Task is not assigned to this user'; end if;
  if v_task.task_number not in (1,2,3) then raise exception 'This task closes automatically'; end if;
  if exists(select 1 from public."Autotask_dependencies" d join public."Autotask_tasks" p on p.id=d.prerequisite_task_id where d.dependent_task_id=v_task.id and p.status<>'completed') then raise exception 'Task dependencies are not complete'; end if;
  select count(*) into v_photos from public."Autotask_evidence" where task_id=p_task_id and evidence_type='photo' and is_finalized;
  if v_task.task_number=1 and v_photos<1 then raise exception 'At least one photo is required'; end if;
  if v_task.task_number=3 then v_has_balance:=coalesce((p_completion_data->>'has_warehouse_balance')::boolean,null); if v_has_balance is null then raise exception 'Warehouse balance choice is required'; end if; if v_has_balance and v_photos<1 then raise exception 'At least one photo is required when balance remains'; end if; end if;
  update public."Autotask_tasks" set status='completed',status_reason_code='user_completed',outcome_code='completed',completion_data=coalesce(p_completion_data,'{}'::jsonb),completed_at=now(),completed_by_user_id=p_actor_user_id,row_version=row_version+1,updated_at=now() where id=p_task_id;
  insert into public."Autotask_activity"(task_id,event_id,activity_type,actor_type,actor_user_id,old_status,new_status,details) values(v_task.id,v_task.event_id,'completion','user',p_actor_user_id,v_task.status,'completed',p_completion_data);
  update public."Autotask_tasks" d set status='open',updated_at=now() where d.event_id=v_task.event_id and d.status='blocked' and not exists(select 1 from public."Autotask_dependencies" x join public."Autotask_tasks" p on p.id=x.prerequisite_task_id where x.dependent_task_id=d.id and p.status<>'completed');
  perform public."Autotask_refresh_source"(v_task.source_table,v_task.source_record_id);
  return jsonb_build_object('success',true,'task_id',p_task_id);
end $$;

drop function if exists public."Autotask_register_evidence"(uuid,text,text,bigint);
create or replace function public."Autotask_register_evidence"(p_actor_user_id uuid,p_task_id uuid,p_storage_path text,p_mime_type text default null,p_size_bytes bigint default null)
returns uuid language plpgsql security definer set search_path=public
as $$ declare v_id uuid; begin
  if not exists(select 1 from public.users u where u.id=p_actor_user_id and u.status='active') then raise exception 'Active Aqura user not found'; end if;
  if not exists(select 1 from public."Autotask_tasks" where id=p_task_id and assignee_user_id=p_actor_user_id and status not in ('completed','cancelled')) then raise exception 'Task is not available'; end if;
  insert into public."Autotask_evidence"(task_id,evidence_type,storage_bucket,storage_path,mime_type,size_bytes,is_required,is_finalized,uploaded_by,finalized_at)
  values(p_task_id,'photo','Autotask_evidence',p_storage_path,p_mime_type,p_size_bytes,true,true,p_actor_user_id,now()) returning id into v_id;
  return v_id;
end $$;

drop function if exists public."Autotask_decide_advance_approval"(text,text,text,text);
create or replace function public."Autotask_decide_advance_approval"(p_actor_user_id uuid,p_source_table text,p_source_record_id text,p_decision text,p_notes text default null)
returns jsonb language plpgsql security definer set search_path=public
as $$ declare v_row jsonb; v_updated bigint; begin
  if not exists(select 1 from public.users where id=p_actor_user_id and status='active') then raise exception 'Active Aqura user not found'; end if;
  if p_source_table not in ('receiving_records','pending_receiving_records') or p_decision not in ('approved','rejected') then raise exception 'Invalid approval decision'; end if;
  execute format('select to_jsonb(r) from public.%I r where r.id::text=$1 for update',p_source_table) into v_row using p_source_record_id;
  if coalesce(v_row->>'autotask_advance_approval_status','')<>'sent_for_approval' then raise exception 'Approval already decided or unavailable'; end if;
  if nullif(btrim(coalesce(v_row->>'original_bill_url','')),'') is null then raise exception 'Original bill must be uploaded before this request can be decided'; end if;
  if not (p_actor_user_id=any(array(select jsonb_array_elements_text(coalesce(v_row->'autotask_advance_approval_approver_ids','[]'::jsonb))::uuid))) then raise exception 'User is not an eligible approver'; end if;
  execute format('update public.%I set autotask_advance_approval_status=$1,autotask_advance_approval_decided_by=$2,autotask_advance_approval_decided_at=now(),autotask_advance_approval_notes=$3 where id::text=$4 and autotask_advance_approval_status=$5',p_source_table) using p_decision,p_actor_user_id,p_notes,p_source_record_id,'sent_for_approval';
  get diagnostics v_updated = row_count;
  if v_updated=0 then raise exception 'Approval was already decided'; end if;
  perform public."Autotask_refresh_source"(p_source_table,p_source_record_id);
  return jsonb_build_object('success',true,'decision',p_decision);
end $$;

drop function if exists public."Autotask_list_my_advance_approvals"();
create or replace function public."Autotask_list_my_advance_approvals"(p_user_id uuid)
returns table(source_table text,source_record_id text,branch_id text,vendor_name text,bill_number text,amount numeric,requested_at timestamptz,status text,original_bill_url text)
language sql security definer set search_path=public
as $$
  select distinct q.source_table,q.source_record_id,q.branch_id,q.vendor_name,q.bill_number,q.amount,q.requested_at,q.status,q.original_bill_url
  from (
    select 'receiving_records'::text source_table,r.id::text source_record_id,r.branch_id::text branch_id,coalesce(v.vendor_name,'Unknown vendor') vendor_name,r.bill_number::text bill_number,coalesce(r.final_bill_amount,r.bill_amount,0)::numeric amount,r.autotask_advance_approval_requested_at requested_at,r.autotask_advance_approval_status status,r.original_bill_url::text original_bill_url
    from public.receiving_records r left join public.vendors v on v.erp_vendor_id=r.vendor_id
    where r.autotask_advance_approval_status='sent_for_approval' and p_user_id=any(r.autotask_advance_approval_approver_ids)
    union all
    select 'pending_receiving_records'::text,r.id::text,r.branch_id::text,coalesce(v.vendor_name,'Unknown vendor'),r.bill_number::text,coalesce(r.final_bill_amount,r.bill_amount,0)::numeric,r.autotask_advance_approval_requested_at,r.autotask_advance_approval_status,r.original_bill_url::text
    from public.pending_receiving_records r left join public.vendors v on v.erp_vendor_id=r.vendor_id
    where r.autotask_advance_approval_status='sent_for_approval' and p_user_id=any(r.autotask_advance_approval_approver_ids)
  ) q where exists(select 1 from public.users u where u.id=p_user_id and u.status='active') order by q.requested_at desc;
$$;

create or replace function public."Autotask_set_pr_excel_verified"(p_source_table text,p_source_record_id text,p_verified boolean)
returns jsonb language plpgsql security definer set search_path=public
as $$ begin
  if p_source_table not in ('receiving_records','pending_receiving_records') then raise exception 'Unsupported source table'; end if;
  execute format('update public.%I set autotask_pr_excel_verified=$1 where id::text=$2',p_source_table) using p_verified,p_source_record_id;
  if p_source_table='receiving_records' then update public.vendor_payment_schedule set pr_excel_verified=p_verified,pr_excel_verified_by=case when p_verified then auth.uid() else null end,pr_excel_verified_date=case when p_verified then now() else null end where receiving_record_id::text=p_source_record_id; end if;
  perform public."Autotask_refresh_source"(p_source_table,p_source_record_id);
  return jsonb_build_object('success',true,'verified',p_verified);
end $$;

create or replace function public.autotask_source_change_trigger()
returns trigger language plpgsql security definer set search_path=public
as $$
declare v_pending record;
begin
  perform public."Autotask_refresh_source"(tg_table_name,new.id::text);
  if tg_table_name='receiving_records' then
    for v_pending in select id from public.pending_receiving_records where posted_receiving_record_id=new.id loop
      perform public."Autotask_refresh_source"('pending_receiving_records',v_pending.id::text);
    end loop;
  end if;
  return new;
end $$;

drop trigger if exists autotask_receiving_source_change on public.receiving_records;
create trigger autotask_receiving_source_change after update on public.receiving_records for each row execute function public.autotask_source_change_trigger();
drop trigger if exists autotask_pending_receiving_source_change on public.pending_receiving_records;
create trigger autotask_pending_receiving_source_change after update on public.pending_receiving_records for each row execute function public.autotask_source_change_trigger();

alter table public."Autotask_rules" enable row level security;
alter table public."Autotask_branch_config" enable row level security;
alter table public."Autotask_events" enable row level security;
alter table public."Autotask_tasks" enable row level security;
alter table public."Autotask_dependencies" enable row level security;
alter table public."Autotask_activity" enable row level security;
alter table public."Autotask_evidence" enable row level security;
revoke all on public."Autotask_rules",public."Autotask_branch_config",public."Autotask_events",public."Autotask_tasks",public."Autotask_dependencies",public."Autotask_activity",public."Autotask_evidence" from anon,authenticated;
grant execute on function public."Autotask_list_rules"() to authenticated;
grant execute on function public."Autotask_get_branch_config"(text) to authenticated;
grant execute on function public."Autotask_save_branch_config"(uuid,text,uuid,uuid[],boolean,integer) to anon,authenticated;
grant execute on function public."Autotask_ingest_receiving_certificate"(text,text,text,uuid) to authenticated;
grant execute on function public."Autotask_list_my_tasks"(uuid,boolean,integer) to anon,authenticated;
grant execute on function public."Autotask_get_source_tasks"(text,text) to authenticated;
grant execute on function public."Autotask_complete_task"(uuid,uuid,jsonb) to anon,authenticated;
grant execute on function public."Autotask_register_evidence"(uuid,uuid,text,text,bigint) to anon,authenticated;
grant execute on function public."Autotask_decide_advance_approval"(uuid,text,text,text,text) to anon,authenticated;
grant execute on function public."Autotask_list_my_advance_approvals"(uuid) to anon,authenticated;
grant execute on function public."Autotask_set_pr_excel_verified"(text,text,boolean) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('Autotask_evidence','Autotask_evidence',false,null,array['image/jpeg','image/png','image/webp','image/heic','image/heif'])
on conflict(id) do nothing;

create or replace function public."Autotask_can_upload_evidence"(p_task_id uuid)
returns boolean language sql security definer set search_path=public
as $$ select exists(select 1 from public."Autotask_tasks" t where t.id=p_task_id and t.assignee_user_id=auth.uid() and t.status not in ('completed','cancelled')) $$;

create or replace function public."Autotask_can_read_evidence"(p_storage_path text)
returns boolean language sql security definer set search_path=public
as $$ select exists(select 1 from public."Autotask_evidence" e join public."Autotask_tasks" t on t.id=e.task_id where e.storage_path=p_storage_path and (t.assignee_user_id=auth.uid() or exists(select 1 from public.users u where u.id=auth.uid() and coalesce(u.is_master_admin,false)))) $$;

drop policy if exists autotask_evidence_insert on storage.objects;
create policy autotask_evidence_insert on storage.objects for insert to authenticated
with check (bucket_id='Autotask_evidence' and public."Autotask_can_upload_evidence"(((storage.foldername(name))[3])::uuid));
drop policy if exists autotask_evidence_select on storage.objects;
create policy autotask_evidence_select on storage.objects for select to authenticated
using (bucket_id='Autotask_evidence' and public."Autotask_can_read_evidence"(name));

commit;
