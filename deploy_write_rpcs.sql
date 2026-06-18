-- ============================================================
-- ProductClaimManager Write RPCs
-- All 4 write operations done server-side (no URL limit, atomic)
-- ============================================================

-- 1. Move products from managed_by → in_process for an employee
DROP FUNCTION IF EXISTS public.transfer_product_claims(TEXT, TEXT[]);

CREATE OR REPLACE FUNCTION public.transfer_product_claims(
    p_employee_id TEXT,
    p_barcodes    TEXT[]
)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_count INTEGER;
    v_now   TEXT := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
BEGIN
    UPDATE erp_synced_products
    SET
        in_process = COALESCE(in_process, '[]'::JSONB) || (
            SELECT COALESCE(
                jsonb_agg(elem || jsonb_build_object('moved_at', v_now)),
                '[]'::JSONB
            )
            FROM jsonb_array_elements(managed_by) AS elem
            WHERE elem->>'employee_id' = p_employee_id
        ),
        managed_by = (
            SELECT COALESCE(jsonb_agg(elem), '[]'::JSONB)
            FROM jsonb_array_elements(managed_by) AS elem
            WHERE elem->>'employee_id' != p_employee_id
        )
    WHERE barcode = ANY(p_barcodes)
      AND managed_by IS NOT NULL
      AND managed_by != '[]'::JSONB;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_product_claims(TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transfer_product_claims(TEXT, TEXT[]) TO anon;

-- ============================================================

-- 2. Remove employee entries from managed_by (unclaim)
DROP FUNCTION IF EXISTS public.unclaim_products(TEXT, TEXT[], INTEGER);

CREATE OR REPLACE FUNCTION public.unclaim_products(
    p_employee_id TEXT,
    p_barcodes    TEXT[],
    p_branch_id   INTEGER DEFAULT NULL
)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE erp_synced_products
    SET managed_by = (
        SELECT COALESCE(jsonb_agg(elem), '[]'::JSONB)
        FROM jsonb_array_elements(managed_by) AS elem
        WHERE NOT (
            elem->>'employee_id' = p_employee_id
            AND (p_branch_id IS NULL OR (elem->>'branch_id')::INTEGER = p_branch_id)
        )
    )
    WHERE barcode = ANY(p_barcodes)
      AND managed_by IS NOT NULL;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.unclaim_products(TEXT, TEXT[], INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unclaim_products(TEXT, TEXT[], INTEGER) TO anon;

-- ============================================================

-- 3. Update branch_id in managed_by for an employee's products
-- p_branch_changes: [{"from_id": X, "to_id": Y}, ...]
DROP FUNCTION IF EXISTS public.manage_product_branch(TEXT, TEXT[], JSONB);

CREATE OR REPLACE FUNCTION public.manage_product_branch(
    p_employee_id   TEXT,
    p_barcodes      TEXT[],
    p_branch_changes JSONB
)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE erp_synced_products
    SET managed_by = (
        SELECT jsonb_agg(
            CASE
                WHEN elem->>'employee_id' = p_employee_id THEN
                    elem || jsonb_build_object(
                        'branch_id',
                        COALESCE(
                            (SELECT (chg->>'to_id')::INTEGER
                             FROM jsonb_array_elements(p_branch_changes) AS chg
                             WHERE (chg->>'from_id')::INTEGER = (elem->>'branch_id')::INTEGER
                             LIMIT 1),
                            (elem->>'branch_id')::INTEGER
                        )
                    )
                ELSE elem
            END
        )
        FROM jsonb_array_elements(managed_by) AS elem
    )
    WHERE barcode = ANY(p_barcodes)
      AND managed_by IS NOT NULL;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_product_branch(TEXT, TEXT[], JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.manage_product_branch(TEXT, TEXT[], JSONB) TO anon;

-- ============================================================

-- 4. Assign in_process products from one employee to another's managed_by
DROP FUNCTION IF EXISTS public.assign_in_process_products(TEXT, TEXT, TEXT[]);

CREATE OR REPLACE FUNCTION public.assign_in_process_products(
    p_old_employee_id TEXT,
    p_new_employee_id TEXT,
    p_barcodes        TEXT[]
)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_count INTEGER;
    v_now   TEXT := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
BEGIN
    UPDATE erp_synced_products
    SET
        in_process = (
            SELECT COALESCE(jsonb_agg(elem), '[]'::JSONB)
            FROM jsonb_array_elements(in_process) AS elem
            WHERE elem->>'employee_id' != p_old_employee_id
        ),
        managed_by = COALESCE(managed_by, '[]'::JSONB) || (
            SELECT COALESCE(
                jsonb_agg(
                    (elem - 'moved_at') ||
                    jsonb_build_object(
                        'employee_id', p_new_employee_id,
                        'claimed_at',  v_now
                    )
                ),
                '[]'::JSONB
            )
            FROM jsonb_array_elements(in_process) AS elem
            WHERE elem->>'employee_id' = p_old_employee_id
        )
    WHERE barcode = ANY(p_barcodes)
      AND in_process IS NOT NULL;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_in_process_products(TEXT, TEXT, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_in_process_products(TEXT, TEXT, TEXT[]) TO anon;
