BEGIN;

DROP FUNCTION IF EXISTS public.get_near_expiry_reports(integer, integer, text, text, date, date);

CREATE FUNCTION public.get_near_expiry_reports(
    p_limit integer DEFAULT 200,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_search text DEFAULT NULL,
    p_branch_id integer DEFAULT NULL,
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL
) RETURNS TABLE(
    id uuid, reporter_user_id uuid, branch_id integer, target_user_id uuid,
    title text, status text, items jsonb, notes text,
    created_at timestamptz, updated_at timestamptz,
    requester_name_en text, requester_name_ar text,
    target_name_en text, target_name_ar text,
    branch_name_en text, branch_name_ar text,
    branch_location_en text, branch_location_ar text,
    total_count bigint
)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public'
AS $$
    SELECT
        r.id, r.reporter_user_id, r.branch_id, r.target_user_id,
        r.title::text, r.status::text, r.items, r.notes::text,
        r.created_at, r.updated_at,
        COALESCE(req.name_en, req.user_id::text)::text,
        COALESCE(req.name_ar, req.name_en, req.user_id::text)::text,
        COALESCE(tgt.name_en, tgt.user_id::text)::text,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::text)::text,
        COALESCE(b.name_en, '')::text,
        COALESCE(b.name_ar, b.name_en, '')::text,
        COALESCE(b.location_en, '')::text,
        COALESCE(b.location_ar, b.location_en, '')::text,
        COUNT(*) OVER ()
    FROM near_expiry_reports r
    LEFT JOIN hr_employee_master req ON req.user_id = r.reporter_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches b ON b.id = r.branch_id
    WHERE
        (p_status IS NULL OR p_status = 'all' OR r.status = p_status)
        AND (p_branch_id IS NULL OR r.branch_id = p_branch_id)
        AND (p_date_from IS NULL OR r.created_at::date >= p_date_from)
        AND (p_date_to IS NULL OR r.created_at::date <= p_date_to)
        AND (
            p_search IS NULL OR p_search = '' OR
            r.id::text ILIKE '%' || p_search || '%' OR
            r.title ILIKE '%' || p_search || '%' OR
            req.name_en ILIKE '%' || p_search || '%' OR
            req.name_ar ILIKE '%' || p_search || '%' OR
            b.name_en ILIKE '%' || p_search || '%'
        )
    ORDER BY r.created_at DESC
    LIMIT p_limit OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.get_near_expiry_reports(integer, integer, text, text, integer, date, date) TO anon, authenticated, service_role;

COMMIT;
