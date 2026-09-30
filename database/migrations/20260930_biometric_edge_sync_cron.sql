DO $$
DECLARE job record;
BEGIN
  FOR job IN SELECT jobid FROM cron.job WHERE jobname IN ('biometric-punch-sync-5m','biometric-employee-sync-hourly') LOOP
    PERFORM cron.unschedule(job.jobid);
  END LOOP;
END $$;

SELECT cron.schedule(
  'biometric-punch-sync-5m',
  '*/5 * * * *',
  $job$
    SELECT net.http_post(
      url := COALESCE(
        (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='supabase_url' LIMIT 1),
        'http://supabase-kong:8000'
      ) || '/functions/v1/biometric-sync',
      headers := jsonb_build_object(
        'Content-Type','application/json',
        'Authorization','Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='service_role_key' LIMIT 1)
      ),
      body := '{"syncType":"punches","triggerType":"scheduled","windowDays":3}'::jsonb,
      timeout_milliseconds := 240000
    );
  $job$
);

SELECT cron.schedule(
  'biometric-employee-sync-hourly',
  '2 * * * *',
  $job$
    SELECT net.http_post(
      url := COALESCE(
        (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='supabase_url' LIMIT 1),
        'http://supabase-kong:8000'
      ) || '/functions/v1/biometric-sync',
      headers := jsonb_build_object(
        'Content-Type','application/json',
        'Authorization','Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='service_role_key' LIMIT 1)
      ),
      body := '{"syncType":"employees","triggerType":"scheduled"}'::jsonb,
      timeout_milliseconds := 240000
    );
  $job$
);
