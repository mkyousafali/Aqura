CREATE OR REPLACE FUNCTION public.get_checklist_submissions()
RETURNS TABLE (
    id                  TEXT,
    user_id             UUID,
    employee_id         TEXT,
    box_operation_id    UUID,
    checklist_id        TEXT,
    answers             JSONB,
    total_points        INTEGER,
    branch_id           BIGINT,
    operation_date      DATE,
    operation_time      TIME,
    created_at          TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ,
    box_number          INTEGER,
    max_points          INTEGER,
    submission_type_en  TEXT,
    submission_type_ar  TEXT,
    -- hr_employee_master
    emp_id              TEXT,
    emp_name_en         TEXT,
    emp_name_ar         TEXT,
    -- hr_checklists
    cl_id               TEXT,
    cl_name_en          TEXT,
    cl_name_ar          TEXT,
    -- branches
    br_id               BIGINT,
    br_name_en          TEXT,
    br_name_ar          TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        o.id,
        o.user_id,
        o.employee_id,
        o.box_operation_id,
        o.checklist_id,
        o.answers,
        o.total_points,
        o.branch_id,
        o.operation_date,
        o.operation_time,
        o.created_at,
        o.updated_at,
        o.box_number,
        o.max_points,
        o.submission_type_en,
        o.submission_type_ar,
        e.id         AS emp_id,
        e.name_en    AS emp_name_en,
        e.name_ar    AS emp_name_ar,
        c.id         AS cl_id,
        c.checklist_name_en AS cl_name_en,
        c.checklist_name_ar AS cl_name_ar,
        b.id         AS br_id,
        b.name_en    AS br_name_en,
        b.name_ar    AS br_name_ar
    FROM hr_checklist_operations o
    LEFT JOIN hr_employee_master e ON e.id = o.employee_id
    LEFT JOIN hr_checklists c ON c.id = o.checklist_id
    LEFT JOIN branches b ON b.id = o.branch_id
    ORDER BY o.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_checklist_submissions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_checklist_submissions() TO anon;
