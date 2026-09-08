-- The 20260901_recreate_user_erp_credentials.sql migration created RLS
-- policies but never granted table-level privileges, so anon/authenticated
-- only had the default SELECT grant — every INSERT/UPDATE from the app hit
-- "permission denied for table user_erp_credentials" (a grant error, not an
-- RLS policy error). Matches the grants other permissive tables in this
-- schema (e.g. erp_connections) carry for anon/authenticated.

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_erp_credentials TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_erp_credentials TO authenticated;
