BEGIN;

-- Remove selected employees from a saved salary statement while preserving
-- every other row and all unrelated statement data.
CREATE OR REPLACE FUNCTION public.remove_salary_statement_rows(
    p_id uuid,
    p_employee_ids text[]
) RETURNS jsonb
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
    v_emp text;
    v_key text;
    v_removed jsonb := '[]'::jsonb;
BEGIN
    IF p_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'id is required');
    END IF;
    IF p_employee_ids IS NULL OR cardinality(p_employee_ids) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'employee ids are required');
    END IF;

    SELECT data_json INTO v_data
    FROM public.hr_salary_statements
    WHERE id = p_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not found');
    END IF;
    v_data := COALESCE(v_data, '{}'::jsonb);

    FOREACH v_emp IN ARRAY p_employee_ids LOOP
        IF v_emp IS NULL OR length(v_emp) = 0 THEN
            RETURN jsonb_build_object('success', false, 'error', 'employeeId is required');
        END IF;

        v_removed := v_removed || COALESCE((
            SELECT jsonb_agg(e)
            FROM jsonb_array_elements(COALESCE(v_data->'analysisData', '[]'::jsonb)) e
            WHERE e->>'employeeId' = v_emp
        ), '[]'::jsonb);

        v_data := jsonb_set(v_data, '{analysisData}', (
            SELECT COALESCE(jsonb_agg(e ORDER BY ord), '[]'::jsonb)
            FROM jsonb_array_elements(COALESCE(v_data->'analysisData', '[]'::jsonb))
                WITH ORDINALITY AS rows(e, ord)
            WHERE e->>'employeeId' <> v_emp
        ));

        FOREACH v_key IN ARRAY v_map_keys LOOP
            v_data := jsonb_set(
                v_data,
                ARRAY[v_key],
                COALESCE(v_data->v_key, '{}'::jsonb) - v_emp
            );
        END LOOP;

        v_data := jsonb_set(v_data, '{employeeShifts}', (
            SELECT COALESCE(jsonb_agg(e ORDER BY ord), '[]'::jsonb)
            FROM jsonb_array_elements(COALESCE(v_data->'employeeShifts', '[]'::jsonb))
                WITH ORDINALITY AS shifts(e, ord)
            WHERE e->>0 <> v_emp
        ));
    END LOOP;

    UPDATE public.hr_salary_statements
    SET data_json = v_data
    WHERE id = p_id;

    RETURN jsonb_build_object('success', true, 'id', p_id, 'removed', v_removed);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT ALL ON FUNCTION public.remove_salary_statement_rows(uuid, text[]) TO authenticated;
GRANT ALL ON FUNCTION public.remove_salary_statement_rows(uuid, text[]) TO anon;
GRANT ALL ON FUNCTION public.remove_salary_statement_rows(uuid, text[]) TO service_role;

COMMIT;
