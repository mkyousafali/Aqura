BEGIN;

CREATE OR REPLACE FUNCTION public."Autotask_list_my_advance_approvals"(p_user_id uuid)
RETURNS TABLE(source_table text, source_record_id text, branch_id text, vendor_name text, bill_number text, amount numeric, requested_at timestamptz, status text, original_bill_url text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT DISTINCT q.*
  FROM (
    SELECT 'receiving_records'::text,r.id::text,r.branch_id::text,
      coalesce(v.vendor_name,'Unknown vendor')::text,r.bill_number::text,
      coalesce(r.final_bill_amount,r.bill_amount,0)::numeric,
      r.autotask_advance_approval_requested_at,r.autotask_advance_approval_status,
      r.original_bill_url::text
    FROM public.receiving_records r
    LEFT JOIN public.vendors v ON v.erp_vendor_id=r.vendor_id AND v.branch_id=r.branch_id
    WHERE r.autotask_advance_approval_status='sent_for_approval'
      AND p_user_id=ANY(r.autotask_advance_approval_approver_ids)

    UNION ALL

    SELECT 'pending_receiving_records'::text,r.id::text,r.branch_id::text,
      coalesce(v.vendor_name,'Unknown vendor')::text,
      coalesce(posted.bill_number,r.bill_number)::text,
      coalesce(posted.final_bill_amount,posted.bill_amount,r.final_bill_amount,r.bill_amount,0)::numeric,
      r.autotask_advance_approval_requested_at,r.autotask_advance_approval_status,
      coalesce(posted.original_bill_url,r.original_bill_url)::text
    FROM public.pending_receiving_records r
    LEFT JOIN public.receiving_records posted ON posted.id=r.posted_receiving_record_id
    LEFT JOIN public.vendors v ON v.erp_vendor_id=coalesce(posted.vendor_id,r.vendor_id)
      AND v.branch_id=coalesce(posted.branch_id,r.branch_id)
    WHERE r.autotask_advance_approval_status='sent_for_approval'
      AND p_user_id=ANY(r.autotask_advance_approval_approver_ids)
  ) q
  WHERE EXISTS(SELECT 1 FROM public.users u WHERE u.id=p_user_id AND u.status='active')
  ORDER BY 7 DESC;
$$;

CREATE OR REPLACE FUNCTION public."Autotask_decide_advance_approval"(p_actor_user_id uuid, p_source_table text, p_source_record_id text, p_decision text, p_notes text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row jsonb;
  v_posted_row jsonb;
  v_effective_bill_url text;
  v_updated bigint;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=p_actor_user_id AND status='active') THEN
    RAISE EXCEPTION 'Active Aqura user not found';
  END IF;
  IF p_source_table NOT IN ('receiving_records','pending_receiving_records') OR p_decision NOT IN ('approved','rejected') THEN
    RAISE EXCEPTION 'Invalid approval decision';
  END IF;

  EXECUTE format('select to_jsonb(r) from public.%I r where r.id::text=$1 for update',p_source_table)
    INTO v_row USING p_source_record_id;
  IF v_row IS NULL THEN RAISE EXCEPTION 'Receiving record not found'; END IF;
  IF coalesce(v_row->>'autotask_advance_approval_status','')<>'sent_for_approval' THEN
    RAISE EXCEPTION 'Approval already decided or unavailable';
  END IF;

  v_effective_bill_url:=nullif(btrim(coalesce(v_row->>'original_bill_url','')),'');
  IF p_source_table='pending_receiving_records'
     AND nullif(v_row->>'posted_receiving_record_id','') IS NOT NULL THEN
    SELECT to_jsonb(r) INTO v_posted_row
    FROM public.receiving_records r
    WHERE r.id::text=v_row->>'posted_receiving_record_id';
    v_effective_bill_url:=coalesce(
      nullif(btrim(coalesce(v_posted_row->>'original_bill_url','')),''),
      v_effective_bill_url
    );
  END IF;
  IF v_effective_bill_url IS NULL THEN
    RAISE EXCEPTION 'Original bill must be uploaded before this request can be decided';
  END IF;
  IF NOT (p_actor_user_id=ANY(array(
    SELECT jsonb_array_elements_text(coalesce(v_row->'autotask_advance_approval_approver_ids','[]'::jsonb))::uuid
  ))) THEN RAISE EXCEPTION 'User is not an eligible approver'; END IF;

  EXECUTE format(
    'update public.%I set autotask_advance_approval_status=$1,autotask_advance_approval_decided_by=$2,autotask_advance_approval_decided_at=now(),autotask_advance_approval_notes=$3 where id::text=$4 and autotask_advance_approval_status=$5',
    p_source_table
  ) USING p_decision,p_actor_user_id,p_notes,p_source_record_id,'sent_for_approval';
  GET DIAGNOSTICS v_updated=ROW_COUNT;
  IF v_updated=0 THEN RAISE EXCEPTION 'Approval was already decided or unavailable'; END IF;

  PERFORM public."Autotask_refresh_source"(p_source_table,p_source_record_id);
  RETURN jsonb_build_object('success',true,'decision',p_decision);
END;
$function$;

CREATE OR REPLACE FUNCTION public."Autotask_refresh_source"(p_source_table text, p_source_record_id text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_row jsonb;
  v_posted_row jsonb;
  v_source_approval_status text;
  v_task record;
  v_match boolean;
  v_closed integer:=0;
BEGIN
  IF p_source_table NOT IN ('receiving_records','pending_receiving_records') THEN RAISE EXCEPTION 'Unsupported source table'; END IF;
  EXECUTE format('select to_jsonb(r) from public.%I r where r.id::text=$1',p_source_table) INTO v_row USING p_source_record_id;
  IF v_row IS NULL THEN RETURN 0; END IF;

  IF p_source_table='pending_receiving_records' AND nullif(v_row->>'posted_receiving_record_id','') IS NOT NULL THEN
    v_source_approval_status:=v_row->>'autotask_advance_approval_status';
    SELECT to_jsonb(r) INTO v_posted_row FROM public.receiving_records r WHERE r.id::text=v_row->>'posted_receiving_record_id';
    IF v_posted_row IS NOT NULL THEN
      v_row:=v_row||v_posted_row;
      v_row:=jsonb_set(v_row,'{autotask_advance_approval_status}',to_jsonb(v_source_approval_status),true);
    END IF;
  END IF;

  FOR v_task IN SELECT * FROM public."Autotask_tasks" WHERE source_table=p_source_table AND source_record_id=p_source_record_id AND status IN ('open','blocked') LOOP
    v_match:=false;
    CASE v_task.task_number
      WHEN 4 THEN v_match:=lower(coalesce(v_row#>>'{original_bill_check_result,status}',''))='matched' AND nullif(v_row->>'original_bill_url','') IS NOT NULL;
      WHEN 5 THEN v_match:=nullif(btrim(coalesce(v_row->>'pr_excel_file_url','')),'') IS NOT NULL;
      WHEN 6 THEN v_match:=coalesce((v_row->>'autotask_pr_excel_verified')::boolean,false);
      WHEN 7 THEN v_match:=nullif(btrim(coalesce(v_row->>'erp_purchase_invoice_reference','')),'') IS NOT NULL;
      WHEN 8 THEN v_match:=lower(coalesce(v_row#>>'{erp_check_result,status}',''))='matched';
      WHEN 9 THEN v_match:=coalesce(v_row->>'autotask_advance_approval_status','') IN ('approved','rejected');
      WHEN 10 THEN v_match:=NOT EXISTS(SELECT 1 FROM public."Autotask_dependencies" d JOIN public."Autotask_tasks" p ON p.id=d.prerequisite_task_id WHERE d.dependent_task_id=v_task.id AND p.status<>'completed');
      ELSE v_match:=false;
    END CASE;
    IF v_match AND v_task.task_number BETWEEN 4 AND 10 THEN
      UPDATE public."Autotask_tasks" SET status='completed',status_reason_code='source_condition_met',outcome_code=CASE WHEN v_task.task_number=9 THEN v_row->>'autotask_advance_approval_status' ELSE 'completed' END,completed_at=now(),completed_by_user_id=null,row_version=row_version+1,updated_at=now() WHERE id=v_task.id AND status<>'completed';
      IF found THEN
        v_closed:=v_closed+1;
        INSERT INTO public."Autotask_activity"(task_id,event_id,activity_type,old_status,new_status,reason_code,details) VALUES(v_task.id,v_task.event_id,'auto_completion','open','completed','source_condition_met',jsonb_build_object('task_number',v_task.task_number));
      END IF;
    END IF;
  END LOOP;
  IF v_closed>0 THEN PERFORM public."Autotask_refresh_source"(p_source_table,p_source_record_id); END IF;
  RETURN v_closed;
END;
$function$;

COMMIT;
