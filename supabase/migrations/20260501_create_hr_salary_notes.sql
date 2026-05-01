-- Migration: Create hr_salary_notes table
-- Date: 2026-05-01
-- Description: Salary notes per employee with three note types

CREATE TABLE IF NOT EXISTS public.hr_salary_notes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id text        NOT NULL REFERENCES public.hr_employee_master(id) ON DELETE CASCADE,
    note_type   text        NOT NULL CHECK (note_type IN ('common', 'specific_period', 'until_date')),
    note_text   text        NOT NULL,
    from_date   date        NULL,
    to_date     date        NULL,
    until_date  date        NULL,
    created_by  uuid        NULL REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_hr_salary_notes_employee_id ON public.hr_salary_notes(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_salary_notes_created_at  ON public.hr_salary_notes(created_at DESC);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.set_hr_salary_notes_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_hr_salary_notes_updated_at ON public.hr_salary_notes;
CREATE TRIGGER trg_hr_salary_notes_updated_at
    BEFORE UPDATE ON public.hr_salary_notes
    FOR EACH ROW EXECUTE FUNCTION public.set_hr_salary_notes_updated_at();

-- RLS
ALTER TABLE public.hr_salary_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "hr_salary_notes_select" ON public.hr_salary_notes
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "hr_salary_notes_insert" ON public.hr_salary_notes
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "hr_salary_notes_delete" ON public.hr_salary_notes
    FOR DELETE TO authenticated USING (true);

-- RPC: fetch notes for an employee (ordered newest first)
CREATE OR REPLACE FUNCTION public.get_hr_salary_notes(p_employee_id text)
RETURNS TABLE (
    id          uuid,
    employee_id text,
    note_type   text,
    note_text   text,
    from_date   date,
    to_date     date,
    until_date  date,
    created_by  uuid,
    created_at  timestamptz,
    updated_at  timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT id, employee_id, note_type, note_text,
           from_date, to_date, until_date, created_by, created_at, updated_at
    FROM public.hr_salary_notes
    WHERE employee_id = p_employee_id
    ORDER BY created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_hr_salary_notes(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_hr_salary_notes(text) TO anon;

-- RPC: create a new note
CREATE OR REPLACE FUNCTION public.create_hr_salary_note(
    p_employee_id text,
    p_note_type   text,
    p_note_text   text,
    p_from_date   date DEFAULT NULL,
    p_to_date     date DEFAULT NULL,
    p_until_date  date DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO public.hr_salary_notes
        (employee_id, note_type, note_text, from_date, to_date, until_date, created_by)
    VALUES
        (p_employee_id, p_note_type, p_note_text, p_from_date, p_to_date, p_until_date, auth.uid())
    RETURNING id INTO v_id;

    RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_hr_salary_note(text,text,text,date,date,date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_hr_salary_note(text,text,text,date,date,date) TO anon;

-- RPC: delete a note
CREATE OR REPLACE FUNCTION public.delete_hr_salary_note(p_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    DELETE FROM public.hr_salary_notes WHERE id = p_id;
    RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_hr_salary_note(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_hr_salary_note(uuid) TO anon;
