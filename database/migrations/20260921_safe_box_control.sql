BEGIN;

CREATE TABLE IF NOT EXISTS public.aqura_safe_box_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id bigint NOT NULL REFERENCES public.branches(id),
  user_id uuid NOT NULL REFERENCES public.users(id),
  permission_type text NOT NULL CHECK (permission_type IN ('receiver', 'depositor', 'printer')),
  added_by uuid NOT NULL REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (branch_id, user_id, permission_type)
);
CREATE INDEX IF NOT EXISTS aqura_safe_box_permissions_user_idx
  ON public.aqura_safe_box_permissions (user_id, branch_id, permission_type);
ALTER TABLE public.aqura_safe_box_permissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.aqura_safe_box_permissions FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.aqura_safe_box_permissions TO service_role;

CREATE TABLE IF NOT EXISTS public.aqura_safe_box_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id),
  branch_id bigint NOT NULL REFERENCES public.branches(id),
  operation_type text CHECK (operation_type IN ('Deposit', 'Withdraw')),
  denomination_counts jsonb CHECK (denomination_counts IS NULL OR jsonb_typeof(denomination_counts) = 'object'),
  total_amount numeric(14,2) CHECK (total_amount IS NULL OR total_amount > 0),
  balance_before numeric(14,2),
  balance_after numeric(14,2),
  printer_name text NOT NULL,
  status text NOT NULL DEFAULT 'Opening' CHECK (status IN ('Opening', 'Print Failed', 'Open', 'Completed')),
  opened_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS aqura_safe_box_operations_branch_idx
  ON public.aqura_safe_box_operations (branch_id, created_at DESC);
ALTER TABLE public.aqura_safe_box_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.aqura_safe_box_operations FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.aqura_safe_box_operations TO service_role;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'aqura_safe_box_permissions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.aqura_safe_box_permissions;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.aqura_complete_safe_box_management(
  p_operation_id uuid, p_user_id uuid, p_operation_type text, p_counts jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_operation public.aqura_safe_box_operations%ROWTYPE;
  v_record public.denomination_records%ROWTYPE;
  v_safe jsonb;
  v_key text;
  v_old integer;
  v_change integer;
  v_next integer;
  v_values jsonb := '{"d500":50000,"d200":20000,"d100":10000,"d50":5000,"d20":2000,"d10":1000,"d5":500,"d2":200,"d1":100,"d05":50,"d025":25,"coins":100,"damage":100}'::jsonb;
  v_amount_cents bigint := 0;
  v_before numeric := 0;
  v_after numeric := 0;
BEGIN
  SELECT * INTO v_operation FROM public.aqura_safe_box_operations WHERE id = p_operation_id FOR UPDATE;
  IF NOT FOUND OR v_operation.user_id <> p_user_id OR v_operation.status <> 'Open' THEN
    RAISE EXCEPTION 'Safe Box management opening is unavailable';
  END IF;
  IF p_operation_type NOT IN ('Deposit', 'Withdraw') OR p_counts IS NULL OR jsonb_typeof(p_counts) <> 'object' THEN
    RAISE EXCEPTION 'Invalid Safe Box operation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id AND status = 'active' AND
    (coalesce(is_master_admin, false) OR EXISTS (
      SELECT 1 FROM public.aqura_safe_box_permissions
      WHERE user_id = p_user_id AND branch_id = v_operation.branch_id AND permission_type = 'depositor'
    ))) THEN
    RAISE EXCEPTION 'Safe Box management access denied';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.hr_employee_master
    WHERE user_id = p_user_id AND current_branch_id = v_operation.branch_id) THEN
    RAISE EXCEPTION 'Safe Box branch mismatch';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aqura_pos_print_actions WHERE flow_id = p_operation_id
    AND action_type = 'safe_box_opening' AND source = 'Aqura Safe Box' AND reason = 'Safe Box Management'
    AND print_status = 'success') THEN
    RAISE EXCEPTION 'Successful Safe Box opening print is required';
  END IF;
  SELECT * INTO v_record FROM public.denomination_records
    WHERE branch_id = v_operation.branch_id AND record_type = 'main'
    ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Branch denomination record is missing'; END IF;
  v_safe := coalesce(v_record.counts->'safe_box', '{}'::jsonb);
  FOR v_key IN SELECT jsonb_object_keys(p_counts) LOOP
    IF NOT v_values ? v_key THEN RAISE EXCEPTION 'Unsupported denomination %', v_key; END IF;
  END LOOP;
  FOR v_key IN SELECT jsonb_object_keys(v_values) LOOP
    v_old := coalesce((v_safe->>v_key)::integer, 0);
    v_change := coalesce((p_counts->>v_key)::integer, 0);
    IF v_old < 0 OR v_change < 0 OR v_change > 100000 OR
       (p_operation_type = 'Withdraw' AND v_change > v_old) THEN
      RAISE EXCEPTION 'Invalid or insufficient Safe Box quantity for %', v_key;
    END IF;
    v_next := v_old + CASE WHEN p_operation_type = 'Deposit' THEN v_change ELSE -v_change END;
    v_before := v_before + v_old * (v_values->>v_key)::integer / 100.0;
    v_after := v_after + v_next * (v_values->>v_key)::integer / 100.0;
    v_amount_cents := v_amount_cents + v_change * (v_values->>v_key)::integer;
    v_safe := jsonb_set(v_safe, ARRAY[v_key], to_jsonb(v_next), true);
  END LOOP;
  IF v_amount_cents <= 0 THEN RAISE EXCEPTION 'Enter at least one denomination quantity'; END IF;
  UPDATE public.denomination_records SET
    counts = jsonb_set(jsonb_set(coalesce(counts, '{}'::jsonb), '{safe_box}', v_safe, true),
      '{safe_box_balance}', to_jsonb(v_after), true),
    difference = CASE WHEN difference IS NULL THEN NULL ELSE difference + v_after - v_before END
  WHERE id = v_record.id;
  UPDATE public.aqura_safe_box_operations SET
    operation_type = p_operation_type, denomination_counts = p_counts,
    total_amount = v_amount_cents / 100.0, balance_before = v_before, balance_after = v_after,
    status = 'Completed', completed_at = now()
  WHERE id = p_operation_id;
  RETURN jsonb_build_object('status', 'Completed', 'total_amount', v_amount_cents / 100.0,
    'safe_box_balance', v_after);
END;
$$;
REVOKE ALL ON FUNCTION public.aqura_complete_safe_box_management(uuid,uuid,text,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.aqura_complete_safe_box_management(uuid,uuid,text,jsonb) TO service_role;

COMMIT;
