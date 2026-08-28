-- Lets HR correct the start date of an employee's CURRENT status record
-- in place, instead of creating a new transition. When the previous status
-- record exists, its effective_to is cascaded to stay adjacent (new_date -
-- 1) so no gap or overlap is created. If there is no previous record
-- (this is the employee's first/only status period), only the current
-- record's effective_from is touched.
CREATE FUNCTION public.update_current_status_effective_date(
    p_employee_id text,
    p_new_effective_from date,
    p_reason text DEFAULT NULL
)
RETURNS TABLE(id bigint, employee_id text, status text, effective_from date, effective_to date, reason text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_current RECORD;
    v_previous RECORD;
    v_conflict RECORD;
BEGIN
    IF COALESCE(trim(p_employee_id), '') = '' THEN
        RAISE EXCEPTION 'Employee ID is required';
    END IF;
    IF p_new_effective_from IS NULL THEN
        RAISE EXCEPTION 'Effective date is required';
    END IF;

    SELECT h.* INTO v_current
    FROM public.hr_employee_status_history h
    WHERE h.employee_id = p_employee_id AND h.effective_to IS NULL
    LIMIT 1;

    IF v_current.id IS NULL THEN
        RAISE EXCEPTION 'No current status found for this employee';
    END IF;

    -- The record immediately before the current one, if any (the most
    -- recently closed period for this employee).
    SELECT h.* INTO v_previous
    FROM public.hr_employee_status_history h
    WHERE h.employee_id = p_employee_id AND h.effective_to IS NOT NULL
    ORDER BY h.effective_to DESC
    LIMIT 1;

    IF v_previous.id IS NOT NULL THEN
        IF v_previous.effective_from IS NOT NULL AND p_new_effective_from <= v_previous.effective_from THEN
            RAISE EXCEPTION 'New date must be after % (%), when the prior status began', v_previous.effective_from, v_previous.status;
        END IF;

        -- Defensive: make sure the new date doesn't land inside any OTHER
        -- older closed period further back.
        SELECT h.* INTO v_conflict
        FROM public.hr_employee_status_history h
        WHERE h.employee_id = p_employee_id
          AND h.id <> v_previous.id
          AND h.effective_to IS NOT NULL
          AND (h.effective_from IS NULL OR h.effective_from <= p_new_effective_from)
          AND h.effective_to >= p_new_effective_from
        LIMIT 1;

        IF v_conflict.id IS NOT NULL THEN
            RAISE EXCEPTION 'This date falls within an existing "%" period (% to %)',
                v_conflict.status, COALESCE(v_conflict.effective_from::text, 'unknown'), v_conflict.effective_to;
        END IF;

        UPDATE public.hr_employee_status_history
        SET effective_to = p_new_effective_from - 1
        WHERE hr_employee_status_history.id = v_previous.id;
    END IF;

    RETURN QUERY
    UPDATE public.hr_employee_status_history
    SET effective_from = p_new_effective_from,
        reason = COALESCE(NULLIF(trim(p_reason), ''), hr_employee_status_history.reason)
    WHERE hr_employee_status_history.id = v_current.id
    RETURNING
        hr_employee_status_history.id,
        hr_employee_status_history.employee_id,
        hr_employee_status_history.status,
        hr_employee_status_history.effective_from,
        hr_employee_status_history.effective_to,
        hr_employee_status_history.reason;
END;
$$;

COMMENT ON FUNCTION public.update_current_status_effective_date(text, date, text) IS
    'Corrects the start date of an employee''s current (open) status record in place, cascading the adjustment to the immediately preceding record''s end date so ranges stay non-overlapping. Distinct from change_employee_status, which creates a new transition.';
