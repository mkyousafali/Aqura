begin;

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

grant execute on function public."Autotask_complete_task"(uuid,uuid,jsonb) to anon,authenticated;
grant execute on function public."Autotask_register_evidence"(uuid,uuid,text,text,bigint) to anon,authenticated;

commit;
