-- Phase 1 compatibility policy reset.
--
-- WARNING: This intentionally gives every Supabase `authenticated` identity
-- broad access to the public application schema. It is a temporary bridge and
-- must be replaced by role/branch/permission/ownership policies in Phase 2.
--
-- Restore point:
-- database/backups/rls_policies_before_authenticated_migration_20261004.sql

begin;

-- Remove every existing RLS policy from application and Storage schemas.
do $$
declare
  item record;
begin
  for item in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname in ('public', 'storage')
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      item.policyname,
      item.schemaname,
      item.tablename
    );
  end loop;
end
$$;

-- Give authenticated sessions broad compatibility grants across public tables,
-- views, sequences, and RPCs.
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select, update on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- Views cannot have RLS policies. Remove legacy anonymous grants so the
-- dashboard's "Unrestricted" views are still inaccessible before sign-in.
do $$
declare
  item record;
begin
  for item in
    select n.nspname as schema_name, c.relname as relation_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('v', 'm')
  loop
    execute format(
      'revoke all privileges on table %I.%I from anon',
      item.schema_name,
      item.relation_name
    );
  end loop;
end
$$;

-- Ensure future objects created by the migration owner receive the same grants.
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant usage, select, update on sequences to authenticated;
alter default privileges in schema public
  grant execute on functions to authenticated;

-- Enable RLS and create one permissive authenticated policy on every public
-- base/partitioned table. Views are controlled by their grants and security mode.
do $$
declare
  item record;
begin
  for item in
    select n.nspname as schema_name, c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
  loop
    execute format(
      'alter table %I.%I enable row level security',
      item.schema_name,
      item.table_name
    );
    execute format(
      'create policy authenticated_full_access on %I.%I as permissive for all to authenticated using (true) with check (true)',
      item.schema_name,
      item.table_name
    );
  end loop;
end
$$;

-- Storage API compatibility. Internal Storage catalog tables remain managed by
-- Supabase; browser access is granted only through buckets and objects.
grant usage on schema storage to authenticated;
grant select on storage.buckets to authenticated;
grant select, insert, update, delete on storage.objects to authenticated;

alter table storage.buckets enable row level security;
alter table storage.objects enable row level security;

create policy authenticated_full_access
  on storage.buckets
  as permissive for all to authenticated
  using (true)
  with check (true);

create policy authenticated_full_access
  on storage.objects
  as permissive for all to authenticated
  using (true)
  with check (true);

-- Minimal anonymous bootstrap/public access retained so login and public pages
-- can render before a Supabase Auth session exists.
grant usage on schema public to anon;
grant select on table
  public.branches,
  public.career_job_vacancies,
  public.login_layout,
  public.social_links,
  public.view_offer
to anon;
grant insert on table public.career_cv_applications to anon;

create policy anon_read_branches
  on public.branches for select to anon using (true);
create policy anon_read_career_job_vacancies
  on public.career_job_vacancies for select to anon using (true);
create policy anon_read_login_layout
  on public.login_layout for select to anon using (true);
create policy anon_insert_career_cv_applications
  on public.career_cv_applications for insert to anon with check (true);
create policy anon_read_social_links
  on public.social_links for select to anon using (true);
create policy anon_read_published_offers
  on public.view_offer for select to anon using (status = 'published');

grant execute on function public.get_login_layout() to anon;
grant execute on function public.increment_social_link_click(bigint, text) to anon;
grant execute on function public.increment_page_visit_count(uuid) to anon;
grant execute on function public.increment_view_button_count(uuid) to anon;

grant usage on schema storage to anon;
grant select on storage.buckets, storage.objects to anon;

create policy anon_read_public_buckets
  on storage.buckets for select to anon
  using (public = true);
create policy anon_read_branding_docs
  on storage.objects for select to anon
  using (bucket_id = 'branding-docs');

commit;
