begin;

alter table public.erp_connections
  add column if not exists vendor_sync_enabled boolean not null default false,
  add column if not exists vendor_auto_sync_enabled boolean not null default false;

comment on column public.erp_connections.vendor_sync_enabled is
  'Allows manual ERP vendor synchronization for this branch.';

comment on column public.erp_connections.vendor_auto_sync_enabled is
  'Allows scheduled ERP vendor synchronization for this branch.';

notify pgrst, 'reload schema';

commit;
