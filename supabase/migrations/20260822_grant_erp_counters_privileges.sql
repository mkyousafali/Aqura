-- erp_counters was created with RLS policies but no table-level GRANTs beyond the
-- default SELECT for anon/authenticated — Postgres privileges gate access before RLS
-- ever runs, so anon inserts/upserts from the frontend failed with
-- "permission denied for table erp_counters" (42501). Match erp_connections' grants,
-- since the frontend writes this table with the anon key (no authenticated session).

GRANT INSERT, UPDATE, DELETE ON public.erp_counters TO anon;
GRANT INSERT, UPDATE, DELETE ON public.erp_counters TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.erp_counters_id_seq TO anon, authenticated;
