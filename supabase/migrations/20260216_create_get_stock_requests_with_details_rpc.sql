-- RPC function to get stock transfer requests with all related details in a single query
-- Replaces 3 separate client-side queries (product_request_st, hr_employee_master, branches)
-- Returns all data joined server-side for faster loading

CREATE OR REPLACE FUNCTION get_stock_requests_with_details()
RETURNS TABLE (
    id UUID,
    requester_user_id UUID,
    branch_id INTEGER,
    target_user_id UUID,
    status VARCHAR,
    items JSONB,
    document_url TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    -- Requester details
    requester_name_en TEXT,
    requester_name_ar TEXT,
    -- Target user details
    target_name_en TEXT,
    target_name_ar TEXT,
    -- Branch details
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
        r.document_url,
        r.created_at,
        r.updated_at,
        -- Requester name
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        -- Target name
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        -- Branch info
        COALESCE(b.name_en, '')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, b.name_en, '')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, b.location_en, '')::TEXT AS branch_location_ar
    FROM product_request_st r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches b ON b.id = r.branch_id
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_stock_requests_with_details() TO authenticated;
GRANT EXECUTE ON FUNCTION get_stock_requests_with_details() TO anon;
