begin;

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

commit;
