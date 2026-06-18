CREATE OR REPLACE FUNCTION public.get_product_in_process(
    p_locale TEXT DEFAULT 'en'
)
RETURNS TABLE(
    barcode         TEXT,
    product_name    TEXT,
    employee_id     TEXT,
    employee_name   TEXT,
    branch_id       INTEGER,
    claimed_at      TEXT,
    moved_at        TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_product RECORD;
    v_in_process JSONB;
    v_entry JSONB;
    v_product_name TEXT;
BEGIN
    -- Fetch all products with in_process entries
    FOR v_product IN 
        SELECT barcode, product_name_en, product_name_ar, in_process 
        FROM erp_synced_products
        WHERE in_process IS NOT NULL AND in_process != '[]'::JSONB
    LOOP
        -- Parse in_process array
        IF v_product.in_process IS NOT NULL AND jsonb_array_length(v_product.in_process) > 0 THEN
            -- Determine product name based on locale
            v_product_name := CASE 
                WHEN p_locale = 'ar' THEN COALESCE(v_product.product_name_ar, v_product.product_name_en, '')
                ELSE COALESCE(v_product.product_name_en, v_product.product_name_ar, '')
            END;
            
            -- Iterate through in_process entries and return results
            RETURN QUERY
            SELECT 
                v_product.barcode,
                v_product_name,
                v_entry->>'employee_id' AS employee_id,
                COALESCE(
                    CASE WHEN p_locale = 'ar' THEN hem.name_ar ELSE hem.name_en END,
                    CASE WHEN p_locale = 'ar' THEN hem.name_en ELSE hem.name_ar END,
                    v_entry->>'employee_id'
                )::TEXT AS employee_name,
                (v_entry->>'branch_id')::INTEGER AS branch_id,
                v_entry->>'claimed_at' AS claimed_at,
                v_entry->>'moved_at' AS moved_at
            FROM jsonb_array_elements(v_product.in_process) AS v_entry
            LEFT JOIN hr_employee_master hem ON hem.id = v_entry->>'employee_id'
            WHERE v_entry->>'employee_id' IS NOT NULL
            ORDER BY v_entry->>'moved_at' DESC NULLS LAST;
        END IF;
    END LOOP;
END;
$$;
