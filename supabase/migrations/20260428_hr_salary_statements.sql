-- ============================================================================
-- HR Salary Statements: Save / Load / Update infrastructure
-- ============================================================================

-- 1) Table -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hr_salary_statements (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    statement_name  text        NOT NULL,
    start_date      date        NOT NULL,
    end_date        date        NOT NULL,
    data_json       jsonb       NOT NULL,
    created_by      uuid        NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT hr_salary_statements_name_chk CHECK (length(trim(statement_name)) > 0),
    CONSTRAINT hr_salary_statements_dates_chk CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS hr_salary_statements_updated_at_idx
    ON public.hr_salary_statements (updated_at DESC);
CREATE INDEX IF NOT EXISTS hr_salary_statements_dates_idx
    ON public.hr_salary_statements (start_date, end_date);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.tg_hr_salary_statements_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS hr_salary_statements_set_updated_at ON public.hr_salary_statements;
CREATE TRIGGER hr_salary_statements_set_updated_at
BEFORE UPDATE ON public.hr_salary_statements
FOR EACH ROW EXECUTE FUNCTION public.tg_hr_salary_statements_set_updated_at();

-- RLS: keep table closed; access only via SECURITY DEFINER RPCs
ALTER TABLE public.hr_salary_statements ENABLE ROW LEVEL SECURITY;

-- 2) RPCs --------------------------------------------------------------------

-- create_salary_statement
CREATE OR REPLACE FUNCTION public.create_salary_statement(
    p_statement_name text,
    p_start_date     date,
    p_end_date       date,
    p_data_json      jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_id  uuid;
    v_uid uuid;
BEGIN
    IF p_statement_name IS NULL OR length(trim(p_statement_name)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'statement_name is required');
    END IF;
    IF p_start_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'start_date is required');
    END IF;
    IF p_end_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'end_date is required');
    END IF;
    IF p_end_date < p_start_date THEN
        RETURN jsonb_build_object('success', false, 'error', 'end_date must be >= start_date');
    END IF;
    IF p_data_json IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'data_json is required');
    END IF;

    BEGIN
        v_uid := auth.uid();
    EXCEPTION WHEN OTHERS THEN
        v_uid := NULL;
    END;

    INSERT INTO public.hr_salary_statements (statement_name, start_date, end_date, data_json, created_by)
    VALUES (trim(p_statement_name), p_start_date, p_end_date, p_data_json, v_uid)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$fn$;

-- list_salary_statements
CREATE OR REPLACE FUNCTION public.list_salary_statements()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_rows jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(r ORDER BY r.updated_at DESC), '[]'::jsonb) INTO v_rows
    FROM (
        SELECT id, statement_name, start_date, end_date, created_at, updated_at
        FROM public.hr_salary_statements
        ORDER BY updated_at DESC
    ) r;
    RETURN jsonb_build_object('success', true, 'items', v_rows);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$fn$;

-- get_salary_statement_by_id
CREATE OR REPLACE FUNCTION public.get_salary_statement_by_id(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_row public.hr_salary_statements;
BEGIN
    IF p_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'id is required');
    END IF;
    SELECT * INTO v_row FROM public.hr_salary_statements WHERE id = p_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not found');
    END IF;
    RETURN jsonb_build_object(
        'success', true,
        'item', jsonb_build_object(
            'id', v_row.id,
            'statement_name', v_row.statement_name,
            'start_date', v_row.start_date,
            'end_date', v_row.end_date,
            'data_json', v_row.data_json,
            'created_at', v_row.created_at,
            'updated_at', v_row.updated_at
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$fn$;

-- update_salary_statement
CREATE OR REPLACE FUNCTION public.update_salary_statement(
    p_id             uuid,
    p_statement_name text,
    p_start_date     date,
    p_end_date       date,
    p_data_json      jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
    v_count int;
BEGIN
    IF p_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'id is required');
    END IF;
    IF p_statement_name IS NULL OR length(trim(p_statement_name)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'statement_name is required');
    END IF;
    IF p_start_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'start_date is required');
    END IF;
    IF p_end_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'end_date is required');
    END IF;
    IF p_end_date < p_start_date THEN
        RETURN jsonb_build_object('success', false, 'error', 'end_date must be >= start_date');
    END IF;
    IF p_data_json IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'data_json is required');
    END IF;

    UPDATE public.hr_salary_statements
    SET statement_name = trim(p_statement_name),
        start_date     = p_start_date,
        end_date       = p_end_date,
        data_json      = p_data_json
    WHERE id = p_id;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'not found');
    END IF;
    RETURN jsonb_build_object('success', true, 'id', p_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$fn$;

-- 3) Grants ------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.create_salary_statement(text, date, date, jsonb) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.list_salary_statements() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_salary_statement_by_id(uuid) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.update_salary_statement(uuid, text, date, date, jsonb) TO authenticated, anon, service_role;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
