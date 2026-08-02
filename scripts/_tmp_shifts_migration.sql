-- Shifts Module: new versioned tables (regular / weekday / date-wise), each with a slots child table.
-- Runs inside a single transaction: if anything fails, everything rolls back (old tables untouched).

BEGIN;

-- =========================================================
-- 1. regular_shift_versions / regular_shift_slots
-- =========================================================
CREATE TABLE public.regular_shift_versions (
    id bigserial PRIMARY KEY,
    employee_id text NOT NULL,
    date_from date NOT NULL,
    date_to date,
    legacy_id text, -- traceability: source regular_shift.id this version was backfilled from
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT regular_shift_versions_date_check CHECK (date_to IS NULL OR date_to >= date_from)
);

CREATE TABLE public.regular_shift_slots (
    id bigserial PRIMARY KEY,
    version_id bigint NOT NULL REFERENCES public.regular_shift_versions(id) ON DELETE CASCADE,
    slot_order integer NOT NULL DEFAULT 1,
    shift_start_time time without time zone NOT NULL DEFAULT '09:00:00',
    shift_start_buffer numeric(4,2) NOT NULL DEFAULT 0,
    shift_end_time time without time zone NOT NULL DEFAULT '17:00:00',
    shift_end_buffer numeric(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day boolean NOT NULL DEFAULT false,
    working_hours numeric(5,2) NOT NULL DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_regular_shift_versions_employee_id ON public.regular_shift_versions USING btree (employee_id);
CREATE INDEX idx_regular_shift_versions_date_range ON public.regular_shift_versions USING btree (employee_id, date_from, date_to);
CREATE INDEX idx_regular_shift_slots_version_id ON public.regular_shift_slots USING btree (version_id);

ALTER TABLE public.regular_shift_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.regular_shift_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to regular_shift_versions" ON public.regular_shift_versions USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to regular_shift_slots" ON public.regular_shift_slots USING (true) WITH CHECK (true);

CREATE TRIGGER regular_shift_versions_timestamp_update BEFORE UPDATE ON public.regular_shift_versions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER regular_shift_slots_timestamp_update BEFORE UPDATE ON public.regular_shift_slots FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================================================
-- 2. special_shift_weekday_versions / special_shift_weekday_slots
-- =========================================================
CREATE TABLE public.special_shift_weekday_versions (
    id bigserial PRIMARY KEY,
    employee_id text NOT NULL,
    weekday integer NOT NULL,
    date_from date NOT NULL,
    date_to date,
    legacy_id text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT special_shift_weekday_versions_weekday_check CHECK (weekday >= 0 AND weekday <= 6),
    CONSTRAINT special_shift_weekday_versions_date_check CHECK (date_to IS NULL OR date_to >= date_from)
);

CREATE TABLE public.special_shift_weekday_slots (
    id bigserial PRIMARY KEY,
    version_id bigint NOT NULL REFERENCES public.special_shift_weekday_versions(id) ON DELETE CASCADE,
    slot_order integer NOT NULL DEFAULT 1,
    shift_start_time time without time zone NOT NULL DEFAULT '09:00:00',
    shift_start_buffer numeric(4,2) NOT NULL DEFAULT 0,
    shift_end_time time without time zone NOT NULL DEFAULT '17:00:00',
    shift_end_buffer numeric(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day boolean NOT NULL DEFAULT false,
    working_hours numeric(5,2) NOT NULL DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_special_shift_weekday_versions_employee_id ON public.special_shift_weekday_versions USING btree (employee_id);
CREATE INDEX idx_special_shift_weekday_versions_weekday ON public.special_shift_weekday_versions USING btree (employee_id, weekday, date_from, date_to);
CREATE INDEX idx_special_shift_weekday_slots_version_id ON public.special_shift_weekday_slots USING btree (version_id);

ALTER TABLE public.special_shift_weekday_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.special_shift_weekday_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to special_shift_weekday_versions" ON public.special_shift_weekday_versions USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to special_shift_weekday_slots" ON public.special_shift_weekday_slots USING (true) WITH CHECK (true);

CREATE TRIGGER special_shift_weekday_versions_timestamp_update BEFORE UPDATE ON public.special_shift_weekday_versions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER special_shift_weekday_slots_timestamp_update BEFORE UPDATE ON public.special_shift_weekday_slots FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================================================
-- 3. special_shift_date_wise_versions / special_shift_date_wise_slots
-- =========================================================
CREATE TABLE public.special_shift_date_wise_versions (
    id bigserial PRIMARY KEY,
    employee_id text NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    legacy_id text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT special_shift_date_wise_versions_date_check CHECK (date_to >= date_from)
);

CREATE TABLE public.special_shift_date_wise_slots (
    id bigserial PRIMARY KEY,
    version_id bigint NOT NULL REFERENCES public.special_shift_date_wise_versions(id) ON DELETE CASCADE,
    slot_order integer NOT NULL DEFAULT 1,
    shift_start_time time without time zone NOT NULL DEFAULT '09:00:00',
    shift_start_buffer numeric(4,2) NOT NULL DEFAULT 0,
    shift_end_time time without time zone NOT NULL DEFAULT '17:00:00',
    shift_end_buffer numeric(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day boolean NOT NULL DEFAULT false,
    working_hours numeric(5,2) NOT NULL DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_special_shift_date_wise_versions_employee_id ON public.special_shift_date_wise_versions USING btree (employee_id);
CREATE INDEX idx_special_shift_date_wise_versions_date_range ON public.special_shift_date_wise_versions USING btree (employee_id, date_from, date_to);
CREATE INDEX idx_special_shift_date_wise_slots_version_id ON public.special_shift_date_wise_slots USING btree (version_id);

ALTER TABLE public.special_shift_date_wise_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.special_shift_date_wise_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to special_shift_date_wise_versions" ON public.special_shift_date_wise_versions USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to special_shift_date_wise_slots" ON public.special_shift_date_wise_slots USING (true) WITH CHECK (true);

CREATE TRIGGER special_shift_date_wise_versions_timestamp_update BEFORE UPDATE ON public.special_shift_date_wise_versions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER special_shift_date_wise_slots_timestamp_update BEFORE UPDATE ON public.special_shift_date_wise_slots FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =========================================================
-- 4. Backfill: regular_shift (+ multi_shift_regular) -> regular_shift_versions/slots
-- =========================================================
INSERT INTO public.regular_shift_versions (employee_id, date_from, date_to, legacy_id)
SELECT id, DATE '2020-01-01', NULL, id
FROM public.regular_shift;

-- single-slot employees (no multi-shift override)
INSERT INTO public.regular_shift_slots (version_id, slot_order, shift_start_time, shift_start_buffer, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day, working_hours)
SELECT v.id, 1, r.shift_start_time, r.shift_start_buffer, r.shift_end_time, r.shift_end_buffer, r.is_shift_overlapping_next_day, r.working_hours
FROM public.regular_shift r
JOIN public.regular_shift_versions v ON v.legacy_id = r.id
WHERE r.id NOT IN (SELECT DISTINCT employee_id FROM public.multi_shift_regular);

-- multi-slot employees: slots come from multi_shift_regular instead of the single regular_shift row
INSERT INTO public.regular_shift_slots (version_id, slot_order, shift_start_time, shift_start_buffer, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day, working_hours)
SELECT v.id, ROW_NUMBER() OVER (PARTITION BY m.employee_id ORDER BY m.shift_start_time), m.shift_start_time, m.shift_start_buffer, m.shift_end_time, m.shift_end_buffer, m.is_shift_overlapping_next_day, m.working_hours
FROM public.multi_shift_regular m
JOIN public.regular_shift_versions v ON v.legacy_id = m.employee_id;

-- =========================================================
-- 5. Backfill: special_shift_weekday (+ multi_shift_weekday, currently empty) -> versions/slots
-- =========================================================
INSERT INTO public.special_shift_weekday_versions (employee_id, weekday, date_from, date_to, legacy_id)
SELECT employee_id, weekday, DATE '2020-01-01', NULL, id
FROM public.special_shift_weekday;

INSERT INTO public.special_shift_weekday_slots (version_id, slot_order, shift_start_time, shift_start_buffer, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day, working_hours)
SELECT v.id, 1, s.shift_start_time, s.shift_start_buffer, s.shift_end_time, s.shift_end_buffer, s.is_shift_overlapping_next_day, s.working_hours
FROM public.special_shift_weekday s
JOIN public.special_shift_weekday_versions v ON v.legacy_id = s.id;

-- (multi_shift_weekday is empty on live DB - nothing to merge)

-- =========================================================
-- 6. Backfill: special_shift_date_wise -> versions/slots (straight 1:1 copy, confirmed decision)
-- =========================================================
INSERT INTO public.special_shift_date_wise_versions (employee_id, date_from, date_to, legacy_id)
SELECT employee_id, shift_date, shift_date, id
FROM public.special_shift_date_wise;

INSERT INTO public.special_shift_date_wise_slots (version_id, slot_order, shift_start_time, shift_start_buffer, shift_end_time, shift_end_buffer, is_shift_overlapping_next_day, working_hours)
SELECT v.id, 1, s.shift_start_time, s.shift_start_buffer, s.shift_end_time, s.shift_end_buffer, s.is_shift_overlapping_next_day, s.working_hours
FROM public.special_shift_date_wise s
JOIN public.special_shift_date_wise_versions v ON v.legacy_id = s.id;

-- (multi_shift_date_wise is empty on live DB - nothing to merge)

-- =========================================================
-- 7. Verification counts (printed before COMMIT)
-- =========================================================
SELECT 'regular_shift' AS src, count(*) FROM public.regular_shift
UNION ALL SELECT 'regular_shift_versions', count(*) FROM public.regular_shift_versions
UNION ALL SELECT 'regular_shift_slots', count(*) FROM public.regular_shift_slots
UNION ALL SELECT 'multi_shift_regular', count(*) FROM public.multi_shift_regular
UNION ALL SELECT 'special_shift_weekday', count(*) FROM public.special_shift_weekday
UNION ALL SELECT 'special_shift_weekday_versions', count(*) FROM public.special_shift_weekday_versions
UNION ALL SELECT 'special_shift_weekday_slots', count(*) FROM public.special_shift_weekday_slots
UNION ALL SELECT 'special_shift_date_wise', count(*) FROM public.special_shift_date_wise
UNION ALL SELECT 'special_shift_date_wise_versions', count(*) FROM public.special_shift_date_wise_versions
UNION ALL SELECT 'special_shift_date_wise_slots', count(*) FROM public.special_shift_date_wise_slots;

COMMIT;
