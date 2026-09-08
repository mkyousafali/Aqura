-- Support for the Pending Receiving Records window + "Final Receiving" flow:
--   1. New columns on pending_receiving_records: which bill type it was, and its
--      clearance status (pending -> cleared once posted to receiving_records).
--   2. get_pending_receiving_records_with_details(...) — listing RPC for the new
--      window, mirroring get_receiving_records_with_details but scoped to pending,
--      unpaid-schedule concepts (mark-paid / due-date) intentionally excluded since
--      no vendor_payment_schedule row exists until a record is cleared.
--   3. finalize_pending_receiving_record(...) — atomically copies a pending row into
--      receiving_records (SAME id preserved, so its already-created receiving_tasks
--      stay correctly linked) and marks the pending row Cleared. Does not touch task
--      creation — that dedupe already lives in process_*_clearance_certificate_generation.

-- =======================================================
-- 1. New columns
-- =======================================================
ALTER TABLE public.pending_receiving_records
  ADD COLUMN IF NOT EXISTS bill_document_type character varying(30),
  ADD COLUMN IF NOT EXISTS status character varying(20) NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS cleared_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS cleared_by_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS posted_receiving_record_id uuid;

ALTER TABLE public.pending_receiving_records
  DROP CONSTRAINT IF EXISTS check_pending_status;
ALTER TABLE public.pending_receiving_records
  ADD CONSTRAINT check_pending_status CHECK (status IN ('pending', 'cleared'));

CREATE INDEX IF NOT EXISTS idx_pending_receiving_records_status ON public.pending_receiving_records (status);

