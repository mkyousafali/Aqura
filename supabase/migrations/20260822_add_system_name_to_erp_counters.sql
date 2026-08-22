-- Counter names alone aren't reliably unique per PC (e.g. two counters both named
-- "Primary" have been observed on the same branch). UserActions.SystemName (the
-- Windows hostname, logged on every print/action) is the actual per-PC identifier,
-- so cache each counter's most-recently-seen SystemName alongside its name.

ALTER TABLE public.erp_counters ADD COLUMN IF NOT EXISTS system_name TEXT;
