BEGIN;

CREATE OR REPLACE FUNCTION public.get_bt_requests_with_details_filtered(
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_search text DEFAULT NULL,
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_branch_id integer DEFAULT NULL
) RETURNS TABLE(
    id uuid,
    requester_user_id uuid,
    from_branch_id integer,
    to_branch_id integer,
    target_user_id uuid,
    status text,
    items jsonb,
    document_url text,
    created_at timestamptz,
    updated_at timestamptz,
    requester_name_en text,
    requester_name_ar text,
    target_name_en text,
    target_name_ar text,
    from_branch_name_en text,
    from_branch_name_ar text,
    from_branch_location_en text,
    from_branch_location_ar text,
    to_branch_name_en text,
    to_branch_name_ar text,
    to_branch_location_en text,
    to_branch_location_ar text,
    assigned_im_user_id uuid,
    total_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
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
        COALESCE(req.name_en, req.user_id::text)::text,
        COALESCE(req.name_ar, req.name_en, req.user_id::text)::text,
        COALESCE(tgt.name_en, tgt.user_id::text)::text,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::text)::text,
        COALESCE(fb.name_en, '')::text,
        COALESCE(fb.name_ar, fb.name_en, '')::text,
        COALESCE(fb.location_en, '')::text,
        COALESCE(fb.location_ar, fb.location_en, '')::text,
        COALESCE(tb.name_en, '')::text,
        COALESCE(tb.name_ar, tb.name_en, '')::text,
        COALESCE(tb.location_en, '')::text,
        COALESCE(tb.location_ar, tb.location_en, '')::text,
        NULL::uuid,
        COUNT(*) OVER ()
    FROM public.product_request_bt r
    LEFT JOIN public.hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN public.hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN public.branches fb ON fb.id = r.from_branch_id
    LEFT JOIN public.branches tb ON tb.id = r.to_branch_id
    WHERE
        (p_status IS NULL OR p_status = '' OR r.status = p_status)
        AND (p_branch_id IS NULL OR r.to_branch_id = p_branch_id)
        AND (p_date_from IS NULL OR r.created_at::date >= p_date_from)
        AND (p_date_to IS NULL OR r.created_at::date <= p_date_to)
        AND (
            p_search IS NULL OR p_search = '' OR
            r.id::text ILIKE '%' || p_search || '%' OR
            req.name_en ILIKE '%' || p_search || '%' OR
            req.name_ar ILIKE '%' || p_search || '%' OR
            tgt.name_en ILIKE '%' || p_search || '%' OR
            fb.name_en ILIKE '%' || p_search || '%' OR
            tb.name_en ILIKE '%' || p_search || '%'
        )
    ORDER BY r.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
$$;

GRANT ALL ON FUNCTION public.get_bt_requests_with_details_filtered(integer, integer, text, text, date, date, integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_bt_requests_with_details_filtered(integer, integer, text, text, date, date, integer) TO anon;

COMMIT;