-- =======================================================
-- 2. get_pending_receiving_records_with_details(...)
-- =======================================================
CREATE OR REPLACE FUNCTION public.get_pending_receiving_records_with_details(
  p_limit integer DEFAULT 500,
  p_offset integer DEFAULT 0,
  p_branch_id text DEFAULT NULL::text,
  p_vendor_search text DEFAULT NULL::text,
  p_erp_ref_filter text DEFAULT NULL::text,
  p_erp_reference_search text DEFAULT NULL::text,
  p_bill_date_from date DEFAULT NULL::date,
  p_bill_date_to date DEFAULT NULL::date
)
RETURNS TABLE(
  id text, bill_number text, vendor_id text, branch_id text, bill_date date, bill_amount numeric,
  created_at timestamp with time zone, user_id text, original_bill_url text,
  erp_purchase_invoice_reference text, certificate_url text, pr_excel_file_url text,
  final_bill_amount numeric, payment_method text, credit_period integer, bank_name text, iban text,
  bill_document_type text, status text,
  branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text,
  vendor_name text, vat_number text, username text, user_display_name text,
  user_display_name_en text, user_display_name_ar text, total_count bigint
)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM pending_receiving_records r
    LEFT JOIN vendors v ON v.erp_vendor_id = r.vendor_id AND v.branch_id = r.branch_id
    WHERE r.status = 'pending'
      AND (p_branch_id IS NULL OR r.branch_id::TEXT = p_branch_id)
      AND (p_vendor_search IS NULL OR p_vendor_search = '' OR LOWER(v.vendor_name) LIKE '%' || LOWER(p_vendor_search) || '%')
      AND (p_erp_ref_filter IS NULL OR p_erp_ref_filter = ''
           OR (p_erp_ref_filter = 'entered' AND r.erp_purchase_invoice_reference IS NOT NULL AND TRIM(r.erp_purchase_invoice_reference::TEXT) <> '')
           OR (p_erp_ref_filter = 'not_entered' AND (r.erp_purchase_invoice_reference IS NULL OR TRIM(r.erp_purchase_invoice_reference::TEXT) = '')))
      AND (p_erp_reference_search IS NULL OR p_erp_reference_search = '' OR LOWER(r.erp_purchase_invoice_reference::TEXT) LIKE '%' || LOWER(p_erp_reference_search) || '%')
      AND (p_bill_date_from IS NULL OR r.bill_date >= p_bill_date_from)
      AND (p_bill_date_to IS NULL OR r.bill_date <= p_bill_date_to);

    RETURN QUERY
    SELECT
        r.id::TEXT,
        r.bill_number::TEXT,
        r.vendor_id::TEXT,
        r.branch_id::TEXT,
        r.bill_date,
        r.bill_amount,
        r.created_at,
        r.user_id::TEXT,
        r.original_bill_url::TEXT,
        r.erp_purchase_invoice_reference::TEXT,
        r.certificate_url::TEXT,
        r.pr_excel_file_url::TEXT,
        r.final_bill_amount,
        r.payment_method::TEXT,
        r.credit_period,
        r.bank_name::TEXT,
        r.iban::TEXT,
        r.bill_document_type::TEXT,
        r.status::TEXT,
        COALESCE(b.name_en, 'N/A')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, b.name_en, 'N/A')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, b.location_en, '')::TEXT AS branch_location_ar,
        COALESCE(v.vendor_name, 'N/A')::TEXT AS vendor_name,
        v.vat_number::TEXT,
        COALESCE(u.username, '')::TEXT AS username,
        COALESCE(he.name_en, he.name_ar, u.username, '')::TEXT AS user_display_name,
        COALESCE(he.name_en, '')::TEXT AS user_display_name_en,
        COALESCE(he.name_ar, '')::TEXT AS user_display_name_ar,
        v_total AS total_count
    FROM pending_receiving_records r
    LEFT JOIN branches b ON b.id = r.branch_id
    LEFT JOIN vendors v ON v.erp_vendor_id = r.vendor_id AND v.branch_id = r.branch_id
    LEFT JOIN public.users u ON u.id = r.user_id
    LEFT JOIN public.hr_employee_master he ON he.user_id = r.user_id
    WHERE r.status = 'pending'
      AND (p_branch_id IS NULL OR r.branch_id::TEXT = p_branch_id)
      AND (p_vendor_search IS NULL OR p_vendor_search = '' OR LOWER(v.vendor_name) LIKE '%' || LOWER(p_vendor_search) || '%')
      AND (p_erp_ref_filter IS NULL OR p_erp_ref_filter = ''
           OR (p_erp_ref_filter = 'entered' AND r.erp_purchase_invoice_reference IS NOT NULL AND TRIM(r.erp_purchase_invoice_reference::TEXT) <> '')
           OR (p_erp_ref_filter = 'not_entered' AND (r.erp_purchase_invoice_reference IS NULL OR TRIM(r.erp_purchase_invoice_reference::TEXT) = '')))
      AND (p_erp_reference_search IS NULL OR p_erp_reference_search = '' OR LOWER(r.erp_purchase_invoice_reference::TEXT) LIKE '%' || LOWER(p_erp_reference_search) || '%')
      AND (p_bill_date_from IS NULL OR r.bill_date >= p_bill_date_from)
      AND (p_bill_date_to IS NULL OR r.bill_date <= p_bill_date_to)
    ORDER BY r.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_pending_receiving_records_with_details(integer, integer, text, text, text, text, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_receiving_records_with_details(integer, integer, text, text, text, text, date, date) TO anon;
GRANT EXECUTE ON FUNCTION public.get_pending_receiving_records_with_details(integer, integer, text, text, text, text, date, date) TO service_role;

-- =======================================================
-- 3. finalize_pending_receiving_record(...)
-- =======================================================
CREATE OR REPLACE FUNCTION public.finalize_pending_receiving_record(
  p_pending_id uuid,
  p_cleared_by_user_id uuid DEFAULT NULL::uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_rec RECORD;
BEGIN
  SELECT * INTO v_rec
  FROM pending_receiving_records
  WHERE id = p_pending_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Pending receiving record not found', 'error_code', 'RECORD_NOT_FOUND');
  END IF;

  IF v_rec.status = 'cleared' THEN
    RETURN json_build_object('success', false, 'error', 'Record already finalized', 'error_code', 'ALREADY_CLEARED');
  END IF;

  -- Copy into receiving_records, preserving the SAME id so the receiving_tasks
  -- created earlier (receiving_record_id = this id) remain correctly linked, and
  -- the calculate_receiving_amounts / auto_create_payment_schedule triggers on
  -- receiving_records fire normally for this now-official record.
  INSERT INTO receiving_records (
    id, user_id, branch_id, vendor_id, bill_date, bill_amount, bill_number, payment_method,
    credit_period, due_date, bank_name, iban, vendor_vat_number, bill_vat_number,
    vat_numbers_match, vat_mismatch_reason, branch_manager_user_id, shelf_stocker_user_ids,
    accountant_user_id, purchasing_manager_user_id, expired_return_amount, near_expiry_return_amount,
    over_stock_return_amount, damage_return_amount, expired_erp_document_type, expired_erp_document_number,
    expired_vendor_document_number, near_expiry_erp_document_type, near_expiry_erp_document_number,
    near_expiry_vendor_document_number, over_stock_erp_document_type, over_stock_erp_document_number,
    over_stock_vendor_document_number, damage_erp_document_type, damage_erp_document_number,
    damage_vendor_document_number, has_expired_returns, has_near_expiry_returns, has_over_stock_returns,
    has_damage_returns, created_at, inventory_manager_user_id, night_supervisor_user_ids,
    warehouse_handler_user_ids, certificate_url, certificate_generated_at, certificate_file_name,
    original_bill_url, erp_purchase_invoice_reference, updated_at, pr_excel_file_url,
    erp_purchase_invoice_uploaded, pr_excel_file_uploaded, original_bill_uploaded
  ) VALUES (
    v_rec.id, v_rec.user_id, v_rec.branch_id, v_rec.vendor_id, v_rec.bill_date, v_rec.bill_amount,
    v_rec.bill_number, v_rec.payment_method, v_rec.credit_period, v_rec.due_date, v_rec.bank_name,
    v_rec.iban, v_rec.vendor_vat_number, v_rec.bill_vat_number, v_rec.vat_numbers_match,
    v_rec.vat_mismatch_reason, v_rec.branch_manager_user_id, v_rec.shelf_stocker_user_ids,
    v_rec.accountant_user_id, v_rec.purchasing_manager_user_id, v_rec.expired_return_amount,
    v_rec.near_expiry_return_amount, v_rec.over_stock_return_amount, v_rec.damage_return_amount,
    v_rec.expired_erp_document_type, v_rec.expired_erp_document_number, v_rec.expired_vendor_document_number,
    v_rec.near_expiry_erp_document_type, v_rec.near_expiry_erp_document_number, v_rec.near_expiry_vendor_document_number,
    v_rec.over_stock_erp_document_type, v_rec.over_stock_erp_document_number, v_rec.over_stock_vendor_document_number,
    v_rec.damage_erp_document_type, v_rec.damage_erp_document_number, v_rec.damage_vendor_document_number,
    v_rec.has_expired_returns, v_rec.has_near_expiry_returns, v_rec.has_over_stock_returns, v_rec.has_damage_returns,
    v_rec.created_at, v_rec.inventory_manager_user_id, v_rec.night_supervisor_user_ids,
    v_rec.warehouse_handler_user_ids, v_rec.certificate_url, v_rec.certificate_generated_at,
    v_rec.certificate_file_name, v_rec.original_bill_url, v_rec.erp_purchase_invoice_reference,
    NOW(), v_rec.pr_excel_file_url, v_rec.erp_purchase_invoice_uploaded, v_rec.pr_excel_file_uploaded,
    v_rec.original_bill_uploaded
  );

  UPDATE pending_receiving_records
  SET status = 'cleared',
      cleared_at = NOW(),
      cleared_by_user_id = p_cleared_by_user_id,
      posted_receiving_record_id = v_rec.id,
      updated_at = NOW()
  WHERE id = p_pending_id;

  RETURN json_build_object('success', true, 'receiving_record_id', v_rec.id);

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM, 'error_code', 'INTERNAL_ERROR');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.finalize_pending_receiving_record(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_pending_receiving_record(uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.finalize_pending_receiving_record(uuid, uuid) TO service_role;
