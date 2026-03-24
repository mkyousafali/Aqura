CREATE OR REPLACE FUNCTION public.get_analytics_log_tables()
RETURNS TABLE(
  table_name text,
  total_size text,
  raw_size bigint,
  row_estimate bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.tablename AS table_name,
    r.total_size,
    r.raw_size,
    r.row_estimate
  FROM dblink(
    'dbname=_supabase user=supabase_admin',
    'SELECT
      t.tablename::text,
      pg_size_pretty(pg_total_relation_size(quote_ident(t.schemaname) || ''.'' || quote_ident(t.tablename)))::text AS total_size,
      pg_total_relation_size(quote_ident(t.schemaname) || ''.'' || quote_ident(t.tablename)) AS raw_size,
      COALESCE(c.reltuples, 0)::bigint AS row_estimate
    FROM pg_tables t
    LEFT JOIN pg_class c ON c.relname = t.tablename AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = t.schemaname)
    WHERE t.schemaname = ''_analytics'' AND t.tablename LIKE ''log_events_%''
    ORDER BY pg_total_relation_size(quote_ident(t.schemaname) || ''.'' || quote_ident(t.tablename)) DESC'
  ) AS r(tablename text, total_size text, raw_size bigint, row_estimate bigint);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_analytics_log_tables() TO service_role;
