-- Reduce the delay between a fingerprint punch and attendance analysis.
-- cron.alter_job preserves each production job's existing command and credentials.
DO $$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid, jobname
    FROM cron.job
    WHERE jobname IN ('process-fingerprints-hourly', 'analyze-attendance-auto')
  LOOP
    PERFORM cron.alter_job(
      job_id := v_job.jobid,
      schedule := CASE v_job.jobname
        WHEN 'process-fingerprints-hourly' THEN '*/2 * * * *'
        WHEN 'analyze-attendance-auto' THEN '*/3 * * * *'
      END
    );
  END LOOP;
END
$$;
