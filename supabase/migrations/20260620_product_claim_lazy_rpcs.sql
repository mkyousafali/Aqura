-- ============================================================
-- Lazy-loading RPCs for ProductClaimManager
-- 1. get_product_claim_summaries  — fast initial load (no products array)
-- 2. get_employee_claim_products  — detail on-demand (one employee)
-- ============================================================

-- 1. Lightweight summary: employee_id, name, count, branch breakdown
CREATE OR REPLACE FUNCTION public.get_product_claim_summaries(p_locale TEXT DEFAULT 'en')
RETURNS TABLE(
    employee_id   TEXT,
    employee_name TEXT,
    product_count BIGINT,
    branch_counts JSONB
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH entries AS (
        SELECT
            e->>'employee_id' AS emp_id,
            e->>'branch_id'   AS branch_id
        FROM erp_synced_products,
             jsonb_array_elements(managed_by) AS e
        WHERE managed_by IS NOT NULL
          AND managed_by != '[]'::JSONB
          AND e->>'employee_id' IS NOT NULL
    ),
    branch_agg AS (
        SELECT
            emp_id,
            jsonb_object_agg(branch_id, cnt) AS branch_counts
        FROM (
            SELECT emp_id, branch_id, COUNT(*) AS cnt
            FROM entries
            GROUP BY emp_id, branch_id
        ) bc
        GROUP BY emp_id
    ),
    totals AS (
        SELECT emp_id, COUNT(*) AS product_count
        FROM entries
        GROUP BY emp_id
    )
    SELECT
        t.emp_id AS employee_id,
        COALESCE(
            CASE WHEN p_locale = 'ar' THEN hem.name_ar ELSE hem.name_en END,
            CASE WHEN p_locale = 'ar' THEN hem.name_en ELSE hem.name_ar END,
            t.emp_id
        )::TEXT AS employee_name,
        t.product_count,
        b.branch_counts
    FROM totals t
    JOIN branch_agg b ON b.emp_id = t.emp_id
    LEFT JOIN hr_employee_master hem ON hem.id = t.emp_id
    ORDER BY t.product_count DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_product_claim_summaries(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_product_claim_summaries(TEXT) TO anon;


-- 2. Products for a single employee (called when employee row is clicked)
CREATE OR REPLACE FUNCTION public.get_employee_claim_products(
    p_employee_id TEXT,
    p_locale      TEXT DEFAULT 'en'
)
RETURNS TABLE(
    barcode      TEXT,
    product_name TEXT,
    branch_id    INTEGER,
    claimed_at   TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        ep.barcode,
        CASE WHEN p_locale = 'ar'
            THEN COALESCE(ep.product_name_ar, ep.product_name_en, '')
            ELSE COALESCE(ep.product_name_en, ep.product_name_ar, '')
        END AS product_name,
        (e->>'branch_id')::INTEGER AS branch_id,
        e->>'claimed_at'           AS claimed_at
    FROM erp_synced_products ep,
         jsonb_array_elements(ep.managed_by) AS e
    WHERE ep.managed_by IS NOT NULL
      AND ep.managed_by != '[]'::JSONB
      AND e->>'employee_id' = p_employee_id
    ORDER BY (e->>'claimed_at') DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_employee_claim_products(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_employee_claim_products(TEXT, TEXT) TO anon;
