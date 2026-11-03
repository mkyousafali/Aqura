begin;

create table public.direct_orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique not null,
  photo_path text not null unique check (length(btrim(photo_path)) > 0),
  quantity numeric not null check (quantity > 0 and quantity < 'Infinity'::numeric),
  branch_id bigint references public.branches(id) on delete set null,
  branch_name_en text,
  branch_name_ar text,
  product_code text,
  barcode text,
  product_name_en text,
  created_by uuid not null references public.users(id),
  created_at timestamptz not null default now()
);

comment on table public.direct_orders is
  'Direct orders: photo and positive quantity required; branch and product identifiers optional, including unmatched products.';

alter table public.direct_orders enable row level security;
revoke all on public.direct_orders from public, anon, authenticated;
grant select, insert on public.direct_orders to service_role;
grant usage, select on sequence public.direct_orders_order_number_seq to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('direct-order-photos', 'direct-order-photos', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

notify pgrst, 'reload schema';
commit;
