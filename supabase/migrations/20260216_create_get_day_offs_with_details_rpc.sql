-- RPC function to get day offs with all related details in a single query
-- Replaces multiple client-side queries (employees, branches, nationalities, day_off_reasons)

CREATE OR REPLACE FUNCTION get_day_offs_with_details(
    p_date_from DATE,
    p_date_to DATE
)
RETURNS TABLE (
    id TEXT,
    employee_id TEXT,
    employee_name_en TEXT,
    employee_name_ar TEXT,
    branch_id TEXT,
    branch_name_en TEXT,
    branch_name_ar TEXT,
    branch_location_en TEXT,
    branch_location_ar TEXT,
    nationality_id TEXT,
    nationality_name_en TEXT,
    nationality_name_ar TEXT,
    sponsorship_status TEXT,
    employment_status TEXT,
    day_off_date DATE,
    approval_status TEXT,
    reason_en TEXT,
    reason_ar TEXT,
    document_url TEXT,
    description TEXT,
    is_deductible_on_salary BOOLEAN,
    approval_requested_at TIMESTAMPTZ,
    day_off_reason_id TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id::TEXT,
        d.employee_id::TEXT,
        COALESCE(e.name_en, 'N/A')::TEXT AS employee_name_en,
        COALESCE(e.name_ar, 'N/A')::TEXT AS employee_name_ar,
        e.current_branch_id::TEXT AS branch_id,
        COALESCE(b.name_en, 'N/A')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, 'N/A')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, '')::TEXT AS branch_location_ar,
        e.nationality_id::TEXT,
        COALESCE(n.name_en, 'N/A')::TEXT AS nationality_name_en,
        COALESCE(n.name_ar, 'N/A')::TEXT AS nationality_name_ar,
        e.sponsorship_status::TEXT,
        e.employment_status::TEXT,
        d.day_off_date,
        COALESCE(d.approval_status, 'pending')::TEXT AS approval_status,
        COALESCE(r.reason_en, 'N/A')::TEXT AS reason_en,
        COALESCE(r.reason_ar, 'N/A')::TEXT AS reason_ar,
        d.document_url::TEXT,
        d.description::TEXT,
        COALESCE(d.is_deductible_on_salary, false) AS is_deductible_on_salary,
        d.approval_requested_at,
        d.day_off_reason_id::TEXT
    FROM day_off d
    LEFT JOIN hr_employee_master e ON e.id = d.employee_id
    LEFT JOIN branches b ON b.id = e.current_branch_id
    LEFT JOIN nationalities n ON n.id = e.nationality_id
    LEFT JOIN day_off_reasons r ON r.id = d.day_off_reason_id
    WHERE d.day_off_date >= p_date_from
      AND d.day_off_date <= p_date_to
    ORDER BY d.day_off_date DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant access
GRANT EXECUTE ON FUNCTION get_day_offs_with_details(DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_day_offs_with_details(DATE, DATE) TO anon;
