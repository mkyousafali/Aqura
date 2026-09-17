begin;

-- Fix: Auto Task notifications (all 10 receiving tasks + the linked advance-payment
-- approval notification) must consistently show Branch, Vendor, and Receiving date.
-- Branch name was never captured into source_refs, and the advance-payment approval
-- notification carried no record-identifying details at all. Everything else in
-- both functions is unchanged from the live definitions.

create or replace function public."Autotask_ingest_receiving_certificate"(p_source_table text,p_source_record_id text,p_certificate_url text,p_actor_user_id uuid default auth.uid())
returns jsonb language plpgsql security definer set search_path=public
as $$
declare v_row jsonb; v_event public."Autotask_events"; v_rule record; v_users uuid[]; v_user uuid; v_task_id uuid; v_created integer:=0; v_branch text; v_branch_name text; v_key text; v_amount numeric; v_approvers uuid[]; v_notifications integer:=0; v_vendor_name text; v_received_by text; v_receiving_date text;
begin
  if p_source_table not in ('receiving_records','pending_receiving_records') then raise exception 'Unsupported source table'; end if;
  execute format('select to_jsonb(r) from public.%I r where r.id::text=$1',p_source_table) into v_row using p_source_record_id;
  if v_row is null then raise exception 'Receiving record not found'; end if;
  select v.vendor_name into v_vendor_name from public.vendors v where v.erp_vendor_id=(v_row->>'vendor_id')::integer;
  select u.username into v_received_by from public.users u where u.id=(v_row->>'user_id')::uuid;
  v_receiving_date:=coalesce(v_row->>'bill_date',v_row->>'created_at');
  v_branch:=v_row->>'branch_id'; v_key:='receiving.clearance_certificate_generated:'||p_source_table||':'||p_source_record_id||':v1';
  select b.name_en into v_branch_name from public.branches b where b.id::text=v_branch;
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
      values(v_event.id,v_rule.id,v_rule.rule_code,v_rule.task_number,v_key||':task:'||v_rule.task_number,v_user,case when v_rule.task_number=1 then 'source_selected_users' else 'branch_default_users' end,v_branch,'receiving',p_source_table,p_source_record_id,jsonb_build_object('certificate_url',p_certificate_url,'vendor_name',coalesce(v_vendor_name,'Unknown vendor'),'branch_name',coalesce(v_branch_name,'Unknown branch'),'receiving_date',v_receiving_date,'received_by',coalesce(v_received_by,'Unknown user')),v_rule.title_en,v_rule.title_ar,case when v_rule.task_number in (2,3,10) then 'blocked' else 'open' end,v_rule.completion_mode,now()+make_interval(mins=>v_rule.effective_timeline),v_rule.effective_timeline,v_rule.dependency_policy,v_rule.closing_policy,v_rule.evidence_policy,v_rule.notification_title_en,v_rule.notification_title_ar,v_rule.notification_body_en,v_rule.notification_body_ar,v_key||':'||v_rule.task_number||':'||v_user)
      on conflict(idempotency_key) do nothing returning id into v_task_id;
      if v_task_id is not null then v_created:=v_created+1; insert into public."Autotask_activity"(task_id,event_id,activity_type,new_status,details) values(v_task_id,v_event.id,'task_created',case when v_rule.task_number in (2,3,10) then 'blocked' else 'open' end,jsonb_build_object('assignee_user_id',v_user)); end if;
      v_task_id:=null;
    end loop;
  end loop;
  insert into public."Autotask_dependencies"(dependent_task_id,prerequisite_task_id)
  select d.id,p.id from public."Autotask_tasks" d join public."Autotask_tasks" p on p.event_id=d.event_id where d.event_id=v_event.id and ((d.task_number in (2,3) and p.task_number=1) or (d.task_number=10 and p.task_number between 1 and 9)) on conflict do nothing;
  update public."Autotask_tasks" d set status='open' where d.event_id=v_event.id and d.status='blocked' and not exists(select 1 from public."Autotask_dependencies" x join public."Autotask_tasks" p on p.id=x.prerequisite_task_id where x.dependent_task_id=d.id and p.status<>'completed');
  v_amount:=coalesce(nullif(v_row->>'final_bill_amount','')::numeric,nullif(v_row->>'bill_amount','')::numeric,0);
  select coalesce(array_agg(x.user_id),'{}'::uuid[]) into v_approvers from (
    select ap.user_id
    from public.approval_permissions ap
    where ap.is_active=true and ap.can_approve_vendor_payments=true
      and (coalesce(ap.vendor_payment_amount_limit,0)=0 or ap.vendor_payment_amount_limit>=v_amount)
    order by (case when coalesce(ap.vendor_payment_amount_limit,0)=0 then 'infinity'::numeric else ap.vendor_payment_amount_limit end) asc, ap.user_id asc
    limit 1
  ) x;
  if cardinality(v_approvers)=0 then select coalesce(array_agg(u.id),'{}'::uuid[]) into v_approvers from public.users u where coalesce(u.is_master_admin,false)=true and u.status='active'; end if;
  execute format('update public.%I set autotask_advance_approval_status=$1,autotask_advance_approval_approver_ids=$2,autotask_advance_approval_requested_by=$3,autotask_advance_approval_requested_at=now() where id::text=$4',p_source_table) using 'sent_for_approval',v_approvers,p_actor_user_id,p_source_record_id;
  v_notifications:=public."Autotask_publish_event_notifications"(v_event.id,v_approvers);
  update public."Autotask_events" set status='processed',processed_at=now(),updated_at=now() where id=v_event.id;
  perform public."Autotask_refresh_source"(p_source_table,p_source_record_id);
  return jsonb_build_object('success',true,'duplicate',false,'tasks_created',v_created,'notifications_sent',v_notifications,'event_id',v_event.id,'approval_approver_ids',v_approvers);
