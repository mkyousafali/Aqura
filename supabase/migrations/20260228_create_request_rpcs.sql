-- RPC functions for PO, BT, and Customer request loading
-- Each replaces 3 separate client-side queries (requests + employees + branches)
-- with a single server-side JOIN query

-- =====================================================
-- RPC: get_po_requests_with_details
-- =====================================================
CREATE OR REPLACE FUNCTION get_po_requests_with_details()
RETURNS TABLE (
    id UUID,
    requester_user_id UUID,
    from_branch_id INTEGER,
    target_user_id UUID,
    status VARCHAR,
    items JSONB,
    document_url TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    requester_name_en TEXT,
    requester_name_ar TEXT,
    target_name_en TEXT,
    target_name_ar TEXT,
    branch_name_en TEXT,
    branch_name_ar TEXT,
    branch_location_en TEXT,
    branch_location_ar TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.requester_user_id,
        r.from_branch_id,
        r.target_user_id,
        r.status,
        r.items,
        r.document_url,
        r.created_at,
        r.updated_at,
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        COALESCE(b.name_en, '')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, b.name_en, '')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, b.location_en, '')::TEXT AS branch_location_ar
    FROM product_request_po r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches b ON b.id = r.from_branch_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_po_requests_with_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_po_requests_with_details() TO anon;

-- =====================================================
-- RPC: get_bt_requests_with_details
-- =====================================================
CREATE OR REPLACE FUNCTION get_bt_requests_with_details()
RETURNS TABLE (
    id UUID,
    requester_user_id UUID,
    from_branch_id INTEGER,
    to_branch_id INTEGER,
    target_user_id UUID,
    status VARCHAR,
    items JSONB,
    document_url TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    requester_name_en TEXT,
    requester_name_ar TEXT,
    target_name_en TEXT,
    target_name_ar TEXT,
    from_branch_name_en TEXT,
    from_branch_name_ar TEXT,
    from_branch_location_en TEXT,
    from_branch_location_ar TEXT,
    to_branch_name_en TEXT,
    to_branch_name_ar TEXT,
    to_branch_location_en TEXT,
    to_branch_location_ar TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.requester_user_id,
        r.from_branch_id,
        r.to_branch_id,
        r.target_user_id,
        r.status,
        r.items,
        r.document_url,
        r.created_at,
        r.updated_at,
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        COALESCE(fb.name_en, '')::TEXT AS from_branch_name_en,
        COALESCE(fb.name_ar, fb.name_en, '')::TEXT AS from_branch_name_ar,
        COALESCE(fb.location_en, '')::TEXT AS from_branch_location_en,
        COALESCE(fb.location_ar, fb.location_en, '')::TEXT AS from_branch_location_ar,
        COALESCE(tb.name_en, '')::TEXT AS to_branch_name_en,
        COALESCE(tb.name_ar, tb.name_en, '')::TEXT AS to_branch_name_ar,
        COALESCE(tb.location_en, '')::TEXT AS to_branch_location_en,
        COALESCE(tb.location_ar, tb.location_en, '')::TEXT AS to_branch_location_ar
    FROM product_request_bt r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches fb ON fb.id = r.from_branch_id
    LEFT JOIN branches tb ON tb.id = r.to_branch_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_bt_requests_with_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_bt_requests_with_details() TO anon;

-- =====================================================
-- RPC: get_customer_requests_with_details
-- =====================================================
CREATE OR REPLACE FUNCTION get_customer_requests_with_details()
RETURNS TABLE (
    id UUID,
    requester_user_id UUID,
    branch_id INTEGER,
    target_user_id UUID,
    status TEXT,
    items JSONB,
    notes TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    requester_name_en TEXT,
    requester_name_ar TEXT,
    target_name_en TEXT,
    target_name_ar TEXT,
    branch_name_en TEXT,
    branch_name_ar TEXT,
    branch_location_en TEXT,
    branch_location_ar TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.requester_user_id,
        r.branch_id,
        r.target_user_id,
        r.status,
        r.items,
        r.notes,
        r.created_at,
        r.updated_at,
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        COALESCE(b.name_en, '')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, b.name_en, '')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, b.location_en, '')::TEXT AS branch_location_ar
    FROM customer_product_requests r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches b ON b.id = r.branch_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_customer_requests_with_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_customer_requests_with_details() TO anon;

-- =====================================================
-- RPC: get_bt_assigned_ims
-- Retrieves the assigned Inventory Manager for BT requests
-- =====================================================
CREATE OR REPLACE FUNCTION get_bt_assigned_ims(p_request_ids UUID[])
RETURNS TABLE (
    product_request_id UUID,
    assigned_to_user_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        qt.product_request_id,
        qta.assigned_to_user_id
    FROM quick_tasks qt
    INNER JOIN quick_task_assignments qta ON qta.quick_task_id = qt.id
    WHERE qt.product_request_type = 'BT'
    AND qt.product_request_id = ANY(p_request_ids);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_bt_assigned_ims(UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_bt_assigned_ims(UUID[]) TO anon;
