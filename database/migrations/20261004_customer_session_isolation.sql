begin;

do $role$
begin
  if not exists (select 1 from pg_roles where rolname = 'customer_authenticated') then
    create role customer_authenticated nologin noinherit;
  end if;
end
$role$;

grant customer_authenticated to authenticator;
grant usage on schema public to customer_authenticated;

create or replace function public.aqura_current_customer_id()
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $function$
  select case
    when coalesce(auth.jwt() -> 'app_metadata' ->> 'aqura_customer_id', '')
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then (auth.jwt() -> 'app_metadata' ->> 'aqura_customer_id')::uuid
    else null
  end
$function$;

revoke all on function public.aqura_current_customer_id() from public, anon;
grant execute on function public.aqura_current_customer_id() to customer_authenticated, authenticated, service_role;

create or replace function public.enforce_customer_api_allowlist()
returns void
language plpgsql
security invoker
set search_path to 'public'
as $function$
declare
  v_path text := coalesce(current_setting('request.path', true), '');
  v_resource text := split_part(trim(both '/' from v_path), '/', 1);
  v_rpc text := case when v_resource = 'rpc' then split_part(trim(both '/' from v_path), '/', 2) else null end;
  v_allowed_tables constant text[] := array[
    'customers', 'orders', 'order_items', 'order_audit_logs',
    'products', 'product_categories', 'branches', 'delivery_service_settings',
    'social_links', 'loyalty_tiers', 'view_offer'
  ];
  v_allowed_rpcs constant text[] := array[
    'create_customer_order', 'delete_customer_account',
    'get_customer_pending_loyalty_otp', 'get_active_customer_media',
    'get_all_branches_delivery_settings', 'get_login_layout',
    'increment_social_link_click', 'increment_page_visit_count',
    'increment_view_button_count', 'surprise_box_check_status',
    'surprise_box_validate_bill', 'surprise_box_play',
    'gift_wheel_check_status'
  ];
begin
  if current_user <> 'customer_authenticated' then
    return;
  end if;

  if v_resource = any(v_allowed_tables) then
    return;
  end if;

  if v_resource = 'rpc' and v_rpc = any(v_allowed_rpcs) then
    return;
  end if;

  raise insufficient_privilege using message = 'Customer session is not permitted to access this API resource';
end
$function$;

revoke all on function public.enforce_customer_api_allowlist() from public;
grant execute on function public.enforce_customer_api_allowlist() to authenticator, anon, authenticated, customer_authenticated, service_role;

alter role authenticator set pgrst.db_pre_request = 'public.enforce_customer_api_allowlist';

grant select on public.customers to customer_authenticated;
grant update (
  location1_name, location1_url, location1_lat, location1_lng,
  location2_name, location2_url, location2_lat, location2_lng,
  location3_name, location3_url, location3_lat, location3_lng
) on public.customers to customer_authenticated;
grant select on public.orders to customer_authenticated;
grant insert on public.orders to customer_authenticated;
grant select, insert on public.order_items to customer_authenticated;
grant select, insert, delete on public.order_audit_logs to customer_authenticated;
grant select on public.products, public.product_categories, public.branches,
  public.delivery_service_settings, public.social_links, public.loyalty_tiers to customer_authenticated;
grant select on public.view_offer to customer_authenticated;

alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_audit_logs enable row level security;
alter table public.products enable row level security;
alter table public.product_categories enable row level security;
alter table public.branches enable row level security;
alter table public.delivery_service_settings enable row level security;
alter table public.social_links enable row level security;
alter table public.loyalty_tiers enable row level security;

drop policy if exists customer_own_profile_select on public.customers;
create policy customer_own_profile_select on public.customers for select to customer_authenticated
  using (id = public.aqura_current_customer_id() and coalesce(is_deleted, false) = false);
drop policy if exists customer_own_profile_update on public.customers;
create policy customer_own_profile_update on public.customers for update to customer_authenticated
  using (id = public.aqura_current_customer_id() and coalesce(is_deleted, false) = false)
  with check (id = public.aqura_current_customer_id() and coalesce(is_deleted, false) = false);

drop policy if exists customer_own_orders_select on public.orders;
create policy customer_own_orders_select on public.orders for select to customer_authenticated
  using (customer_id = public.aqura_current_customer_id());
drop policy if exists customer_own_orders_insert on public.orders;
create policy customer_own_orders_insert on public.orders for insert to customer_authenticated
  with check (customer_id = public.aqura_current_customer_id());

drop policy if exists customer_own_order_items_select on public.order_items;
create policy customer_own_order_items_select on public.order_items for select to customer_authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.customer_id = public.aqura_current_customer_id()));
drop policy if exists customer_own_order_items_insert on public.order_items;
create policy customer_own_order_items_insert on public.order_items for insert to customer_authenticated
  with check (exists (select 1 from public.orders o where o.id = order_id and o.customer_id = public.aqura_current_customer_id()));

