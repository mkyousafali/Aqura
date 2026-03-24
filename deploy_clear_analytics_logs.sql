CREATE OR REPLACE FUNCTION public.clear_analytics_logs()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  tbl record;
  cnt int := 0;
  total_freed bigint := 0;
  tbl_size bigint;
  db_size_before bigint;
  db_size_after bigint;
BEGIN
  -- Get _supabase database size before
  SELECT pg_database_size('_supabase') INTO db_size_before;

  -- Use dblink to truncate tables in _supabase database
  PERFORM dblink_connect('analytics_conn', 'dbname=_supabase user=supabase_admin');

  FOR tbl IN
    SELECT t.tablename FROM dblink('analytics_conn',
      'SELECT tablename::text FROM pg_tables WHERE schemaname = ''_analytics'' AND tablename LIKE ''log_events_%'''
    ) AS t(tablename text)
  LOOP
    PERFORM dblink_exec('analytics_conn', format('TRUNCATE TABLE _analytics.%I', tbl.tablename));
    cnt := cnt + 1;
  END LOOP;

  -- Vacuum to reclaim space
  IF cnt > 0 THEN
    PERFORM dblink_exec('analytics_conn', 'VACUUM FULL');
  END IF;

  PERFORM dblink_disconnect('analytics_conn');

  -- Get _supabase database size after
  SELECT pg_database_size('_supabase') INTO db_size_after;

  RETURN format('Cleared %s log tables, freed ~%s', cnt, pg_size_pretty(GREATEST(db_size_before - db_size_after, 0)));
END;
$$;

GRANT EXECUTE ON FUNCTION public.clear_analytics_logs() TO service_role;