exception when others then
  if v_event.id is not null then update public."Autotask_events" set status='failed',attempt_count=attempt_count+1,error_message=sqlerrm,updated_at=now() where id=v_event.id; end if;
  raise;
end $$;

create or replace function public."Autotask_publish_event_notifications"(p_event_id uuid,p_approval_user_ids uuid[] default '{}')
returns integer language plpgsql security definer set search_path=public
as $$
declare v_task record; v_notification_id uuid; v_count integer:=0; v_title_en text; v_title_ar text; v_body_en text; v_body_ar text; v_details_en text; v_details_ar text; v_approval_body_en text; v_approval_body_ar text;
begin
  for v_task in select * from public."Autotask_tasks" where event_id=p_event_id loop
    v_title_en:=v_task.notification_title_en;
    v_title_ar:=v_task.notification_title_ar;
    v_body_en:=replace(replace(v_task.notification_body_en,'{{vendor_name}}',coalesce(v_task.source_refs->>'vendor_name','')),'{{receiving_date}}',coalesce(v_task.source_refs->>'receiving_date',''));
    v_body_ar:=replace(replace(v_task.notification_body_ar,'{{vendor_name}}',coalesce(v_task.source_refs->>'vendor_name','')),'{{receiving_date}}',coalesce(v_task.source_refs->>'receiving_date',''));
    v_details_en:=E'\n\nTask: '||coalesce(v_task.title_en,'')||E'\nBranch: '||coalesce(v_task.source_refs->>'branch_name','')||E'\nVendor: '||coalesce(v_task.source_refs->>'vendor_name','')||E'\nBill number: '||coalesce(v_task.source_refs->>'bill_number','')||E'\nReceiving date: '||coalesce(v_task.source_refs->>'receiving_date','')||E'\nReceived by: '||coalesce(v_task.source_refs->>'received_by','');
    v_details_ar:=E'\n\nالمهمة: '||coalesce(v_task.title_ar,'')||E'\nالفرع: '||coalesce(v_task.source_refs->>'branch_name','')||E'\nالمورد: '||coalesce(v_task.source_refs->>'vendor_name','')||E'\nرقم الفاتورة: '||coalesce(v_task.source_refs->>'bill_number','')||E'\nتاريخ الاستلام: '||coalesce(v_task.source_refs->>'receiving_date','')||E'\nتم الاستلام بواسطة: '||coalesce(v_task.source_refs->>'received_by','');
    v_body_en:=v_body_en||v_details_en;
    v_body_ar:=v_body_ar||v_details_ar;
    insert into public.notifications(title,message,title_en,title_ar,message_en,message_ar,type,priority,target_type,target_users,created_by,created_by_name,created_by_role,status,total_recipients,metadata)
    values(v_title_en||' / '||v_title_ar,v_body_en||E'\n---\n'||v_body_ar,v_title_en,v_title_ar,v_body_en,v_body_ar,'task_assigned','medium','specific_users',to_jsonb(array[v_task.assignee_user_id]),'Auto Task System','Auto Task System','System','published',1,jsonb_build_object('autotask_id',v_task.id,'autotask_event_id',p_event_id,'source_table',v_task.source_table,'source_record_id',v_task.source_record_id))
    returning id into v_notification_id;
    v_count:=v_count+1;
  end loop;
  if cardinality(coalesce(p_approval_user_ids,'{}'::uuid[]))>0 then
    v_approval_body_en:='An advance-payment approval decision is required.'||E'\n\nBranch: '||coalesce(v_task.source_refs->>'branch_name','')||E'\nVendor: '||coalesce(v_task.source_refs->>'vendor_name','')||E'\nReceiving date: '||coalesce(v_task.source_refs->>'receiving_date','');
    v_approval_body_ar:='مطلوب قرار بشأن موافقة الدفعة المقدمة.'||E'\n\nالفرع: '||coalesce(v_task.source_refs->>'branch_name','')||E'\nالمورد: '||coalesce(v_task.source_refs->>'vendor_name','')||E'\nتاريخ الاستلام: '||coalesce(v_task.source_refs->>'receiving_date','');
    insert into public.notifications(title,message,title_en,title_ar,message_en,message_ar,type,priority,target_type,target_users,created_by,created_by_name,created_by_role,status,total_recipients,metadata)
    values('Advance Payment Approval / موافقة الدفعة المقدمة',v_approval_body_en||E'\n---\n'||v_approval_body_ar,'Advance Payment Approval','موافقة الدفعة المقدمة',v_approval_body_en,v_approval_body_ar,'approval_request','high','specific_users',to_jsonb(p_approval_user_ids),'Auto Task System','Auto Task System','System','published',cardinality(p_approval_user_ids),jsonb_build_object('autotask_event_id',p_event_id,'approval_type','receiving_advance_payment'))
    returning id into v_notification_id;
    v_count:=v_count+1;
  end if;
  return v_count;
end $$;

grant execute on function public."Autotask_ingest_receiving_certificate"(text,text,text,uuid) to authenticated;

commit;
