-- ============================================================
-- RPC 1: get_employee_dup_counts
-- Returns per-employee duplicate barcode count in managed_by.
-- A duplicate = same (employee_id, branch_id) on the same barcode more than once.
-- ============================================================
DROP FUNCTION IF EXISTS public.get_employee_dup_counts();

CREATE OR REPLACE FUNCTION public.get_employee_dup_counts()
RETURNS TABLE(employee_id TEXT, dup_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        sub.emp_id AS employee_id,
        SUM(sub.cnt - 1)::BIGINT AS dup_count
    FROM (
        SELECT
            elem->>'employee_id' AS emp_id,
            COUNT(*) AS cnt
        FROM erp_synced_products,
             jsonb_array_elements(managed_by) AS elem
        WHERE managed_by IS NOT NULL
          AND managed_by != '[]'::JSONB
        GROUP BY barcode, elem->>'employee_id', (elem->>'branch_id')::INTEGER
        HAVING COUNT(*) > 1
    ) sub
    WHERE sub.emp_id IS NOT NULL
    GROUP BY sub.emp_id
    ORDER BY dup_count DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_employee_dup_counts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_employee_dup_counts() TO anon;

-- ============================================================
-- RPC 2: clean_employee_duplicates
-- Removes duplicate managed_by entries for a specific employee,
-- keeping only the earliest claimed_at per (barcode, branch_id).
-- Returns the number of product rows updated.
-- ============================================================
DROP FUNCTION IF EXISTS public.clean_employee_duplicates(TEXT);

CREATE OR REPLACE FUNCTION public.clean_employee_duplicates(p_employee_id TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count   INTEGER := 0;
    v_rec     RECORD;
    v_deduped JSONB;
BEGIN
    -- Iterate only products where this employee has duplicate (same branch) entries
    FOR v_rec IN
        SELECT barcode, managed_by
        FROM erp_synced_products
        WHERE managed_by IS NOT NULL
          AND EXISTS (
              SELECT 1
              FROM jsonb_array_elements(managed_by) AS e
              WHERE e->>'employee_id' = p_employee_id
              GROUP BY (e->>'branch_id')::INTEGER
              HAVING COUNT(*) > 1
          )
        FOR UPDATE
    LOOP
        -- Build deduplicated array:
        --   1. All entries for OTHER employees — unchanged
        --   2. For THIS employee — keep only earliest claimed_at per branch
        SELECT jsonb_agg(entry) INTO v_deduped
        FROM (
            SELECT e AS entry
            FROM jsonb_array_elements(v_rec.managed_by) AS e
            WHERE e->>'employee_id' != p_employee_id

            UNION ALL

            SELECT entry FROM (
                SELECT DISTINCT ON ((e->>'branch_id')::INTEGER)
                    e AS entry
                FROM jsonb_array_elements(v_rec.managed_by) AS e
                WHERE e->>'employee_id' = p_employee_id
                ORDER BY (e->>'branch_id')::INTEGER, (e->>'claimed_at') ASC
            ) sub
        ) deduped;

        UPDATE erp_synced_products
        SET managed_by = v_deduped
        WHERE barcode = v_rec.barcode;

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.clean_employee_duplicates(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clean_employee_duplicates(TEXT) TO anon;
