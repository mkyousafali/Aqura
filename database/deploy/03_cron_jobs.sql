-- Requires pg_cron extension (see 00_extensions.sql).
-- SECURITY: replace <SERVICE_ROLE_JWT> below with your own service_role key. Never commit real keys.
select cron.schedule('process-fingerprints-hourly', '*/5 * * * *', '
  SELECT net.http_post(
    url := ''http://supabase-kong:8000/functions/v1/process-fingerprints'',
    headers := jsonb_build_object(
      ''Content-Type'', ''application/json'',
      ''Authorization'', ''Bearer <SERVICE_ROLE_JWT>''
    ),
    body := ''{}''::jsonb
  );
  ');
select cron.schedule('analyze-attendance-auto', '3,13,23,33,43,53 * * * *', 'SELECT net.http_post(url := ''http://supabase-kong:8000/functions/v1/analyze-attendance'', headers := jsonb_build_object(''Content-Type'', ''application/json'', ''Authorization'', ''Bearer <SERVICE_ROLE_JWT>''), body := ''{"rollingDays": 3}''::jsonb);');
select cron.schedule('vip-campaign-schedule-check', '* * * * *', 'SELECT public.check_vip_campaign_schedule()');
select cron.schedule('broadcast-watchdog', '*/2 * * * *', 'SELECT public.broadcast_watchdog()');
select cron.schedule('generate-followup-occurrences', '0 0 * * *', 'SELECT public.generate_followup_occurrences();');
select cron.schedule('expire-view-offers', '* * * * *', 'SELECT public.expire_view_offers();');
