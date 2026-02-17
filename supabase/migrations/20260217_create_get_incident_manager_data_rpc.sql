-- RPC: get_incident_manager_data
-- Replaces 5+ client queries with a single server-side call
-- Returns all incidents with enriched employee/branch/user names and actions
CREATE OR REPLACE FUNCTION public.get_incident_manager_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_agg(incident_row ORDER BY (incident_row->>'created_at') DESC)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', i.id,
            'incident_type_id', i.incident_type_id,
            'employee_id', i.employee_id,
            'branch_id', i.branch_id,
            'violation_id', i.violation_id,
            'what_happened', i.what_happened,
            'witness_details', i.witness_details,
            'report_type', i.report_type,
            'reports_to_user_ids', i.reports_to_user_ids,
            'resolution_status', i.resolution_status::TEXT,
            'resolution_report', i.resolution_report,
            'user_statuses', i.user_statuses,
            'attachments', i.attachments,
            'investigation_report', i.investigation_report,
            'created_at', i.created_at,
            'created_by', i.created_by,
            -- Joined incident type
            'incident_types', CASE WHEN it.id IS NOT NULL THEN jsonb_build_object(
                'id', it.id,
                'incident_type_en', it.incident_type_en,
                'incident_type_ar', it.incident_type_ar
            ) ELSE NULL END,
            -- Joined warning violation
            'warning_violation', CASE WHEN wv.id IS NOT NULL THEN jsonb_build_object(
                'id', wv.id,
                'name_en', wv.name_en,
                'name_ar', wv.name_ar
            ) ELSE NULL END,
            -- Employee name (from hr_employee_master by employee_id = id)
            'employee_name_en', emp.name_en,
            'employee_name_ar', emp.name_ar,
            -- Branch info
            'branch_name_en', b.name_en,
            'branch_name_ar', b.name_ar,
            'branch_location_en', b.location_en,
            'branch_location_ar', b.location_ar,
            -- Reporter name (from hr_employee_master by user_id = created_by)
            'reporter_name_en', reporter.name_en,
            'reporter_name_ar', reporter.name_ar,
            -- Claimed-by user name (find user with status 'claimed' in user_statuses)
            'claimed_by_name_en', (
                SELECT e.name_en
                FROM jsonb_each(i.user_statuses) AS us(uid, status_obj)
                JOIN hr_employee_master e ON e.user_id = us.uid::uuid
                WHERE LOWER(us.status_obj->>'status') = 'claimed'
                LIMIT 1
            ),
            'claimed_by_name_ar', (
                SELECT e.name_ar
                FROM jsonb_each(i.user_statuses) AS us(uid, status_obj)
                JOIN hr_employee_master e ON e.user_id = us.uid::uuid
                WHERE LOWER(us.status_obj->>'status') = 'claimed'
                LIMIT 1
            ),
            -- Report-to users with names (subquery)
            'report_to_users', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'user_id', rtu.user_id,
                    'name_en', rtu.name_en,
                    'name_ar', rtu.name_ar
                )), '[]'::JSONB)
                FROM hr_employee_master rtu
                WHERE rtu.user_id = ANY(i.reports_to_user_ids)
            ),
            -- Incident actions (subquery)
            'incident_actions', (
                SELECT COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'id', ia.id,
                        'action_type', ia.action_type,
                        'recourse_type', ia.recourse_type,
                        'action_report', ia.action_report,
                        'has_fine', ia.has_fine,
                        'fine_amount', ia.fine_amount,
                        'fine_threat_amount', ia.fine_threat_amount,
                        'is_paid', ia.is_paid,
                        'paid_at', ia.paid_at,
                        'paid_by', ia.paid_by,
                        'employee_id', ia.employee_id,
                        'incident_id', ia.incident_id,
                        'incident_type_id', ia.incident_type_id,
                        'created_by', ia.created_by,
                        'created_at', ia.created_at,
                        'updated_at', ia.updated_at
                    ) ORDER BY ia.created_at DESC
                ), '[]'::JSONB)
                FROM incident_actions ia
                WHERE ia.incident_id = i.id
            )
        ) AS incident_row
        FROM incidents i
        LEFT JOIN incident_types it ON it.id = i.incident_type_id
        LEFT JOIN warning_violation wv ON wv.id = i.violation_id
        LEFT JOIN hr_employee_master emp ON emp.id = i.employee_id
        LEFT JOIN branches b ON b.id = i.branch_id
        LEFT JOIN hr_employee_master reporter ON reporter.user_id = i.created_by
    ) sub;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_incident_manager_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_incident_manager_data() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_incident_manager_data() TO anon;
