begin;

alter table public.erp_connections
  add column if not exists vendor_last_auto_sync_at timestamp with time zone;

comment on column public.erp_connections.vendor_last_auto_sync_at is
  'Most recent successful scheduled ERP vendor synchronization for this branch.';

create or replace function public.enforce_vendor_sync_switches()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.vendor_sync_enabled is not true then
    new.vendor_auto_sync_enabled := false;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_vendor_sync_switches on public.erp_connections;
create trigger enforce_vendor_sync_switches
before insert or update of vendor_sync_enabled, vendor_auto_sync_enabled
on public.erp_connections
for each row execute function public.enforce_vendor_sync_switches();

do $$
declare
  existing_job record;
begin
  for existing_job in
    select jobid from cron.job where jobname = 'erp-vendor-sync-every-6-hours'
  loop
    perform cron.unschedule(existing_job.jobid);
  end loop;
end $$;

select cron.schedule(
  'erp-vendor-sync-every-6-hours',
  '0 */6 * * *',
  $job$
    select net.http_post(
      url := coalesce(
        (select decrypted_secret from vault.decrypted_secrets where name = 'supabase_url' limit 1),
        'http://supabase-kong:8000'
      ) || '/functions/v1/sync-erp-vendors',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key' limit 1)
      ),
      body := jsonb_build_object(
        'branchId', branch_id,
        'syncMode', 'auto'
      ),
      timeout_milliseconds := 240000
    )
    from public.erp_connections
    where is_active is true
      and vendor_sync_enabled is true
      and vendor_auto_sync_enabled is true
      and tunnel_url is not null
      and btrim(tunnel_url) <> ''
      and bridge_api_secret is not null
      and btrim(bridge_api_secret) <> ''
      and erp_branch_id is not null;
  $job$
);

notify pgrst, 'reload schema';

commit;
