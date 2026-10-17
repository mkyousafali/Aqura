begin;

create or replace function public.master_delete_statement_mjv_item(p_statement_mjv_id uuid,p_item text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_actor uuid:=public.aqura_current_user_id(); v_task_ids uuid[]; v_deleted int:=0;
begin
  if v_actor is null or not exists(select 1 from public.users where id=v_actor and status='active' and coalesce(is_master_admin,false)) then
    raise exception 'Master Admin access required.';
  end if;
  if not exists(select 1 from public.statement_mjvs where id=p_statement_mjv_id) then raise exception 'Saved statement MJV was not found.'; end if;
  if p_item='tasks' then
    select coalesce(array_agg(task_id) filter(where task_id is not null),'{}'::uuid[]) into v_task_ids
    from public.statement_mjv_branches where statement_mjv_id=p_statement_mjv_id;
    if cardinality(v_task_ids)>0 then
      delete from public.assistant_workflow_tasks where id=any(v_task_ids);
      get diagnostics v_deleted=row_count;
    end if;
    update public.statement_mjv_branches set task_id=null,task_status='saved',updated_at=now() where statement_mjv_id=p_statement_mjv_id;
    update public.statement_mjvs set status='saved',updated_at=now() where id=p_statement_mjv_id;
    return jsonb_build_object('success',true,'deleted_tasks',v_deleted);
  elsif p_item='mjv' then
    if exists(select 1 from public.statement_mjv_branches where statement_mjv_id=p_statement_mjv_id and task_id is not null) then
      raise exception 'Delete the posting tasks before deleting the saved MJV.';
    end if;
    delete from public.statement_mjvs where id=p_statement_mjv_id;
    return jsonb_build_object('success',true,'deleted_mjv',true);
  end if;
  raise exception 'Delete item must be tasks or mjv.';
end;
$$;

revoke all on function public.master_delete_statement_mjv_item(uuid,text) from public,anon;
grant execute on function public.master_delete_statement_mjv_item(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
