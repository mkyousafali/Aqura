CREATE OR REPLACE FUNCTION public.get_bt_requests_with_details(
    p_limit     INT     DEFAULT 100,
    p_offset    INT     DEFAULT 0,
    p_status    TEXT    DEFAULT NULL,
    p_search    TEXT    DEFAULT NULL,
    p_date_from DATE    DEFAULT NULL,
    p_date_to   DATE    DEFAULT NULL
)
RETURNS TABLE(
    id                      UUID,
    requester_user_id       UUID,
    from_branch_id          INTEGER,
    to_branch_id            INTEGER,
    target_user_id          UUID,
    status                  TEXT,
    items                   JSONB,
    document_url            TEXT,
    created_at              TIMESTAMPTZ,
    updated_at              TIMESTAMPTZ,
    requester_name_en       TEXT,
    requester_name_ar       TEXT,
    target_name_en          TEXT,
    target_name_ar          TEXT,
    from_branch_name_en     TEXT,
    from_branch_name_ar     TEXT,
    from_branch_location_en TEXT,
    from_branch_location_ar TEXT,
    to_branch_name_en       TEXT,
    to_branch_name_ar       TEXT,
    to_branch_location_en   TEXT,
    to_branch_location_ar   TEXT,
    assigned_im_user_id     UUID,
    total_count             BIGINT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
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
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT  AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT  AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        COALESCE(fb.name_en, '')::TEXT      AS from_branch_name_en,
        COALESCE(fb.name_ar, fb.name_en, '')::TEXT AS from_branch_name_ar,
        COALESCE(fb.location_en, '')::TEXT  AS from_branch_location_en,
        COALESCE(fb.location_ar, fb.location_en, '')::TEXT AS from_branch_location_ar,
        COALESCE(tb.name_en, '')::TEXT      AS to_branch_name_en,
        COALESCE(tb.name_ar, tb.name_en, '')::TEXT AS to_branch_name_ar,
        COALESCE(tb.location_en, '')::TEXT  AS to_branch_location_en,
        COALESCE(tb.location_ar, tb.location_en, '')::TEXT AS to_branch_location_ar,
        NULL::UUID                          AS assigned_im_user_id,
        COUNT(*) OVER ()                    AS total_count
    FROM product_request_bt r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches fb ON fb.id = r.from_branch_id
    LEFT JOIN branches tb ON tb.id = r.to_branch_id
    WHERE
        (p_status IS NULL OR p_status = '' OR r.status = p_status)
        AND (p_date_from IS NULL OR r.created_at::DATE >= p_date_from)
        AND (p_date_to   IS NULL OR r.created_at::DATE <= p_date_to)
        AND (
            p_search IS NULL OR p_search = '' OR
            r.id::TEXT ILIKE '%' || p_search || '%' OR
            req.name_en ILIKE '%' || p_search || '%' OR
            req.name_ar ILIKE '%' || p_search || '%' OR
            tgt.name_en ILIKE '%' || p_search || '%' OR
            fb.name_en  ILIKE '%' || p_search || '%' OR
            tb.name_en  ILIKE '%' || p_search || '%'
        )
    ORDER BY r.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.get_bt_requests_with_details(INT, INT, TEXT, TEXT, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_bt_requests_with_details(INT, INT, TEXT, TEXT, DATE, DATE) TO anon;
