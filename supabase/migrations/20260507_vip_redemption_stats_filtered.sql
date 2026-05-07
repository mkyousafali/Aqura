-- Drop old signature so we can change params
DROP FUNCTION IF EXISTS public.get_vip_redemption_stats();
DROP FUNCTION IF EXISTS public.get_vip_redemption_stats(text, text, text, text);

CREATE OR REPLACE FUNCTION public.get_vip_redemption_stats(
    p_from      text DEFAULT NULL,   -- 'YYYY-MM-DD' inclusive (matches redeemed_date)
    p_to        text DEFAULT NULL,   -- 'YYYY-MM-DD' inclusive
    p_branch_id text DEFAULT NULL,   -- branches.id as text, '' or NULL = all
    p_search    text DEFAULT NULL    -- matches whatsapp_number OR bill_number
)
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
WITH params AS (
    SELECT
        NULLIF(p_from, '')::date      AS p_from_d,
        NULLIF(p_to, '')::date        AS p_to_d,
        NULLIF(p_branch_id, '')       AS p_branch,
        NULLIF(TRIM(p_search), '')    AS p_q
),
filtered AS (
    SELECT vr.*
    FROM vip_redemptions vr, params
    WHERE (params.p_from_d IS NULL OR vr.redeemed_date >= params.p_from_d)
      AND (params.p_to_d   IS NULL OR vr.redeemed_date <= params.p_to_d)
      AND (params.p_branch IS NULL OR vr.branch_id = params.p_branch)
      AND (
            params.p_q IS NULL
         OR vr.whatsapp_number ILIKE '%' || params.p_q || '%'
         OR vr.bill_number     ILIKE '%' || params.p_q || '%'
          )
)
SELECT json_build_object(
    'total_redemptions',  (SELECT COUNT(*)                                 FROM filtered),
    'today_redemptions',  (SELECT COUNT(*)                                 FROM filtered WHERE redeemed_date = CURRENT_DATE),
    'total_discount',     (SELECT COALESCE(SUM(discounted_value), 0)       FROM filtered),
    'today_discount',     (SELECT COALESCE(SUM(discounted_value), 0)       FROM filtered WHERE redeemed_date = CURRENT_DATE),
    'total_bill_amount',  (SELECT COALESCE(SUM(bill_amount), 0)            FROM filtered),
    'today_bill_amount',  (SELECT COALESCE(SUM(bill_amount), 0)            FROM filtered WHERE redeemed_date = CURRENT_DATE),
    'recent', (
        SELECT COALESCE(json_agg(r ORDER BY r.redeemed_at DESC), '[]'::json)
        FROM (
            SELECT
                f.id,
                f.whatsapp_number,
                f.bill_number,
                f.bill_amount,
                f.discounted_value,
                f.redeemed_date,
                f.redeemed_at,
                f.cashier_id,
                COALESCE(emp.name_en, f.cashier_id, '-') AS cashier_name_en,
                COALESCE(emp.name_ar, f.cashier_id, '-') AS cashier_name_ar,
                f.branch_id,
                br.name_en      AS branch_name_en,
                br.name_ar      AS branch_name_ar,
                br.location_en  AS branch_location_en,
                br.location_ar  AS branch_location_ar
            FROM filtered f
            LEFT JOIN hr_employee_master emp ON emp.user_id::text = f.cashier_id
            LEFT JOIN branches br            ON br.id::text       = f.branch_id
            ORDER BY f.redeemed_at DESC
            LIMIT 500
        ) r
    )
);
$$;

GRANT EXECUTE ON FUNCTION public.get_vip_redemption_stats(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_vip_redemption_stats(text, text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_vip_redemption_stats(text, text, text, text) TO service_role;

-- Smoke test
SELECT (public.get_vip_redemption_stats()::jsonb) -> 'total_redemptions' AS total,
       (public.get_vip_redemption_stats()::jsonb) -> 'total_bill_amount' AS bill_total;
