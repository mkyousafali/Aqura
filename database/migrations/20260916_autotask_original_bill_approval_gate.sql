begin;

create or replace function public."Autotask_decide_advance_approval"(p_actor_user_id uuid,p_source_table text,p_source_record_id text,p_decision text,p_notes text default null)
returns jsonb language plpgsql security definer set search_path=public as $$ declare v_row jsonb; v_updated bigint; begin
  if not exists(select 1 from public.users where id=p_actor_user_id and status='active') then raise exception 'Active Aqura user not found'; end if;
  if p_source_table not in ('receiving_records','pending_receiving_records') or p_decision not in ('approved','rejected') then raise exception 'Invalid approval decision'; end if;
  execute format('select to_jsonb(r) from public.%I r where r.id::text=$1 for update',p_source_table) into v_row using p_source_record_id;
  if coalesce(v_row->>'autotask_advance_approval_status','')<>'sent_for_approval' then raise exception 'Approval already decided or unavailable'; end if;
  if nullif(btrim(coalesce(v_row->>'original_bill_url','')),'') is null then raise exception 'Original bill must be uploaded before this request can be decided'; end if;
  if not (p_actor_user_id=any(array(select jsonb_array_elements_text(coalesce(v_row->'autotask_advance_approval_approver_ids','[]'::jsonb))::uuid))) then raise exception 'User is not an eligible approver'; end if;
  execute format('update public.%I set autotask_advance_approval_status=$1,autotask_advance_approval_decided_by=$2,autotask_advance_approval_decided_at=now(),autotask_advance_approval_notes=$3 where id::text=$4 and autotask_advance_approval_status=$5 and nullif(btrim(coalesce(original_bill_url,'''')::text),'''') is not null',p_source_table) using p_decision,p_actor_user_id,p_notes,p_source_record_id,'sent_for_approval';
  get diagnostics v_updated = row_count;
  if v_updated=0 then raise exception 'Approval was already decided or the original bill is unavailable'; end if;
  perform public."Autotask_refresh_source"(p_source_table,p_source_record_id);
  return jsonb_build_object('success',true,'decision',p_decision);
end $$;

drop function if exists public."Autotask_list_my_advance_approvals"(uuid);
create function public."Autotask_list_my_advance_approvals"(p_user_id uuid)
returns table(source_table text,source_record_id text,branch_id text,vendor_name text,bill_number text,amount numeric,requested_at timestamptz,status text,original_bill_url text)
language sql security definer set search_path=public as $$
  select distinct q.* from (
    select 'receiving_records'::text source_table,r.id::text source_record_id,r.branch_id::text branch_id,coalesce(v.vendor_name,'Unknown vendor') vendor_name,r.bill_number::text bill_number,coalesce(r.final_bill_amount,r.bill_amount,0)::numeric amount,r.autotask_advance_approval_requested_at requested_at,r.autotask_advance_approval_status status,r.original_bill_url::text original_bill_url
    from public.receiving_records r left join public.vendors v on v.erp_vendor_id=r.vendor_id where r.autotask_advance_approval_status='sent_for_approval' and p_user_id=any(r.autotask_advance_approval_approver_ids)
    union all
    select 'pending_receiving_records'::text,r.id::text,r.branch_id::text,coalesce(v.vendor_name,'Unknown vendor'),r.bill_number::text,coalesce(r.final_bill_amount,r.bill_amount,0)::numeric,r.autotask_advance_approval_requested_at,r.autotask_advance_approval_status,r.original_bill_url::text
    from public.pending_receiving_records r left join public.vendors v on v.erp_vendor_id=r.vendor_id where r.autotask_advance_approval_status='sent_for_approval' and p_user_id=any(r.autotask_advance_approval_approver_ids)
  ) q where exists(select 1 from public.users u where u.id=p_user_id and u.status='active') order by q.requested_at desc
$$;
grant execute on function public."Autotask_decide_advance_approval"(uuid,text,text,text,text) to anon,authenticated;
grant execute on function public."Autotask_list_my_advance_approvals"(uuid) to anon,authenticated;
commit;
