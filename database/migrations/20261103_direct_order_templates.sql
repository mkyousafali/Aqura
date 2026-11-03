begin;

create table public.direct_order_templates (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique not null,
  shop_name text check (shop_name is null or length(btrim(shop_name)) between 1 and 200),
  shop_location text check (shop_location is null or length(btrim(shop_location)) between 1 and 500),
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now()
);

comment on table public.direct_order_templates is
  'Direct order shop templates. Names and locations are required by the creation API; null values identify migrated legacy orders.';

alter table public.direct_order_templates enable row level security;
revoke all on public.direct_order_templates from public, anon, authenticated;
grant select, insert on public.direct_order_templates to service_role;
grant usage, select on sequence public.direct_order_templates_order_number_seq to service_role;

alter table public.direct_orders
  add column template_id uuid references public.direct_order_templates(id);

-- Preserve every existing order and photo as a product inside its own template.
-- Unknown historical shop names/locations remain null rather than being invented.
insert into public.direct_order_templates (id, order_number, created_by, created_at)
overriding system value
select id, order_number, created_by, created_at from public.direct_orders;

update public.direct_orders set template_id = id where template_id is null;

select setval('public.direct_order_templates_order_number_seq',
  coalesce((select max(order_number) from public.direct_order_templates), 1),
  exists(select 1 from public.direct_order_templates));

alter table public.direct_orders alter column template_id set not null;
create index direct_orders_template_order_idx on public.direct_orders(template_id, order_number desc);

-- Keep the previously deployed single-item API compatible until the frontend
-- is deployed. New code always supplies the chosen template explicitly.
create function public.direct_orders_assign_legacy_template() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.template_id is null then
    insert into public.direct_order_templates (created_by, created_at)
    values (new.created_by, new.created_at)
    returning id into new.template_id;
  end if;
  return new;
end;
$$;
revoke all on function public.direct_orders_assign_legacy_template() from public, anon, authenticated;
grant execute on function public.direct_orders_assign_legacy_template() to service_role;

create trigger direct_orders_assign_legacy_template
before insert on public.direct_orders
for each row execute function public.direct_orders_assign_legacy_template();

comment on table public.direct_orders is
  'Products belonging to direct order shop templates; photo and positive quantity required, branch and product identifiers optional.';

notify pgrst, 'reload schema';
commit;
