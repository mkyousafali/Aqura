CREATE OR REPLACE FUNCTION public.get_po_requests_with_details(
    p_limit      INT     DEFAULT 100,
    p_offset     INT     DEFAULT 0,
    p_status     TEXT    DEFAULT NULL,
    p_search     TEXT    DEFAULT NULL,
    p_branch_id  INT     DEFAULT NULL,
    p_date_from  DATE    DEFAULT NULL,
    p_date_to    DATE    DEFAULT NULL
)
RETURNS TABLE(
    id                  UUID,
    requester_user_id   UUID,
    from_branch_id      INTEGER,
    target_user_id      UUID,
    status              VARCHAR,
    items               JSONB,
    document_url        TEXT,
    created_at          TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ,
    requester_name_en   TEXT,
    requester_name_ar   TEXT,
    target_name_en      TEXT,
    target_name_ar      TEXT,
    branch_name_en      TEXT,
    branch_name_ar      TEXT,
    branch_location_en  TEXT,
    branch_location_ar  TEXT,
    total_count         BIGINT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
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
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT  AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT  AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        COALESCE(b.name_en, '')::TEXT      AS branch_name_en,
        COALESCE(b.name_ar, b.name_en, '')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT  AS branch_location_en,
        COALESCE(b.location_ar, b.location_en, '')::TEXT AS branch_location_ar,
        COUNT(*) OVER ()                   AS total_count
    FROM product_request_po r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches b ON b.id = r.from_branch_id
    WHERE
        (p_status IS NULL OR p_status = 'all' OR r.status = p_status)
        AND (p_branch_id IS NULL OR r.from_branch_id = p_branch_id)
        AND (p_date_from IS NULL OR r.created_at::DATE >= p_date_from)
        AND (p_date_to   IS NULL OR r.created_at::DATE <= p_date_to)
        AND (
            p_search IS NULL OR p_search = '' OR
            r.id::TEXT ILIKE '%' || p_search || '%' OR
            req.name_en ILIKE '%' || p_search || '%' OR
            req.name_ar ILIKE '%' || p_search || '%' OR
            tgt.name_en ILIKE '%' || p_search || '%' OR
            b.name_en   ILIKE '%' || p_search || '%'
        )
    ORDER BY r.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.get_po_requests_with_details(INT, INT, TEXT, TEXT, INT, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_po_requests_with_details(INT, INT, TEXT, TEXT, INT, DATE, DATE) TO anon;
