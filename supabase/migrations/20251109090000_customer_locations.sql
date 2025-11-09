-- Add customer location fields (up to 3 locations with name + URL + coordinates)
-- Created at: 2025-11-09

begin;

alter table public.customers
  add column if not exists location1_name text null,
  add column if not exists location1_url  text null,
  add column if not exists location1_lat  double precision null,
  add column if not exists location1_lng  double precision null,
  add column if not exists location2_name text null,
  add column if not exists location2_url  text null,
  add column if not exists location2_lat  double precision null,
  add column if not exists location2_lng  double precision null,
  add column if not exists location3_name text null,
  add column if not exists location3_url  text null,
  add column if not exists location3_lat  double precision null,
  add column if not exists location3_lng  double precision null;

-- Optional basic length constraints to prevent absurdly long URLs/names
-- PostgreSQL does not support IF NOT EXISTS for ADD CONSTRAINT; use catalog checks
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'customers_location1_name_len') then
    alter table public.customers add constraint customers_location1_name_len check (location1_name is null or length(location1_name) <= 120);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'customers_location2_name_len') then
    alter table public.customers add constraint customers_location2_name_len check (location2_name is null or length(location2_name) <= 120);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'customers_location3_name_len') then
    alter table public.customers add constraint customers_location3_name_len check (location3_name is null or length(location3_name) <= 120);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'customers_location1_url_len') then
    alter table public.customers add constraint customers_location1_url_len check (location1_url is null or length(location1_url) <= 2048);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'customers_location2_url_len') then
    alter table public.customers add constraint customers_location2_url_len check (location2_url is null or length(location2_url) <= 2048);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'customers_location3_url_len') then
    alter table public.customers add constraint customers_location3_url_len check (location3_url is null or length(location3_url) <= 2048);
  end if;
end $$;

-- Touch updated_at via trigger on update; no data backfill required

commit;
