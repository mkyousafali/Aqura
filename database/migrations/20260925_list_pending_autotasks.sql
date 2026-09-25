BEGIN;

CREATE OR REPLACE FUNCTION public."Autotask_list_pending_tasks"(p_requesting_user_id uuid)
RETURNS TABLE(
  id uuid,
  task_number integer,
  rule_code text,
  title_en text,
  title_ar text,
  status text,
  is_overdue boolean,
  triggered_at timestamptz,
  available_at timestamptz,
  due_at timestamptz,
  branch_id text,
  branch_name_en text,
  branch_name_ar text,
  assignee_user_id uuid,
  assignee_username text,
  assignee_name_en text,
  assignee_name_ar text,
  source_table text,
  source_record_id text,
  source_refs jsonb,
  pending_dependencies jsonb,
  source_vendor_name text,
  source_bill_amount numeric,
  source_record_date date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = p_requesting_user_id
      AND u.status = 'active'
      AND (
        coalesce(u.is_master_admin, false)
        OR EXISTS (
          SELECT 1
          FROM public.button_permissions bp
          WHERE bp.user_id = u.id
            AND bp.button_code IN ('DEFAULT_POSITIONS', 'APP_PERMISSIONS')
            AND bp.is_enabled = true
        )
      )
  ) THEN
    RAISE EXCEPTION 'Not authorized to view pending Auto Tasks';
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    t.task_number,
    t.rule_code,
    t.title_en,
    t.title_ar,
    t.status,
    (t.due_at < now()) AS is_overdue,
    t.triggered_at,
    t.available_at,
    t.due_at,
    t.branch_id,
    coalesce(b.name_en, 'Unknown branch')::text,
    coalesce(b.name_ar, b.name_en, 'Unknown branch')::text,
    t.assignee_user_id,
    coalesce(u.username, 'Unknown user')::text,
    coalesce(he.name_en, u.username, 'Unknown user')::text,
    coalesce(he.name_ar, he.name_en, u.username, 'Unknown user')::text,
    t.source_table,
    t.source_record_id,
    t.source_refs,
    coalesce(deps.items, '[]'::jsonb),
    coalesce(v.vendor_name, t.source_refs->>'vendor_name', 'Unknown vendor')::text,
    coalesce(rr.bill_amount, pr.bill_amount),
    coalesce(rr.bill_date, pr.bill_date)
  FROM public."Autotask_tasks" t
  LEFT JOIN public.branches b ON b.id::text = t.branch_id
  LEFT JOIN public.users u ON u.id = t.assignee_user_id
  LEFT JOIN public.hr_employee_master he ON he.user_id = t.assignee_user_id
  LEFT JOIN public.receiving_records rr
    ON t.source_table = 'receiving_records' AND rr.id::text = t.source_record_id
  LEFT JOIN public.pending_receiving_records pr
    ON t.source_table = 'pending_receiving_records' AND pr.id::text = t.source_record_id
  LEFT JOIN public.vendors v
    ON v.erp_vendor_id = coalesce(rr.vendor_id, pr.vendor_id)
   AND v.branch_id = coalesce(rr.branch_id, pr.branch_id)
  LEFT JOIN LATERAL (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', prerequisite.id,
        'task_number', prerequisite.task_number,
        'title_en', prerequisite.title_en,
        'title_ar', prerequisite.title_ar,
        'status', prerequisite.status,
        'assignee_user_id', prerequisite.assignee_user_id,
        'assignee_username', coalesce(prerequisite_user.username, 'Unknown user'),
        'assignee_name_en', coalesce(prerequisite_employee.name_en, prerequisite_user.username, 'Unknown user'),
        'assignee_name_ar', coalesce(prerequisite_employee.name_ar, prerequisite_employee.name_en, prerequisite_user.username, 'Unknown user'),
        'due_at', prerequisite.due_at,
        'is_overdue', prerequisite.due_at < now()
      ) ORDER BY prerequisite.task_number, prerequisite.due_at
    ) AS items
    FROM public."Autotask_dependencies" dependency
    JOIN public."Autotask_tasks" prerequisite ON prerequisite.id = dependency.prerequisite_task_id
    LEFT JOIN public.users prerequisite_user ON prerequisite_user.id = prerequisite.assignee_user_id
    LEFT JOIN public.hr_employee_master prerequisite_employee ON prerequisite_employee.user_id = prerequisite.assignee_user_id
    WHERE dependency.dependent_task_id = t.id
      AND prerequisite.status NOT IN ('completed', 'cancelled')
  ) deps ON true
  WHERE t.status IN ('open', 'blocked')
  ORDER BY t.due_at ASC, t.task_number ASC, t.created_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public."Autotask_list_pending_tasks"(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public."Autotask_list_pending_tasks"(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public."Autotask_list_pending_tasks"(uuid) TO authenticated;

COMMIT;
