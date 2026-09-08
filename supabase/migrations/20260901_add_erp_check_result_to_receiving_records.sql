-- Persists the live ERP Check (vendor ID + amount match) result from ReceivingRecords.svelte
-- as JSONB, so a "Matched" verdict survives page reloads instead of resetting to a bare
-- "Check ERP" button every time the window is reopened.
ALTER TABLE public.receiving_records ADD COLUMN IF NOT EXISTS erp_check_result jsonb;

DROP FUNCTION IF EXISTS public.get_receiving_records_with_details(integer, integer, text, text, text, text, text, date, date);

CREATE FUNCTION public.get_receiving_records_with_details(
    p_limit integer DEFAULT 500, p_offset integer DEFAULT 0,
    p_branch_id text DEFAULT NULL, p_vendor_search text DEFAULT NULL,
    p_pr_excel_filter text DEFAULT NULL, p_erp_ref_filter text DEFAULT NULL,
    p_erp_reference_search text DEFAULT NULL,
    p_bill_date_from date DEFAULT NULL,
    p_bill_date_to date DEFAULT NULL
) RETURNS TABLE(
    id text, bill_number text, vendor_id text, branch_id text, bill_date date,
    bill_amount numeric, created_at timestamptz, user_id text, original_bill_url text,
    erp_purchase_invoice_reference text, certificate_url text, due_date date,
    pr_excel_file_url text, final_bill_amount numeric, payment_method text,
    credit_period integer, bank_name text, iban text, branch_name_en text,
    branch_name_ar text, branch_location_en text, branch_location_ar text,
    vendor_name text, vat_number text, username text, user_display_name text,
    user_display_name_en text, user_display_name_ar text, is_scheduled boolean,
    is_paid boolean, pr_excel_verified boolean, pr_excel_verified_by text,
    pr_excel_verified_date timestamptz, erp_check_result jsonb, total_count bigint
) LANGUAGE plpgsql STABLE AS $$
DECLARE v_total bigint;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM receiving_records r
    LEFT JOIN vendors v ON v.erp_vendor_id = r.vendor_id AND v.branch_id = r.branch_id
    LEFT JOIN LATERAL (
        SELECT vps.pr_excel_verified FROM vendor_payment_schedule vps
        WHERE vps.receiving_record_id = r.id LIMIT 1
    ) ps_count ON true
    WHERE (p_branch_id IS NULL OR r.branch_id::text = p_branch_id)
      AND (p_vendor_search IS NULL OR p_vendor_search = '' OR v.vendor_name ILIKE '%' || p_vendor_search || '%')
      AND (p_pr_excel_filter IS NULL OR p_pr_excel_filter = ''
           OR (p_pr_excel_filter = 'verified' AND COALESCE(ps_count.pr_excel_verified, false))
           OR (p_pr_excel_filter = 'unverified' AND NOT COALESCE(ps_count.pr_excel_verified, false)))
      AND (p_erp_ref_filter IS NULL OR p_erp_ref_filter = ''
           OR (p_erp_ref_filter = 'entered' AND NULLIF(TRIM(r.erp_purchase_invoice_reference::text), '') IS NOT NULL)
           OR (p_erp_ref_filter = 'not_entered' AND NULLIF(TRIM(r.erp_purchase_invoice_reference::text), '') IS NULL))
      AND (p_erp_reference_search IS NULL OR p_erp_reference_search = ''
           OR r.erp_purchase_invoice_reference::text ILIKE '%' || p_erp_reference_search || '%')
      AND (p_bill_date_from IS NULL OR r.bill_date >= p_bill_date_from)
      AND (p_bill_date_to IS NULL OR r.bill_date <= p_bill_date_to);

    RETURN QUERY
    SELECT r.id::text, r.bill_number::text, r.vendor_id::text, r.branch_id::text,
        r.bill_date, r.bill_amount, r.created_at, r.user_id::text,
        r.original_bill_url::text, r.erp_purchase_invoice_reference::text,
        r.certificate_url::text, r.due_date, r.pr_excel_file_url::text,
        r.final_bill_amount, r.payment_method::text, r.credit_period,
        r.bank_name::text, r.iban::text,
        COALESCE(b.name_en, 'N/A')::text, COALESCE(b.name_ar, b.name_en, 'N/A')::text,
        COALESCE(b.location_en, '')::text, COALESCE(b.location_ar, b.location_en, '')::text,
        COALESCE(v.vendor_name, 'N/A')::text, v.vat_number::text,
        COALESCE(u.username, '')::text,
        COALESCE(he.name_en, he.name_ar, u.username, '')::text,
        COALESCE(he.name_en, '')::text, COALESCE(he.name_ar, '')::text,
        (ps.receiving_record_id IS NOT NULL), COALESCE(ps.is_paid, false),
        COALESCE(ps.pr_excel_verified, false), ps.pr_excel_verified_by::text,
        ps.pr_excel_verified_date, r.erp_check_result, v_total
    FROM receiving_records r
    LEFT JOIN branches b ON b.id = r.branch_id
    LEFT JOIN vendors v ON v.erp_vendor_id = r.vendor_id AND v.branch_id = r.branch_id
    LEFT JOIN public.users u ON u.id = r.user_id
    LEFT JOIN public.hr_employee_master he ON he.user_id = r.user_id
    LEFT JOIN LATERAL (
        SELECT vps.receiving_record_id, vps.is_paid, vps.pr_excel_verified,
            vps.pr_excel_verified_by, vps.pr_excel_verified_date
        FROM vendor_payment_schedule vps WHERE vps.receiving_record_id = r.id LIMIT 1
    ) ps ON true
    WHERE (p_branch_id IS NULL OR r.branch_id::text = p_branch_id)
      AND (p_vendor_search IS NULL OR p_vendor_search = '' OR v.vendor_name ILIKE '%' || p_vendor_search || '%')
      AND (p_pr_excel_filter IS NULL OR p_pr_excel_filter = ''
           OR (p_pr_excel_filter = 'verified' AND COALESCE(ps.pr_excel_verified, false))
           OR (p_pr_excel_filter = 'unverified' AND NOT COALESCE(ps.pr_excel_verified, false)))
      AND (p_erp_ref_filter IS NULL OR p_erp_ref_filter = ''
           OR (p_erp_ref_filter = 'entered' AND NULLIF(TRIM(r.erp_purchase_invoice_reference::text), '') IS NOT NULL)
           OR (p_erp_ref_filter = 'not_entered' AND NULLIF(TRIM(r.erp_purchase_invoice_reference::text), '') IS NULL))
      AND (p_erp_reference_search IS NULL OR p_erp_reference_search = ''
           OR r.erp_purchase_invoice_reference::text ILIKE '%' || p_erp_reference_search || '%')
      AND (p_bill_date_from IS NULL OR r.bill_date >= p_bill_date_from)
      AND (p_bill_date_to IS NULL OR r.bill_date <= p_bill_date_to)
    ORDER BY r.created_at DESC LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_receiving_records_with_details(integer, integer, text, text, text, text, text, date, date)
TO anon, authenticated, service_role;
