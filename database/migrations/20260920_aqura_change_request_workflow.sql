BEGIN;

ALTER TABLE public.aqura_change_requests
  DROP CONSTRAINT aqura_change_requests_status_check;
ALTER TABLE public.aqura_change_requests
  ADD CONSTRAINT aqura_change_requests_status_check CHECK (status IN
    ('Pending', 'Cash Received', 'Safe Box Printed', 'Ready for Cashier Confirmation', 'Cashier Confirmed', 'Completed'));
ALTER TABLE public.aqura_change_requests
  ADD COLUMN IF NOT EXISTS received_counts jsonb,
  ADD COLUMN IF NOT EXISTS received_total numeric(14,2),
  ADD COLUMN IF NOT EXISTS received_at timestamptz,
  ADD COLUMN IF NOT EXISTS withdrawal_counts jsonb,
  ADD COLUMN IF NOT EXISTS withdrawal_total numeric(14,2),
  ADD COLUMN IF NOT EXISTS safe_box_printed_at timestamptz,
  ADD COLUMN IF NOT EXISTS processed_at timestamptz,
  ADD COLUMN IF NOT EXISTS cashier_confirmed_counts jsonb,
  ADD COLUMN IF NOT EXISTS cashier_confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS safe_box_printer_name text,
  ADD COLUMN IF NOT EXISTS cashier_printer_name text;

ALTER TABLE public.aqura_pos_print_actions
  ADD COLUMN IF NOT EXISTS request_id uuid REFERENCES public.aqura_change_requests(id),
  ADD COLUMN IF NOT EXISTS source text;
ALTER TABLE public.aqura_pos_print_actions
  DROP CONSTRAINT aqura_pos_print_actions_action_type_check;
ALTER TABLE public.aqura_pos_print_actions
  ADD CONSTRAINT aqura_pos_print_actions_action_type_check CHECK (action_type IN (
    'printer_selection', 'test_print_attempt', 'test_print_success', 'test_print_failure',
    'opening_pos_counter', 'closing_pos_counter', 'recharge_card_operation',
    'other_reason', 'final_print_attempt', 'final_print_success', 'final_print_failure',
    'safe_box_opening', 'pos_counter_opening'
  ));
CREATE INDEX IF NOT EXISTS aqura_pos_print_actions_request_idx
  ON public.aqura_pos_print_actions (request_id, created_at DESC);
GRANT UPDATE ON public.aqura_change_requests TO service_role;
GRANT UPDATE ON public.denomination_records TO service_role;

CREATE OR REPLACE FUNCTION public.aqura_finalize_safe_box_request(
  p_request_id uuid, p_user_id uuid, p_withdrawal_counts jsonb, p_printer_name text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_request public.aqura_change_requests%ROWTYPE;
  v_record public.denomination_records%ROWTYPE;
  v_safe jsonb;
  v_key text;
  v_old integer;
  v_in integer;
  v_out integer;
  v_values jsonb := '{"d500":50000,"d200":20000,"d100":10000,"d50":5000,"d20":2000,"d10":1000,"d5":500,"d2":200,"d1":100,"d05":50,"d025":25}'::jsonb;
  v_total_cents bigint := 0;
  v_old_balance numeric := 0;
  v_new_balance numeric := 0;
BEGIN
  SELECT * INTO v_request FROM public.aqura_change_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_request.requested_to_user_id <> p_user_id OR v_request.status <> 'Safe Box Printed' THEN
    RAISE EXCEPTION 'Request is not ready for Safe Box withdrawal';
  END IF;
  IF p_withdrawal_counts IS NULL OR jsonb_typeof(p_withdrawal_counts) <> 'object' THEN
    RAISE EXCEPTION 'Invalid withdrawal denominations';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.aqura_pos_print_actions
    WHERE request_id = p_request_id AND action_type = 'safe_box_opening' AND print_status = 'success') THEN
    RAISE EXCEPTION 'Successful Safe Box opening print is required';
  END IF;
  SELECT * INTO v_record FROM public.denomination_records
    WHERE branch_id = v_request.branch_id AND record_type = 'main'
    ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Branch denomination record is missing'; END IF;
  v_safe := coalesce(v_record.counts->'safe_box', '{}'::jsonb);
  FOR v_key IN SELECT jsonb_object_keys(p_withdrawal_counts) LOOP
    IF NOT v_values ? v_key THEN RAISE EXCEPTION 'Unsupported denomination %', v_key; END IF;
  END LOOP;
  FOR v_key IN SELECT jsonb_object_keys(v_values) LOOP
    v_old := coalesce((v_safe->>v_key)::integer, 0);
    v_in := coalesce((v_request.received_counts->>v_key)::integer, 0);
    v_out := coalesce((p_withdrawal_counts->>v_key)::integer, 0);
    IF v_old < 0 OR v_in < 0 OR v_out < 0 OR v_out > v_old THEN
      RAISE EXCEPTION 'Insufficient Safe Box balance for %: available %', v_key, v_old;
    END IF;
    v_old_balance := v_old_balance + v_old * (v_values->>v_key)::integer / 100.0;
    v_new_balance := v_new_balance + (v_old + v_in - v_out) * (v_values->>v_key)::integer / 100.0;
    v_total_cents := v_total_cents + v_out * (v_values->>v_key)::integer;
    v_safe := jsonb_set(v_safe, ARRAY[v_key], to_jsonb(v_old + v_in - v_out), true);
  END LOOP;
  -- Finance includes its Coins and Damage rows as one SAR each. Preserve them unchanged.
  v_old_balance := v_old_balance + coalesce((v_safe->>'coins')::numeric, 0) + coalesce((v_safe->>'damage')::numeric, 0);
  v_new_balance := v_new_balance + coalesce((v_safe->>'coins')::numeric, 0) + coalesce((v_safe->>'damage')::numeric, 0);
  IF v_total_cents <= 0 THEN RAISE EXCEPTION 'Enter at least one withdrawal denomination'; END IF;
  UPDATE public.denomination_records SET
    counts = jsonb_set(jsonb_set(coalesce(counts, '{}'::jsonb), '{safe_box}', v_safe, true),
      '{safe_box_balance}', to_jsonb(v_new_balance), true),
    difference = CASE WHEN difference IS NULL THEN NULL ELSE difference + v_new_balance - v_old_balance END
    WHERE id = v_record.id;
  UPDATE public.aqura_change_requests SET
    withdrawal_counts = p_withdrawal_counts, withdrawal_total = v_total_cents / 100.0,
    safe_box_printer_name = p_printer_name, processed_at = now(),
    status = 'Ready for Cashier Confirmation'
    WHERE id = p_request_id;
  RETURN jsonb_build_object('status', 'Ready for Cashier Confirmation', 'withdrawal_total', v_total_cents / 100.0,
    'safe_box_balance', v_new_balance);
END;
$$;
REVOKE ALL ON FUNCTION public.aqura_finalize_safe_box_request(uuid,uuid,jsonb,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.aqura_finalize_safe_box_request(uuid,uuid,jsonb,text) TO service_role;

COMMIT;
