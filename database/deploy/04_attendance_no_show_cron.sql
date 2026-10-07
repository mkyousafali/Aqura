-- Production activation checklist. If this job is installed before Meta approval,
-- keep attendance monitoring/recipient configuration empty until approval and testing.
-- 1. 20261007_attendance_no_show_notifications.sql has been applied.
-- 2. The attendance-no-show and email-send Edge Functions are deployed.
-- 3. The Meta template `attendance_not_reported_ar` is approved and available.
-- 4. WhatsApp and transactional email accounts have been tested.

do $cron$
declare
  v_job record;
begin
  for v_job in select jobid from cron.job where jobname = 'attendance-no-show-check-1m' loop
    perform cron.unschedule(v_job.jobid);
  end loop;

  perform cron.schedule(
    'attendance-no-show-check-1m',
    '* * * * *',
    $job$
      select net.http_post(
        url := coalesce(
          (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_url' limit 1),
          'http://supabase-kong:8000'
        ) || '/functions/v1/attendance-no-show',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key' limit 1)
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 50000
      );
    $job$
  );
end;
$cron$;
