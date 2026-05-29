-- Add is_paid and is_manual_hr_entry columns to day_off table
-- is_paid: HR marks an approved annual leave day as paid from the leave balance
-- is_manual_hr_entry: distinguishes dates manually added via HR Services UI vs organic day_off requests

ALTER TABLE public.day_off
    ADD COLUMN IF NOT EXISTS is_paid boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_manual_hr_entry boolean NOT NULL DEFAULT false;

-- Ensure RLS policies and grants cover new columns (table-level grants already exist)
GRANT ALL ON TABLE public.day_off TO anon;
GRANT ALL ON TABLE public.day_off TO authenticated;
GRANT ALL ON TABLE public.day_off TO service_role;
GRANT SELECT ON TABLE public.day_off TO replication_user;
