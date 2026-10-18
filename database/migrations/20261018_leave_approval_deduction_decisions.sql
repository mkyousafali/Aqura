BEGIN;

-- Each submitted day must carry an explicit deduction decision. This RPC saves
-- all approval and deduction decisions together; a stale/invalid day rolls back
-- the entire request. Existing leave and saved payroll snapshots are untouched.
CREATE OR REPLACE FUNCTION public.decide_leave_request_days(p_decisions jsonb, p_rejection_reason text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO public
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_count integer;
  v_item jsonb;
  v_employee text;
  v_employee_ids integer;
BEGIN
  IF v_actor IS NULL OR NOT (
    EXISTS (SELECT 1 FROM public.users WHERE id = v_actor AND is_master_admin IS TRUE)
    OR EXISTS (SELECT 1 FROM public.approval_permissions WHERE user_id = v_actor AND is_active AND can_approve_leave_requests)
  ) THEN
    RAISE EXCEPTION 'Leave approval permission required' USING ERRCODE = '42501';
  END IF;
  IF p_decisions IS NULL OR jsonb_typeof(p_decisions) <> 'array' THEN
    RAISE EXCEPTION 'Per-day decisions are required';
  END IF;
  v_count := jsonb_array_length(p_decisions);
  IF v_count = 0 THEN RAISE EXCEPTION 'Per-day decisions are required'; END IF;
  IF (SELECT count(DISTINCT e->>'id') FROM jsonb_array_elements(p_decisions) e) <> v_count THEN
    RAISE EXCEPTION 'Every leave day must be specified exactly once';
  END IF;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_decisions) LOOP
    IF coalesce(v_item->>'id', '') = ''
      OR coalesce(v_item->>'status', '') NOT IN ('approved', 'rejected')
      OR jsonb_typeof(v_item->'deduct') IS DISTINCT FROM 'boolean' THEN
      RAISE EXCEPTION 'Choose Deduct or Don''t deduct for every day';
    END IF;
  END LOOP;
  -- Lock the exact pending records before any write (also prevents double action).
  PERFORM d.id FROM public.day_off d
    WHERE d.id IN (SELECT e->>'id' FROM jsonb_array_elements(p_decisions) e)
      AND coalesce(d.approval_status, 'pending') IN ('pending', 'sent_for_approval')
    ORDER BY d.id FOR UPDATE;
  GET DIAGNOSTICS v_employee_ids = ROW_COUNT;
  IF v_employee_ids <> v_count THEN
    RAISE EXCEPTION 'A leave day is missing or has already been decided. Reload the request.';
  END IF;
  SELECT count(DISTINCT employee_id), min(employee_id) INTO v_employee_ids, v_employee
    FROM public.day_off WHERE id IN (SELECT e->>'id' FROM jsonb_array_elements(p_decisions) e);
  IF v_employee_ids <> 1 THEN RAISE EXCEPTION 'Decisions must belong to one employee'; END IF;

  UPDATE public.day_off d SET
    approval_status = e.value->>'status',
    is_deductible_on_salary = (e.value->>'deduct')::boolean,
    approval_approved_by = v_actor,
    approval_approved_at = now(),
    updated_at = now(),
    rejection_reason = CASE WHEN e.value->>'status' = 'rejected'
      THEN coalesce(nullif(btrim(p_rejection_reason), ''), 'Rejected by approver') ELSE NULL END
  FROM jsonb_array_elements(p_decisions) e
  WHERE d.id = e.value->>'id';

  RETURN jsonb_build_object('success', true, 'updated', v_count);
END;
$$;

REVOKE ALL ON FUNCTION public.decide_leave_request_days(jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decide_leave_request_days(jsonb, text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
