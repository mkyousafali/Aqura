-- Fix Arabic localization for receiving records RPC
-- Returns Arabic branch/user fields that the UI can use when locale is Arabic.

DROP FUNCTION IF EXISTS public.get_receiving_records_with_details(
    INTEGER,
    INTEGER,
    TEXT,
    TEXT,
    TEXT,
    TEXT
);

CREATE OR REPLACE FUNCTION public.get_receiving_records_with_details(
    p_limit INTEGER DEFAULT 500,
    p_offset INTEGER DEFAULT 0,
    p_branch_id TEXT DEFAULT NULL,
    p_vendor_search TEXT DEFAULT NULL,
    p_pr_excel_filter TEXT DEFAULT NULL,
    p_erp_ref_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    id TEXT,
    bill_number TEXT,
    vendor_id TEXT,
    branch_id TEXT,
    bill_date DATE,
    bill_amount NUMERIC,
    created_at TIMESTAMPTZ,
    user_id TEXT,
    original_bill_url TEXT,
    erp_purchase_invoice_reference TEXT,
    certificate_url TEXT,
    due_date DATE,
    pr_excel_file_url TEXT,
    final_bill_amount NUMERIC,
    payment_method TEXT,
    credit_period INTEGER,
    bank_name TEXT,
    iban TEXT,
    branch_name_en TEXT,
    branch_name_ar TEXT,
    branch_location_en TEXT,
    branch_location_ar TEXT,
    vendor_name TEXT,
    vat_number TEXT,
    username TEXT,
    user_display_name TEXT,
    user_display_name_en TEXT,
    user_display_name_ar TEXT,
    is_scheduled BOOLEAN,
    is_paid BOOLEAN,
    pr_excel_verified BOOLEAN,
    pr_excel_verified_by TEXT,
    pr_excel_verified_date TIMESTAMPTZ,
    total_count BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM receiving_records r
    LEFT JOIN branches b ON b.id = r.branch_id
    LEFT JOIN vendors v ON v.erp_vendor_id = r.vendor_id AND v.branch_id = r.branch_id
    LEFT JOIN LATERAL (
        SELECT vps.pr_excel_verified
        FROM vendor_payment_schedule vps
        WHERE vps.receiving_record_id = r.id
        LIMIT 1
    ) ps_count ON true
    WHERE (p_branch_id IS NULL OR r.branch_id::TEXT = p_branch_id)
      AND (p_vendor_search IS NULL OR p_vendor_search = '' OR LOWER(v.vendor_name) LIKE '%' || LOWER(p_vendor_search) || '%')
      AND (p_pr_excel_filter IS NULL OR p_pr_excel_filter = ''
           OR (p_pr_excel_filter = 'verified' AND COALESCE(ps_count.pr_excel_verified, false) = true)
           OR (p_pr_excel_filter = 'unverified' AND COALESCE(ps_count.pr_excel_verified, false) = false))
      AND (p_erp_ref_filter IS NULL OR p_erp_ref_filter = ''
           OR (p_erp_ref_filter = 'entered' AND r.erp_purchase_invoice_reference IS NOT NULL AND TRIM(r.erp_purchase_invoice_reference::TEXT) <> '')
           OR (p_erp_ref_filter = 'not_entered' AND (r.erp_purchase_invoice_reference IS NULL OR TRIM(r.erp_purchase_invoice_reference::TEXT) = '')));

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
        r.due_date,
        r.pr_excel_file_url::TEXT,
        r.final_bill_amount,
        r.payment_method::TEXT,
        r.credit_period,
        r.bank_name::TEXT,
        r.iban::TEXT,
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
        (ps.receiving_record_id IS NOT NULL) AS is_scheduled,
        COALESCE(ps.is_paid, false) AS is_paid,
        COALESCE(ps.pr_excel_verified, false) AS pr_excel_verified,
        ps.pr_excel_verified_by::TEXT,
        ps.pr_excel_verified_date,
        v_total AS total_count
    FROM receiving_records r
    LEFT JOIN branches b ON b.id = r.branch_id
    LEFT JOIN vendors v ON v.erp_vendor_id = r.vendor_id AND v.branch_id = r.branch_id
    LEFT JOIN public.users u ON u.id = r.user_id
    LEFT JOIN public.hr_employee_master he ON he.user_id = r.user_id
    LEFT JOIN LATERAL (
        SELECT
            vps.receiving_record_id,
            vps.is_paid,
            vps.pr_excel_verified,
            vps.pr_excel_verified_by,
            vps.pr_excel_verified_date
        FROM vendor_payment_schedule vps
        WHERE vps.receiving_record_id = r.id
        LIMIT 1
    ) ps ON true
    WHERE (p_branch_id IS NULL OR r.branch_id::TEXT = p_branch_id)
      AND (p_vendor_search IS NULL OR p_vendor_search = '' OR LOWER(v.vendor_name) LIKE '%' || LOWER(p_vendor_search) || '%')
      AND (p_pr_excel_filter IS NULL OR p_pr_excel_filter = ''
           OR (p_pr_excel_filter = 'verified' AND COALESCE(ps.pr_excel_verified, false) = true)
           OR (p_pr_excel_filter = 'unverified' AND COALESCE(ps.pr_excel_verified, false) = false))
      AND (p_erp_ref_filter IS NULL OR p_erp_ref_filter = ''
           OR (p_erp_ref_filter = 'entered' AND r.erp_purchase_invoice_reference IS NOT NULL AND TRIM(r.erp_purchase_invoice_reference::TEXT) <> '')
           OR (p_erp_ref_filter = 'not_entered' AND (r.erp_purchase_invoice_reference IS NULL OR TRIM(r.erp_purchase_invoice_reference::TEXT) = '')))
    ORDER BY r.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_receiving_records_with_details(INTEGER, INTEGER, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_receiving_records_with_details(INTEGER, INTEGER, TEXT, TEXT, TEXT, TEXT) TO anon;
