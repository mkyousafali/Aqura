-- Shift management now uses the versioned hr_*_versions and hr_*_slots tables.
-- Historical rows in these legacy tables are intentionally discarded.
-- RESTRICT stops the entire transaction if another database object depends on any table.
BEGIN;

DROP TABLE IF EXISTS
    public.regular_shift,
    public.special_shift_date_wise,
    public.special_shift_weekday,
    public.multi_shift_date_wise,
    public.multi_shift_regular,
    public.multi_shift_weekday
RESTRICT;

COMMIT;
