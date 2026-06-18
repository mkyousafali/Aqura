CREATE OR REPLACE FUNCTION public.get_product_claims(
    p_locale TEXT DEFAULT 'en'
)
RETURNS TABLE(
    employee_id         TEXT,
    employee_name       TEXT,
    product_count       INTEGER,
    branch_counts       JSONB,
    products            JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_employee_map JSONB := '{}'::JSONB;
    v_product RECORD;
    v_managed_by JSONB;
    v_entry JSONB;
    v_emp_id TEXT;
    v_branch_id INTEGER;
    v_product_name TEXT;
    v_claimed_at TEXT;
    v_emp_data JSONB;
    v_products_arr JSONB;
    v_branch_counts JSONB;
    v_emp_rec RECORD;
    v_branch_rec RECORD;
BEGIN
    -- Fetch all products with managed_by entries
    FOR v_product IN 
        SELECT barcode, product_name_en, product_name_ar, managed_by 
        FROM erp_synced_products
        WHERE managed_by IS NOT NULL AND managed_by != '[]'::JSONB
    LOOP
        -- Parse managed_by array
        IF v_product.managed_by IS NOT NULL AND jsonb_array_length(v_product.managed_by) > 0 THEN
            -- Determine product name based on locale
            v_product_name := CASE 
                WHEN p_locale = 'ar' THEN COALESCE(v_product.product_name_ar, v_product.product_name_en, '')
                ELSE COALESCE(v_product.product_name_en, v_product.product_name_ar, '')
            END;
            
            -- Iterate through managed_by entries
            FOR v_entry IN SELECT jsonb_array_elements(v_product.managed_by)
            LOOP
                v_emp_id := v_entry->>'employee_id';
                v_branch_id := (v_entry->>'branch_id')::INTEGER;
                v_claimed_at := v_entry->>'claimed_at';
                
                IF v_emp_id IS NOT NULL THEN
                    -- Initialize employee entry if not exists
                    IF NOT v_employee_map ? v_emp_id THEN
                        v_employee_map := v_employee_map || jsonb_build_object(
                            v_emp_id, jsonb_build_object(
                                'products', '[]'::JSONB,
                                'branch_counts', '{}'::JSONB
                            )
                        );
                    END IF;
                    
                    -- Get current employee data
                    v_emp_data := v_employee_map->v_emp_id;
                    v_products_arr := v_emp_data->'products';
                    v_branch_counts := v_emp_data->'branch_counts';
                    
                    -- Add product
                    v_products_arr := v_products_arr || jsonb_build_object(
                        'barcode', v_product.barcode,
                        'product_name', v_product_name,
                        'branch_id', v_branch_id,
                        'claimed_at', v_claimed_at
                    );
                    
                    -- Update branch count
                    v_branch_counts := CASE 
                        WHEN v_branch_counts ? v_branch_id::TEXT THEN 
                            v_branch_counts || jsonb_build_object(v_branch_id::TEXT, (v_branch_counts->>v_branch_id::TEXT)::INTEGER + 1)
                        ELSE 
                            v_branch_counts || jsonb_build_object(v_branch_id::TEXT, 1)
                    END;
                    
                    -- Update employee map
                    v_employee_map := jsonb_set(
                        v_employee_map,
                        ARRAY[v_emp_id],
                        jsonb_build_object(
                            'products', v_products_arr,
                            'branch_counts', v_branch_counts
                        )
                    );
                END IF;
            END LOOP;
        END IF;
    END LOOP;
    
    -- Fetch employee names and return results
    RETURN QUERY
    SELECT 
        key AS employee_id,
        COALESCE(
            CASE WHEN p_locale = 'ar' THEN hem.name_ar ELSE hem.name_en END,
            CASE WHEN p_locale = 'ar' THEN hem.name_en ELSE hem.name_ar END,
            key
        )::TEXT AS employee_name,
        jsonb_array_length((v_employee_map->key)->'products')::INTEGER AS product_count,
        (v_employee_map->key)->'branch_counts' AS branch_counts,
        (v_employee_map->key)->'products' AS products
    FROM jsonb_object_keys(v_employee_map) AS key
    LEFT JOIN hr_employee_master hem ON hem.id = key
    ORDER BY product_count DESC;
END;
$$;
