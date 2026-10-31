begin;

-- Product preparation is available to every active Aqura user.
-- Keep the existing master-admin policy and ERP automation permissions.
create or replace function public."Polosys_can_edit_products"() returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.users
    where id = public.aqura_current_user_id() and status = 'active'
  );
$$;
revoke all on function public."Polosys_can_edit_products"() from public, anon;
grant execute on function public."Polosys_can_edit_products"() to authenticated, service_role;

do $$
declare table_name text;
begin
  foreach table_name in array array['Polosys_products', 'Polosys_units', 'Polosys_product_groups'] loop
    execute format('drop policy if exists "Polosys_active_user_read" on public.%I', table_name);
    execute format('drop policy if exists "Polosys_active_user_insert" on public.%I', table_name);
    execute format('drop policy if exists "Polosys_active_user_update" on public.%I', table_name);
    execute format('create policy "Polosys_active_user_read" on public.%I for select to authenticated using ((select public."Polosys_can_edit_products"()))', table_name);
    execute format('create policy "Polosys_active_user_insert" on public.%I for insert to authenticated with check ((select public."Polosys_can_edit_products"()))', table_name);
    execute format('create policy "Polosys_active_user_update" on public.%I for update to authenticated using ((select public."Polosys_can_edit_products"())) with check ((select public."Polosys_can_edit_products"()))', table_name);
  end loop;
end;
$$;

notify pgrst, 'reload schema';
commit;
