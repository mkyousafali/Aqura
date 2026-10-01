BEGIN;

-- Update only specific employees inside a saved salary statement.
-- Every other employee (any branch) stays exactly as saved.
--
-- p_rows: [{ "employeeId": "EMP1", "row": {...analysisData row...},
--            "values": { "basicSalaries": 3000, "empEditOverrides": null, ... },
--            "shift": {...} | null }, ...]
-- A null value removes that employee's key from the map.
-- Returns each employee's previous slice so the client can log before/after.
CREATE OR REPLACE FUNCTION public.update_salary_statement_rows(p_id uuid, p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_map_keys constant text[] := ARRAY[
        'editableWorkedDays', 'basicSalaries', 'paymentModes',
        'otherAllowances', 'otherAllowancePaymentModes',
        'accommodationAllowances', 'accommodationPaymentModes',
        'travelAllowances', 'travelPaymentModes',
        'gosiDeductions', 'gosiIsPercentages', 'gosiPercentages',
        'foodAllowances', 'foodPaymentModes', 'foodDeductionActives',
        'posShortageDeductions', 'posDeductionsList', 'empEditOverrides',
        'autoFineDeductions', 'lateMinutesOverrides', 'underWorkedMinutesOverrides',
        'lateDeductionOverrides', 'underWorkedDeductionOverrides',
        'unapprovedLeaveDeductionOverrides', 'incompleteDayDeductionOverrides'
    ];
    v_data jsonb;
    v_item jsonb;
    v_emp text;
    v_key text;
    v_val jsonb;
    v_before_values jsonb;
    v_before_row jsonb;
    v_before_shift jsonb;
    v_before jsonb := '[]'::jsonb;
BEGIN
    IF p_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'id is required');
    END IF;
    IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'rows are required');
    END IF;

    SELECT data_json INTO v_data FROM public.hr_salary_statements WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not found');
    END IF;
    v_data := COALESCE(v_data, '{}'::jsonb);

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
        v_emp := v_item->>'employeeId';
        IF v_emp IS NULL OR length(v_emp) = 0 THEN
            RETURN jsonb_build_object('success', false, 'error', 'employeeId is required');
        END IF;
        IF jsonb_typeof(v_item->'row') IS DISTINCT FROM 'object' THEN
            RETURN jsonb_build_object('success', false, 'error', 'row is required for ' || v_emp);
        END IF;

        -- Capture the previous slice for logging
        SELECT e INTO v_before_row
        FROM jsonb_array_elements(COALESCE(v_data->'analysisData', '[]'::jsonb)) e
        WHERE e->>'employeeId' = v_emp
        LIMIT 1;

        v_before_values := '{}'::jsonb;
        FOREACH v_key IN ARRAY v_map_keys LOOP
            v_before_values := v_before_values || jsonb_build_object(v_key, v_data->v_key->v_emp);
        END LOOP;

        SELECT e->1 INTO v_before_shift
        FROM jsonb_array_elements(COALESCE(v_data->'employeeShifts', '[]'::jsonb)) e
        WHERE e->>0 = v_emp
        LIMIT 1;

        v_before := v_before || jsonb_build_array(jsonb_build_object(
            'employeeId', v_emp, 'row', v_before_row, 'values', v_before_values, 'shift', v_before_shift
        ));

        -- analysisData: replace this employee's row in place, or append if missing
        IF v_before_row IS NOT NULL THEN
            v_data := jsonb_set(v_data, '{analysisData}', (
                SELECT jsonb_agg(CASE WHEN e->>'employeeId' = v_emp THEN v_item->'row' ELSE e END ORDER BY ord)
                FROM jsonb_array_elements(v_data->'analysisData') WITH ORDINALITY AS t(e, ord)
            ));
        ELSE
            v_data := jsonb_set(v_data, '{analysisData}',
                COALESCE(v_data->'analysisData', '[]'::jsonb) || jsonb_build_array(v_item->'row'));
        END IF;

        -- Per-employee maps (only whitelisted keys)
        FOREACH v_key IN ARRAY v_map_keys LOOP
            v_val := v_item->'values'->v_key;
            IF v_val IS NULL OR jsonb_typeof(v_val) = 'null' THEN
                v_data := jsonb_set(v_data, ARRAY[v_key], COALESCE(v_data->v_key, '{}'::jsonb) - v_emp);
            ELSE
                v_data := jsonb_set(v_data, ARRAY[v_key], COALESCE(v_data->v_key, '{}'::jsonb) || jsonb_build_object(v_emp, v_val));
            END IF;
        END LOOP;

        -- employeeShifts is stored as [[employeeId, shift], ...]
        v_data := jsonb_set(v_data, '{employeeShifts}', (
            SELECT COALESCE(jsonb_agg(e ORDER BY ord), '[]'::jsonb)
            FROM jsonb_array_elements(COALESCE(v_data->'employeeShifts', '[]'::jsonb)) WITH ORDINALITY AS t(e, ord)
            WHERE e->>0 <> v_emp
        ));
        IF v_item->'shift' IS NOT NULL AND jsonb_typeof(v_item->'shift') <> 'null' THEN
            v_data := jsonb_set(v_data, '{employeeShifts}',
                (v_data->'employeeShifts') || jsonb_build_array(jsonb_build_array(v_emp, v_item->'shift')));
        END IF;
    END LOOP;

    UPDATE public.hr_salary_statements SET data_json = v_data WHERE id = p_id;

    RETURN jsonb_build_object('success', true, 'id', p_id, 'before', v_before);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT ALL ON FUNCTION public.update_salary_statement_rows(p_id uuid, p_rows jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.update_salary_statement_rows(p_id uuid, p_rows jsonb) TO anon;
GRANT ALL ON FUNCTION public.update_salary_statement_rows(p_id uuid, p_rows jsonb) TO service_role;

COMMIT;
