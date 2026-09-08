-- ============================================================================
-- Shifts Module Migration — Step: Create new versioned tables + backfill
-- Generated 2026-08-02. Old tables are NOT touched/dropped by this script.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Shared trigger function for updated_at (new tables only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_shift_module_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$function$;

-- ============================================================================
-- 1. hr_regular_shift_versions / hr_regular_shift_slots
-- ============================================================================
CREATE TABLE public.hr_regular_shift_versions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id text NOT NULL REFERENCES public.hr_employee_master(id) ON DELETE CASCADE,
    date_from date NOT NULL DEFAULT '2020-01-01',
    date_to date,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT hr_regular_shift_versions_date_check CHECK (date_to IS NULL OR date_to >= date_from)
);
CREATE INDEX idx_hr_regular_shift_versions_employee_id ON public.hr_regular_shift_versions USING btree (employee_id);
CREATE INDEX idx_hr_regular_shift_versions_dates ON public.hr_regular_shift_versions USING btree (date_from, date_to);
ALTER TABLE public.hr_regular_shift_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to hr_regular_shift_versions" ON public.hr_regular_shift_versions FOR ALL USING (true) WITH CHECK (true);
CREATE TRIGGER hr_regular_shift_versions_timestamp_update BEFORE UPDATE ON public.hr_regular_shift_versions
    FOR EACH ROW EXECUTE FUNCTION public.set_shift_module_updated_at();

