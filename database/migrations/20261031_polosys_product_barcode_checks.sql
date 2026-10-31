begin;

create table if not exists public."Polosys_product_barcode_checks" (
  product_id uuid not null references public."Polosys_products"(id) on delete cascade,
  branch_id bigint not null references public.branches(id) on delete cascade,
  barcode text not null check (barcode = btrim(barcode) and length(barcode) between 1 and 100),
  checked_by uuid not null references public.users(id),
  checked_at timestamptz not null default now(),
  primary key (product_id, branch_id, barcode)
);

comment on table public."Polosys_product_barcode_checks" is
  'Checker confirmation per saved product barcode and branch; shared between users.';

alter table public."Polosys_product_barcode_checks" enable row level security;
revoke all on public."Polosys_product_barcode_checks" from public, anon, authenticated;
grant select, insert on public."Polosys_product_barcode_checks" to service_role;

notify pgrst, 'reload schema';
commit;
