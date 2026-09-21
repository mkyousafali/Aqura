BEGIN;

-- Keep the existing management operation and opening-print trail, while recording
-- both sides of the cash transfer in the same audit row.
ALTER TABLE public.aqura_safe_box_operations
  ADD COLUMN IF NOT EXISTS denomination_record_id uuid REFERENCES public.denomination_records(id),
  ADD COLUMN IF NOT EXISTS main_counts_before jsonb,
  ADD COLUMN IF NOT EXISTS main_counts_after jsonb,
  ADD COLUMN IF NOT EXISTS safe_box_counts_before jsonb,
  ADD COLUMN IF NOT EXISTS safe_box_counts_after jsonb,
  ADD COLUMN IF NOT EXISTS opening_print_status text,
  ADD COLUMN IF NOT EXISTS opening_printed_at timestamptz;

ALTER TABLE public.aqura_safe_box_operations
  DROP CONSTRAINT IF EXISTS aqura_safe_box_operations_operation_type_check;
ALTER TABLE public.aqura_safe_box_operations
  ADD CONSTRAINT aqura_safe_box_operations_operation_type_check
  CHECK (operation_type IS NULL OR operation_type = 'Withdraw');

CREATE OR REPLACE FUNCTION public.aqura_complete_safe_box_management(
  p_operation_id uuid, p_user_id uuid, p_operation_type text, p_counts jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_operation public.aqura_safe_box_operations%ROWTYPE;
  v_record public.denomination_records%ROWTYPE;
  v_counts jsonb;
  v_safe jsonb;
  v_main_before jsonb := '{}'::jsonb;
  v_main_after jsonb := '{}'::jsonb;
  v_safe_before jsonb := '{}'::jsonb;
  v_safe_after jsonb := '{}'::jsonb;
  v_key text;
  v_main_quantity integer;
  v_safe_quantity integer;
  v_change integer;
  v_values jsonb := '{"d500":50000,"d200":20000,"d100":10000,"d50":5000,"d20":2000,"d10":1000,"d5":500,"d2":200,"d1":100,"d05":50,"d025":25,"coins":100,"damage":100}'::jsonb;
  v_main_before_cents bigint := 0;
  v_main_after_cents bigint := 0;
  v_safe_before_cents bigint := 0;
  v_safe_after_cents bigint := 0;
  v_amount_cents bigint := 0;
BEGIN
  SELECT * INTO v_operation FROM public.aqura_safe_box_operations
    WHERE id = p_operation_id FOR UPDATE;
  IF NOT FOUND OR v_operation.user_id <> p_user_id OR v_operation.status <> 'Open' THEN
    RAISE EXCEPTION 'Safe Box management opening is unavailable';
  END IF;
  IF p_operation_type IS DISTINCT FROM 'Withdraw' OR p_counts IS NULL OR
     jsonb_typeof(p_counts) <> 'object' THEN
    RAISE EXCEPTION 'Only Safe Box withdrawal is allowed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id AND status = 'active' AND
    (coalesce(is_master_admin, false) OR EXISTS (
      SELECT 1 FROM public.aqura_safe_box_permissions
      WHERE user_id = p_user_id AND branch_id = v_operation.branch_id AND permission_type = 'depositor'
    ))) THEN
    RAISE EXCEPTION 'Safe Box Management access denied';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.hr_employee_master
    WHERE user_id = p_user_id AND current_branch_id = v_operation.branch_id) THEN
    RAISE EXCEPTION 'Safe Box branch mismatch';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aqura_pos_print_actions WHERE flow_id = p_operation_id
    AND action_type = 'safe_box_opening' AND source = 'Aqura Safe Box'
    AND reason = 'Safe Box Management' AND print_status = 'success') THEN
    RAISE EXCEPTION 'Successful Safe Box opening print is required';
  END IF;

  -- This row lock makes the latest balance read, validation, both JSON updates,
  -- and the audit completion one atomic operation.
  SELECT * INTO v_record FROM public.denomination_records
    WHERE branch_id = v_operation.branch_id AND record_type = 'main'
    ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Branch denomination record is missing'; END IF;
  v_counts := coalesce(v_record.counts, '{}'::jsonb);
  v_safe := coalesce(v_counts->'safe_box', '{}'::jsonb);
  IF jsonb_typeof(v_counts) <> 'object' OR jsonb_typeof(v_safe) <> 'object' THEN
    RAISE EXCEPTION 'Invalid saved denomination counts';
  END IF;
  FOR v_key IN SELECT jsonb_object_keys(p_counts) LOOP
    IF NOT v_values ? v_key THEN RAISE EXCEPTION 'Unsupported denomination %', v_key; END IF;
  END LOOP;
  FOR v_key IN SELECT jsonb_object_keys(v_values) LOOP
    v_main_quantity := coalesce((v_counts->>v_key)::integer, 0);
    v_safe_quantity := coalesce((v_safe->>v_key)::integer, 0);
    v_change := coalesce((p_counts->>v_key)::integer, 0);
    IF v_main_quantity < 0 OR v_safe_quantity < 0 OR v_change < 0 OR
       v_change > v_safe_quantity OR v_change > 100000 OR
       v_main_quantity::bigint + v_change > 2147483647 THEN
      RAISE EXCEPTION 'Insufficient or invalid Safe Box quantity for %: available %', v_key, v_safe_quantity;
    END IF;
    v_main_before := jsonb_set(v_main_before, ARRAY[v_key], to_jsonb(v_main_quantity), true);
    v_main_after := jsonb_set(v_main_after, ARRAY[v_key], to_jsonb(v_main_quantity + v_change), true);
    v_safe_before := jsonb_set(v_safe_before, ARRAY[v_key], to_jsonb(v_safe_quantity), true);
    v_safe_after := jsonb_set(v_safe_after, ARRAY[v_key], to_jsonb(v_safe_quantity - v_change), true);
    v_counts := jsonb_set(v_counts, ARRAY[v_key], to_jsonb(v_main_quantity + v_change), true);
    v_main_before_cents := v_main_before_cents + v_main_quantity * (v_values->>v_key)::integer;
    v_main_after_cents := v_main_after_cents + (v_main_quantity + v_change) * (v_values->>v_key)::integer;
    v_safe_before_cents := v_safe_before_cents + v_safe_quantity * (v_values->>v_key)::integer;
    v_safe_after_cents := v_safe_after_cents + (v_safe_quantity - v_change) * (v_values->>v_key)::integer;
    v_amount_cents := v_amount_cents + v_change * (v_values->>v_key)::integer;
  END LOOP;
  IF v_amount_cents <= 0 THEN RAISE EXCEPTION 'Enter at least one withdrawal quantity'; END IF;
  IF v_main_before_cents + v_safe_before_cents <> v_main_after_cents + v_safe_after_cents THEN
    RAISE EXCEPTION 'Combined physical cash must remain unchanged';
  END IF;

  UPDATE public.denomination_records SET
    counts = jsonb_set(jsonb_set(v_counts, '{safe_box}', v_safe_after, true),
      '{safe_box_balance}', to_jsonb(v_safe_after_cents / 100.0), true),
    grand_total = v_main_after_cents / 100.0,
    difference = CASE WHEN difference IS NULL THEN NULL ELSE difference +
      (v_main_after_cents + v_safe_after_cents - v_main_before_cents - v_safe_before_cents) / 100.0 END
  WHERE id = v_record.id;

  UPDATE public.aqura_safe_box_operations SET
    denomination_record_id = v_record.id,
    operation_type = 'Withdraw', denomination_counts = p_counts,
    total_amount = v_amount_cents / 100.0,
    balance_before = v_safe_before_cents / 100.0,
    balance_after = v_safe_after_cents / 100.0,
    main_counts_before = v_main_before, main_counts_after = v_main_after,
    safe_box_counts_before = v_safe_before, safe_box_counts_after = v_safe_after,
    opening_print_status = 'success',
    status = 'Completed', completed_at = now()
  WHERE id = p_operation_id;

  RETURN jsonb_build_object('status', 'Completed', 'total_amount', v_amount_cents / 100.0,
    'main_total', v_main_after_cents / 100.0, 'safe_box_balance', v_safe_after_cents / 100.0);
END;
$$;
REVOKE ALL ON FUNCTION public.aqura_complete_safe_box_management(uuid,uuid,text,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.aqura_complete_safe_box_management(uuid,uuid,text,jsonb) TO service_role;

COMMIT;
