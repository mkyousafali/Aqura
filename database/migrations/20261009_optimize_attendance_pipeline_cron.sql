-- Keep the biometric-to-notification pipeline current with whole-minute pg_cron schedules.
-- Existing commands and production credentials are preserved; only schedules change.
DO $$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid, jobname
    FROM cron.job
    WHERE jobname IN (
      'biometric-punch-sync-5m',
      'process-fingerprints-hourly',
      'analyze-attendance-auto',
      'attendance-no-show-check-1m',
      'biometric-employee-sync-hourly'
    )
  LOOP
    PERFORM cron.alter_job(
      job_id := v_job.jobid,
      schedule := CASE v_job.jobname
        WHEN 'biometric-punch-sync-5m' THEN '* * * * *'
        WHEN 'process-fingerprints-hourly' THEN '*/2 * * * *'
        WHEN 'analyze-attendance-auto' THEN '*/2 * * * *'
        WHEN 'attendance-no-show-check-1m' THEN '* * * * *'
        WHEN 'biometric-employee-sync-hourly' THEN '*/10 * * * *'
      END
    );
  END LOOP;
END
$$;