drop policy if exists customer_own_order_logs_select on public.order_audit_logs;
create policy customer_own_order_logs_select on public.order_audit_logs for select to customer_authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.customer_id = public.aqura_current_customer_id()));
drop policy if exists customer_own_order_logs_insert on public.order_audit_logs;
create policy customer_own_order_logs_insert on public.order_audit_logs for insert to customer_authenticated
  with check (exists (select 1 from public.orders o where o.id = order_id and o.customer_id = public.aqura_current_customer_id()));
drop policy if exists customer_own_order_logs_delete on public.order_audit_logs;
create policy customer_own_order_logs_delete on public.order_audit_logs for delete to customer_authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.customer_id = public.aqura_current_customer_id()));

drop policy if exists customer_catalog_products_select on public.products;
create policy customer_catalog_products_select on public.products for select to customer_authenticated
  using (coalesce(is_active, false) and coalesce(is_customer_product, false));
drop policy if exists customer_catalog_categories_select on public.product_categories;
create policy customer_catalog_categories_select on public.product_categories for select to customer_authenticated
  using (coalesce(is_active, false));
drop policy if exists customer_active_branches_select on public.branches;
create policy customer_active_branches_select on public.branches for select to customer_authenticated
  using (coalesce(is_active, false));
drop policy if exists customer_delivery_settings_select on public.delivery_service_settings;
create policy customer_delivery_settings_select on public.delivery_service_settings for select to customer_authenticated
  using (coalesce(is_active, false));
drop policy if exists customer_social_links_select on public.social_links;
create policy customer_social_links_select on public.social_links for select to customer_authenticated using (true);
drop policy if exists customer_loyalty_tiers_select on public.loyalty_tiers;
create policy customer_loyalty_tiers_select on public.loyalty_tiers for select to customer_authenticated
  using (coalesce(is_active, false));

create or replace function public.enforce_customer_owned_write()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_customer_id uuid := public.aqura_current_customer_id();
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'customer_authenticated' then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if v_customer_id is null then
    raise insufficient_privilege using message = 'Customer identity is missing from the authenticated session';
  end if;

  if tg_table_name = 'customers' then
    if (tg_op = 'DELETE' and old.id <> v_customer_id)
       or (tg_op <> 'DELETE' and new.id <> v_customer_id) then
      raise insufficient_privilege using message = 'Customers may modify only their own profile';
    end if;
  elsif tg_table_name = 'orders' then
    if (tg_op = 'DELETE' and old.customer_id <> v_customer_id)
       or (tg_op <> 'DELETE' and new.customer_id <> v_customer_id) then
      raise insufficient_privilege using message = 'Customers may create or modify only their own orders';
    end if;
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end
$function$;

revoke all on function public.enforce_customer_owned_write() from public, anon, authenticated, customer_authenticated;

drop trigger if exists enforce_customer_owned_write on public.customers;
create trigger enforce_customer_owned_write
before insert or update or delete on public.customers
for each row execute function public.enforce_customer_owned_write();

drop trigger if exists enforce_customer_owned_write on public.orders;
create trigger enforce_customer_owned_write
before insert or update or delete on public.orders
for each row execute function public.enforce_customer_owned_write();

create or replace function public.get_customer_pending_loyalty_otp(p_phone text)
returns table(redemption_id uuid, otp_code text, created_at timestamp with time zone)
language sql
security definer
set search_path to 'public'
as $function$
  select lr.id, lr.otp_code, lr.created_at
  from public.loyalty_redemptions lr
  where lr.whatsapp_number = p_phone
    and lr.status <> 'confirmed'
    and lr.otp_code is not null
    and lr.otp_confirmed_at is null
    and lr.created_at > (now() - interval '15 minutes')
    and (
      coalesce(auth.jwt() ->> 'role', '') <> 'customer_authenticated'
      or exists (
        select 1 from public.customers c
        where c.id = public.aqura_current_customer_id()
          and c.whatsapp_number = p_phone
          and coalesce(c.is_deleted, false) = false
      )
    )
  order by lr.created_at desc
  limit 1
$function$;

do $grants$
declare
  v_function record;
begin
  for v_function in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(array[
        'create_customer_order', 'delete_customer_account',
        'get_customer_pending_loyalty_otp', 'get_active_customer_media',
        'get_all_branches_delivery_settings', 'get_login_layout',
        'increment_social_link_click', 'increment_page_visit_count',
        'increment_view_button_count', 'surprise_box_check_status',
        'surprise_box_validate_bill', 'surprise_box_play',
        'gift_wheel_check_status'
      ])
  loop
    execute format('grant execute on function %s to customer_authenticated', v_function.signature);
  end loop;
end
$grants$;

update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object(
       'role', 'customer_authenticated',
       'aqura_subject', 'customer',
       'aqura_customer_id', raw_user_meta_data ->> 'aqura_customer_id'
     )
where raw_user_meta_data ->> 'aqura_subject' = 'customer'
  and coalesce(raw_user_meta_data ->> 'aqura_customer_id', '') <> '';

notify pgrst, 'reload config';
notify pgrst, 'reload schema';

commit;
