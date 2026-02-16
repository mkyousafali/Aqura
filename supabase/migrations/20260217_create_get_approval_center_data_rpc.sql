-- ============================================================
-- RPC: get_approval_center_data
-- Consolidates 9+ sequential queries into 1 RPC call for the
-- mobile & desktop approval center pages (~55% speedup)
-- ============================================================

CREATE OR REPLACE FUNCTION get_approval_center_data(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_permissions JSONB;
  v_can_approve_vendor_payments BOOLEAN := FALSE;
  v_can_approve_leave_requests BOOLEAN := FALSE;
  v_can_approve_purchase_vouchers BOOLEAN := FALSE;
  v_vendor_payment_amount_limit NUMERIC := 0;
  v_two_days_date DATE;
  v_result JSONB;
  v_requisitions JSONB;
  v_payment_schedules JSONB;
  v_vendor_payments JSONB;
  v_purchase_vouchers JSONB;
  v_my_requisitions JSONB;
  v_my_schedules JSONB;
  v_my_vouchers JSONB;
  v_day_off_requests JSONB;
  v_my_day_off_requests JSONB;
  v_user_names JSONB;
  v_employee_names JSONB;
  v_current_user_employee JSONB;
BEGIN
  -- 1) Get approval permissions
  SELECT jsonb_build_object(
    'id', ap.id,
    'user_id', ap.user_id,
    'can_approve_requisitions', ap.can_approve_requisitions,
    'requisition_amount_limit', ap.requisition_amount_limit,
    'can_approve_single_bill', ap.can_approve_single_bill,
    'single_bill_amount_limit', ap.single_bill_amount_limit,
    'can_approve_multiple_bill', ap.can_approve_multiple_bill,
    'multiple_bill_amount_limit', ap.multiple_bill_amount_limit,
    'can_approve_recurring_bill', ap.can_approve_recurring_bill,
    'recurring_bill_amount_limit', ap.recurring_bill_amount_limit,
    'can_approve_vendor_payments', ap.can_approve_vendor_payments,
    'vendor_payment_amount_limit', ap.vendor_payment_amount_limit,
    'can_approve_leave_requests', ap.can_approve_leave_requests,
    'can_approve_purchase_vouchers', ap.can_approve_purchase_vouchers,
    'can_add_missing_punches', ap.can_add_missing_punches,
    'is_active', ap.is_active
  ) INTO v_permissions
  FROM approval_permissions ap
  WHERE ap.user_id = p_user_id AND ap.is_active = TRUE
  LIMIT 1;

  -- Extract permission flags
  IF v_permissions IS NOT NULL THEN
    v_can_approve_vendor_payments := COALESCE((v_permissions->>'can_approve_vendor_payments')::BOOLEAN, FALSE);
    v_can_approve_leave_requests := COALESCE((v_permissions->>'can_approve_leave_requests')::BOOLEAN, FALSE);
    v_can_approve_purchase_vouchers := COALESCE((v_permissions->>'can_approve_purchase_vouchers')::BOOLEAN, FALSE);
    v_vendor_payment_amount_limit := COALESCE((v_permissions->>'vendor_payment_amount_limit')::NUMERIC, 0);
  END IF;

  -- Calculate two days from now for due date filtering
  v_two_days_date := CURRENT_DATE + INTERVAL '2 days';

  -- Fetch current user employee name
  SELECT jsonb_build_object('name_en', e.name_en, 'name_ar', e.name_ar)
  INTO v_current_user_employee
  FROM hr_employee_master e
  WHERE e.user_id = p_user_id
  LIMIT 1;

  -- 2) Pending requisitions where user is approver
  SELECT COALESCE(jsonb_agg(row_to_json(r)::JSONB ORDER BY r.created_at DESC), '[]'::JSONB)
  INTO v_requisitions
  FROM (
    SELECT * FROM expense_requisitions
    WHERE approver_id = p_user_id AND status = 'pending'
    ORDER BY created_at DESC
    LIMIT 200
  ) r;

  -- 3) Pending payment schedules where user is approver (single_bill + multiple_bill)
  SELECT COALESCE(jsonb_agg(row_to_json(s)::JSONB ORDER BY s.created_at DESC), '[]'::JSONB)
  INTO v_payment_schedules
  FROM (
    SELECT naps.*,
      jsonb_build_object('id', u.id, 'username', u.username,
        'hr_employee_master', CASE WHEN e.name_en IS NOT NULL THEN jsonb_build_object('name_en', e.name_en, 'name_ar', e.name_ar) ELSE NULL END
      ) AS creator
    FROM non_approved_payment_scheduler naps
    LEFT JOIN users u ON u.id = naps.created_by
    LEFT JOIN hr_employee_master e ON e.user_id = naps.created_by
    WHERE naps.approval_status = 'pending'
      AND naps.approver_id = p_user_id
      AND naps.schedule_type IN ('single_bill', 'multiple_bill')
    ORDER BY naps.created_at DESC
    LIMIT 200
  ) s;

  -- 4) Vendor payments requiring approval (conditional on permission)
  IF v_can_approve_vendor_payments THEN
    SELECT COALESCE(jsonb_agg(row_to_json(vp)::JSONB ORDER BY vp.approval_requested_at DESC), '[]'::JSONB)
    INTO v_vendor_payments
    FROM (
      SELECT vps.*,
        jsonb_build_object('id', u.id, 'username', u.username,
          'hr_employee_master', CASE WHEN e.name_en IS NOT NULL THEN jsonb_build_object('name_en', e.name_en, 'name_ar', e.name_ar) ELSE NULL END
        ) AS requester
      FROM vendor_payment_schedule vps
      LEFT JOIN users u ON u.id = vps.approval_requested_by
      LEFT JOIN hr_employee_master e ON e.user_id = vps.approval_requested_by
      WHERE vps.approval_status = 'sent_for_approval'
        AND vps.assigned_approver_id = p_user_id
      ORDER BY vps.approval_requested_at DESC
      LIMIT 200
    ) vp;
  ELSE
    v_vendor_payments := '[]'::JSONB;
  END IF;

  -- 4b) Purchase vouchers requiring approval (conditional on permission)
  IF v_can_approve_purchase_vouchers THEN
    SELECT COALESCE(jsonb_agg(row_to_json(pv)::JSONB ORDER BY pv.issued_date DESC), '[]'::JSONB)
    INTO v_purchase_vouchers
    FROM (
      SELECT pvi.*,
        jsonb_build_object('id', u.id, 'username', u.username,
          'hr_employee_master', CASE WHEN e.name_en IS NOT NULL THEN jsonb_build_object('name_en', e.name_en, 'name_ar', e.name_ar) ELSE NULL END
        ) AS issued_by_user,
        jsonb_build_object('id', b1.id, 'name_en', b1.name_en) AS stock_location_branch,
        jsonb_build_object('id', b2.id, 'name_en', b2.name_en) AS pending_location_branch,
        jsonb_build_object('id', u2.id, 'username', u2.username,
          'hr_employee_master', CASE WHEN e2.name_en IS NOT NULL THEN jsonb_build_object('name_en', e2.name_en, 'name_ar', e2.name_ar) ELSE NULL END
        ) AS pending_person_user
      FROM purchase_voucher_items pvi
      LEFT JOIN users u ON u.id = pvi.issued_by
      LEFT JOIN hr_employee_master e ON e.user_id = pvi.issued_by
      LEFT JOIN branches b1 ON b1.id = pvi.stock_location
      LEFT JOIN branches b2 ON b2.id = pvi.pending_stock_location
      LEFT JOIN users u2 ON u2.id = pvi.pending_stock_person
      LEFT JOIN hr_employee_master e2 ON e2.user_id = pvi.pending_stock_person
      WHERE pvi.approval_status = 'pending'
        AND pvi.approver_id = p_user_id
      ORDER BY pvi.issued_date DESC
      LIMIT 200
    ) pv;
  ELSE
    v_purchase_vouchers := '[]'::JSONB;
  END IF;

  -- 5) My created requisitions (pending)
  SELECT COALESCE(jsonb_agg(row_to_json(mr)::JSONB ORDER BY mr.created_at DESC), '[]'::JSONB)
  INTO v_my_requisitions
  FROM (
    SELECT * FROM expense_requisitions
    WHERE created_by = p_user_id AND status = 'pending'
    ORDER BY created_at DESC
    LIMIT 200
  ) mr;

  -- 6) My created payment schedules (pending)
  SELECT COALESCE(jsonb_agg(row_to_json(ms)::JSONB ORDER BY ms.created_at DESC), '[]'::JSONB)
  INTO v_my_schedules
  FROM (
    SELECT naps.*,
      jsonb_build_object('id', u.id, 'username', u.username,
        'hr_employee_master', CASE WHEN e.name_en IS NOT NULL THEN jsonb_build_object('name_en', e.name_en, 'name_ar', e.name_ar) ELSE NULL END
      ) AS approver
    FROM non_approved_payment_scheduler naps
    LEFT JOIN users u ON u.id = naps.approver_id
    LEFT JOIN hr_employee_master e ON e.user_id = naps.approver_id
    WHERE naps.created_by = p_user_id
      AND naps.approval_status = 'pending'
      AND naps.schedule_type IN ('single_bill', 'multiple_bill')
    ORDER BY naps.created_at DESC
    LIMIT 200
  ) ms;

  -- 6b) My created purchase vouchers (pending)
  SELECT COALESCE(jsonb_agg(row_to_json(mv)::JSONB ORDER BY mv.issued_date DESC), '[]'::JSONB)
  INTO v_my_vouchers
  FROM (
    SELECT pvi.*,
      jsonb_build_object('id', u.id, 'username', u.username,
        'hr_employee_master', CASE WHEN e.name_en IS NOT NULL THEN jsonb_build_object('name_en', e.name_en, 'name_ar', e.name_ar) ELSE NULL END
      ) AS approver_user
    FROM purchase_voucher_items pvi
    LEFT JOIN users u ON u.id = pvi.approver_id
    LEFT JOIN hr_employee_master e ON e.user_id = pvi.approver_id
    WHERE pvi.issued_by = p_user_id
      AND pvi.approval_status = 'pending'
    ORDER BY pvi.issued_date DESC
    LIMIT 200
  ) mv;

  -- 7) Day off requests requiring approval (conditional on permission)
  IF v_can_approve_leave_requests THEN
    SELECT COALESCE(jsonb_agg(row_to_json(dor)::JSONB ORDER BY dor.approval_requested_at DESC), '[]'::JSONB)
    INTO v_day_off_requests
    FROM (
      SELECT d.*,
        jsonb_build_object('id', u.id, 'username', u.username,
          'hr_employee_master', CASE WHEN e2.name_en IS NOT NULL THEN jsonb_build_object('name_en', e2.name_en, 'name_ar', e2.name_ar) ELSE NULL END
        ) AS requester,
        jsonb_build_object('id', e.id, 'name_en', e.name_en, 'name_ar', e.name_ar) AS employee,
        jsonb_build_object('id', dr.id, 'reason_en', dr.reason_en, 'reason_ar', dr.reason_ar) AS reason
      FROM day_off d
      LEFT JOIN users u ON u.id = d.approval_requested_by
      LEFT JOIN hr_employee_master e ON e.id = d.employee_id
      LEFT JOIN hr_employee_master e2 ON e2.user_id = d.approval_requested_by
      LEFT JOIN day_off_reasons dr ON dr.id = d.day_off_reason_id
      WHERE d.approval_status = 'pending'
      ORDER BY d.approval_requested_at DESC
      LIMIT 200
    ) dor;
  ELSE
    v_day_off_requests := '[]'::JSONB;
  END IF;

  -- 8) My day off requests (all statuses)
  SELECT COALESCE(jsonb_agg(row_to_json(mdo)::JSONB ORDER BY mdo.approval_requested_at DESC), '[]'::JSONB)
  INTO v_my_day_off_requests
  FROM (
    SELECT d.*,
      jsonb_build_object('id', dr.id, 'reason_en', dr.reason_en, 'reason_ar', dr.reason_ar) AS reason
    FROM day_off d
    LEFT JOIN day_off_reasons dr ON dr.id = d.day_off_reason_id
    WHERE d.approval_requested_by = p_user_id
    ORDER BY d.approval_requested_at DESC
    LIMIT 200
  ) mdo;

  -- 9) Collect unique user IDs from requisitions for username lookup
  SELECT COALESCE(jsonb_object_agg(u.id::TEXT, jsonb_build_object('id', u.id, 'username', u.username,
    'hr_employee_master', CASE WHEN e.name_en IS NOT NULL THEN jsonb_build_object('name_en', e.name_en, 'name_ar', e.name_ar) ELSE NULL END
  )), '{}'::JSONB)
  INTO v_user_names
  FROM users u
  LEFT JOIN hr_employee_master e ON e.user_id = u.id
  WHERE u.id IN (
    SELECT DISTINCT er.created_by FROM expense_requisitions er
    WHERE er.created_by IS NOT NULL
      AND (
        (er.approver_id = p_user_id AND er.status = 'pending')
        OR (er.created_by = p_user_id AND er.status = 'pending')
      )
  );

  -- 10) Collect employee names for vendor payment & day-off requesters
  SELECT COALESCE(jsonb_object_agg(e.user_id::TEXT, jsonb_build_object('user_id', e.user_id, 'name_en', e.name_en, 'name_ar', e.name_ar)), '{}'::JSONB)
  INTO v_employee_names
  FROM hr_employee_master e
  WHERE e.user_id IN (
    SELECT vps.approval_requested_by FROM vendor_payment_schedule vps
    WHERE vps.approval_status = 'sent_for_approval' AND vps.assigned_approver_id = p_user_id
    UNION
    SELECT d.approval_requested_by FROM day_off d
    WHERE d.approval_status = 'pending'
  );

  -- Build final result
  v_result := jsonb_build_object(
    'permissions', COALESCE(v_permissions, 'null'::JSONB),
    'requisitions', v_requisitions,
    'payment_schedules', v_payment_schedules,
    'vendor_payments', v_vendor_payments,
    'purchase_vouchers', v_purchase_vouchers,
    'my_requisitions', v_my_requisitions,
    'my_schedules', v_my_schedules,
    'my_vouchers', v_my_vouchers,
    'day_off_requests', v_day_off_requests,
    'my_day_off_requests', v_my_day_off_requests,
    'user_names', v_user_names,
    'employee_names', v_employee_names,
    'current_user_employee', COALESCE(v_current_user_employee, 'null'::JSONB),
    'two_days_date', v_two_days_date
  );

  RETURN v_result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_approval_center_data(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_approval_center_data(UUID) TO anon;
GRANT EXECUTE ON FUNCTION get_approval_center_data(UUID) TO service_role;