CREATE TABLE public.hr_regular_shift_slots (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version_id bigint NOT NULL REFERENCES public.hr_regular_shift_versions(id) ON DELETE CASCADE,
    slot_order integer NOT NULL DEFAULT 1,
    shift_start_time time NOT NULL DEFAULT '09:00:00',
    shift_start_buffer numeric(4,2) NOT NULL DEFAULT 0,
    shift_end_time time NOT NULL DEFAULT '17:00:00',
    shift_end_buffer numeric(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day boolean NOT NULL DEFAULT false,
    working_hours numeric(5,2) DEFAULT 0,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_hr_regular_shift_slots_version_id ON public.hr_regular_shift_slots USING btree (version_id);
ALTER TABLE public.hr_regular_shift_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to hr_regular_shift_slots" ON public.hr_regular_shift_slots FOR ALL USING (true) WITH CHECK (true);
CREATE TRIGGER hr_regular_shift_slots_timestamp_update BEFORE UPDATE ON public.hr_regular_shift_slots
    FOR EACH ROW EXECUTE FUNCTION public.set_shift_module_updated_at();
CREATE TRIGGER hr_regular_shift_slots_working_hours_trigger BEFORE INSERT OR UPDATE ON public.hr_regular_shift_slots
    FOR EACH ROW EXECUTE FUNCTION public.calculate_working_hours();

-- ============================================================================
-- 2. hr_special_shift_weekday_versions / hr_special_shift_weekday_slots
-- ============================================================================
CREATE TABLE public.hr_special_shift_weekday_versions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id text NOT NULL REFERENCES public.hr_employee_master(id) ON DELETE CASCADE,
    weekday integer NOT NULL,
    date_from date NOT NULL DEFAULT '2020-01-01',
    date_to date,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT hr_special_shift_weekday_versions_weekday_check CHECK (weekday >= 0 AND weekday <= 6),
    CONSTRAINT hr_special_shift_weekday_versions_date_check CHECK (date_to IS NULL OR date_to >= date_from)
);
CREATE INDEX idx_hr_special_shift_weekday_versions_employee_id ON public.hr_special_shift_weekday_versions USING btree (employee_id);
CREATE INDEX idx_hr_special_shift_weekday_versions_weekday ON public.hr_special_shift_weekday_versions USING btree (weekday);
CREATE INDEX idx_hr_special_shift_weekday_versions_dates ON public.hr_special_shift_weekday_versions USING btree (date_from, date_to);
ALTER TABLE public.hr_special_shift_weekday_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to hr_special_shift_weekday_versions" ON public.hr_special_shift_weekday_versions FOR ALL USING (true) WITH CHECK (true);
CREATE TRIGGER hr_special_shift_weekday_versions_timestamp_update BEFORE UPDATE ON public.hr_special_shift_weekday_versions
    FOR EACH ROW EXECUTE FUNCTION public.set_shift_module_updated_at();

CREATE TABLE public.hr_special_shift_weekday_slots (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version_id bigint NOT NULL REFERENCES public.hr_special_shift_weekday_versions(id) ON DELETE CASCADE,
    slot_order integer NOT NULL DEFAULT 1,
    shift_start_time time NOT NULL DEFAULT '09:00:00',
    shift_start_buffer numeric(4,2) NOT NULL DEFAULT 0,
    shift_end_time time NOT NULL DEFAULT '17:00:00',
    shift_end_buffer numeric(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day boolean NOT NULL DEFAULT false,
    working_hours numeric(5,2) DEFAULT 0,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_hr_special_shift_weekday_slots_version_id ON public.hr_special_shift_weekday_slots USING btree (version_id);
ALTER TABLE public.hr_special_shift_weekday_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to hr_special_shift_weekday_slots" ON public.hr_special_shift_weekday_slots FOR ALL USING (true) WITH CHECK (true);
CREATE TRIGGER hr_special_shift_weekday_slots_timestamp_update BEFORE UPDATE ON public.hr_special_shift_weekday_slots
    FOR EACH ROW EXECUTE FUNCTION public.set_shift_module_updated_at();
CREATE TRIGGER hr_special_shift_weekday_slots_working_hours_trigger BEFORE INSERT OR UPDATE ON public.hr_special_shift_weekday_slots
    FOR EACH ROW EXECUTE FUNCTION public.calculate_working_hours();

-- ============================================================================
-- 3. hr_special_shift_date_wise_versions / hr_special_shift_date_wise_slots
-- ============================================================================
CREATE TABLE public.hr_special_shift_date_wise_versions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id text NOT NULL REFERENCES public.hr_employee_master(id) ON DELETE CASCADE,
    date_from date NOT NULL,
    date_to date NOT NULL,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT hr_special_shift_date_wise_versions_date_check CHECK (date_from <= date_to)
);
CREATE INDEX idx_hr_special_shift_date_wise_versions_employee_id ON public.hr_special_shift_date_wise_versions USING btree (employee_id);
CREATE INDEX idx_hr_special_shift_date_wise_versions_dates ON public.hr_special_shift_date_wise_versions USING btree (date_from, date_to);
ALTER TABLE public.hr_special_shift_date_wise_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to hr_special_shift_date_wise_versions" ON public.hr_special_shift_date_wise_versions FOR ALL USING (true) WITH CHECK (true);
CREATE TRIGGER hr_special_shift_date_wise_versions_timestamp_update BEFORE UPDATE ON public.hr_special_shift_date_wise_versions
    FOR EACH ROW EXECUTE FUNCTION public.set_shift_module_updated_at();

CREATE TABLE public.hr_special_shift_date_wise_slots (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version_id bigint NOT NULL REFERENCES public.hr_special_shift_date_wise_versions(id) ON DELETE CASCADE,
    slot_order integer NOT NULL DEFAULT 1,
    shift_start_time time NOT NULL DEFAULT '09:00:00',
    shift_start_buffer numeric(4,2) NOT NULL DEFAULT 0,
    shift_end_time time NOT NULL DEFAULT '17:00:00',
    shift_end_buffer numeric(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day boolean NOT NULL DEFAULT false,
    working_hours numeric(5,2) DEFAULT 0,
    created_at timestamptz DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_hr_special_shift_date_wise_slots_version_id ON public.hr_special_shift_date_wise_slots USING btree (version_id);
ALTER TABLE public.hr_special_shift_date_wise_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to hr_special_shift_date_wise_slots" ON public.hr_special_shift_date_wise_slots FOR ALL USING (true) WITH CHECK (true);
CREATE TRIGGER hr_special_shift_date_wise_slots_timestamp_update BEFORE UPDATE ON public.hr_special_shift_date_wise_slots
    FOR EACH ROW EXECUTE FUNCTION public.set_shift_module_updated_at();
CREATE TRIGGER hr_special_shift_date_wise_slots_working_hours_trigger BEFORE INSERT OR UPDATE ON public.hr_special_shift_date_wise_slots
    FOR EACH ROW EXECUTE FUNCTION public.calculate_working_hours();

-- ============================================================================
-- BACKFILL
-- ============================================================================

-- --- 1a. regular_shift (75 rows) -> 1 version + 1 slot each ---
INSERT INTO public.hr_regular_shift_versions (employee_id, date_from, date_to, created_at, updated_at)
SELECT id, '2020-01-01'::date, NULL, created_at, updated_at FROM public.regular_shift;

INSERT INTO public.hr_regular_shift_slots (version_id, slot_order, shift_start_time, shift_start_buffer, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day, working_hours, created_at, updated_at)
SELECT v.id, 1, r.shift_start_time, COALESCE(r.shift_start_buffer,0), r.shift_end_time, COALESCE(r.shift_end_buffer,0), r.is_shift_overlapping_next_day, COALESCE(r.working_hours,0), r.created_at, r.updated_at
FROM public.regular_shift r
JOIN public.hr_regular_shift_versions v ON v.employee_id = r.id;

-- --- 1b. multi_shift_regular (2 rows, EMP30 only, no regular_shift row exists for EMP30) ---
INSERT INTO public.hr_regular_shift_versions (employee_id, date_from, date_to, created_at, updated_at)
SELECT m.employee_id, '2020-01-01'::date, NULL, MIN(m.created_at), now()
FROM public.multi_shift_regular m
WHERE NOT EXISTS (SELECT 1 FROM public.hr_regular_shift_versions v WHERE v.employee_id = m.employee_id)
GROUP BY m.employee_id;

INSERT INTO public.hr_regular_shift_slots (version_id, slot_order, shift_start_time, shift_start_buffer, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day, working_hours, created_at, updated_at)
SELECT v.id, ROW_NUMBER() OVER (PARTITION BY m.employee_id ORDER BY m.id), m.shift_start_time, COALESCE(m.shift_start_buffer,0), m.shift_end_time, COALESCE(m.shift_end_buffer,0), m.is_shift_overlapping_next_day, COALESCE(m.working_hours,0), m.created_at, m.updated_at
FROM public.multi_shift_regular m
JOIN public.hr_regular_shift_versions v ON v.employee_id = m.employee_id;

-- --- 2. special_shift_weekday (15 rows) -> 1 version + 1 slot each; multi_shift_weekday is empty (nothing to backfill) ---
INSERT INTO public.hr_special_shift_weekday_versions (employee_id, weekday, date_from, date_to, created_at, updated_at)
SELECT employee_id, weekday, '2020-01-01'::date, NULL, created_at, updated_at FROM public.special_shift_weekday;

INSERT INTO public.hr_special_shift_weekday_slots (version_id, slot_order, shift_start_time, shift_start_buffer, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day, working_hours, created_at, updated_at)
SELECT v.id, 1, s.shift_start_time, COALESCE(s.shift_start_buffer,0), s.shift_end_time, COALESCE(s.shift_end_buffer,0), s.is_shift_overlapping_next_day, COALESCE(s.working_hours,0), s.created_at, s.updated_at
FROM public.special_shift_weekday s
JOIN public.hr_special_shift_weekday_versions v ON v.employee_id = s.employee_id AND v.weekday = s.weekday;

-- --- 3. special_shift_date_wise (2582 rows) -> straight 1:1 copy, 1 version + 1 slot each; multi_shift_date_wise is empty ---
INSERT INTO public.hr_special_shift_date_wise_versions (employee_id, date_from, date_to, created_at, updated_at)
SELECT employee_id, shift_date, shift_date, created_at, updated_at FROM public.special_shift_date_wise;

INSERT INTO public.hr_special_shift_date_wise_slots (version_id, slot_order, shift_start_time, shift_start_buffer, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day, working_hours, created_at, updated_at)
SELECT v.id, 1, s.shift_start_time, COALESCE(s.shift_start_buffer,0), s.shift_end_time, COALESCE(s.shift_end_buffer,0), s.is_shift_overlapping_next_day, COALESCE(s.working_hours,0), s.created_at, s.updated_at
FROM public.special_shift_date_wise s
JOIN public.hr_special_shift_date_wise_versions v ON v.employee_id = s.employee_id AND v.date_from = s.shift_date;

COMMIT;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
SELECT 'hr_regular_shift_versions' AS tbl, COUNT(*) FROM public.hr_regular_shift_versions
UNION ALL SELECT 'hr_regular_shift_slots', COUNT(*) FROM public.hr_regular_shift_slots
UNION ALL SELECT 'hr_special_shift_weekday_versions', COUNT(*) FROM public.hr_special_shift_weekday_versions
UNION ALL SELECT 'hr_special_shift_weekday_slots', COUNT(*) FROM public.hr_special_shift_weekday_slots
UNION ALL SELECT 'hr_special_shift_date_wise_versions', COUNT(*) FROM public.hr_special_shift_date_wise_versions
UNION ALL SELECT 'hr_special_shift_date_wise_slots', COUNT(*) FROM public.hr_special_shift_date_wise_slots;
