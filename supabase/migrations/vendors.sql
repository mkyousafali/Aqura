create table public.vendors (
  erp_vendor_id integer not null,
  vendor_name text not null,
  salesman_name text null,
  salesman_contact text null,
  supervisor_name text null,
  supervisor_contact text null,
  vendor_contact_number text null,
  payment_method text null,
  credit_period integer null,
  bank_name text null,
  iban text null,
  status text null default 'Active'::text,
  last_visit timestamp without time zone null,
  categories text[] null,
  delivery_modes text[] null,
  place text null,
  location_link text null,
  return_expired_products text null,
  return_expired_products_note text null,
  return_near_expiry_products text null,
  return_near_expiry_products_note text null,
  return_over_stock text null,
  return_over_stock_note text null,
  return_damage_products text null,
  return_damage_products_note text null,
  no_return boolean null default false,
  no_return_note text null,
  vat_applicable text null default 'VAT Applicable'::text,
  vat_number text null,
  no_vat_note text null,
  created_at timestamp without time zone null default now(),
  updated_at timestamp without time zone null default now(),
  branch_id bigint not null,
  payment_priority text null default 'Normal'::text,
  constraint vendors_pkey primary key (erp_vendor_id, branch_id),
  constraint vendors_erp_vendor_branch_unique unique (erp_vendor_id, branch_id),
  constraint vendors_branch_id_fkey foreign KEY (branch_id) references branches (id) on delete set null,
  constraint vendors_payment_priority_check check (
    (
      payment_priority = any (
        array[
          'Most'::text,
          'Medium'::text,
          'Normal'::text,
          'Low'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_vendors_branch_id on public.vendors using btree (branch_id) TABLESPACE pg_default
where
  (branch_id is not null);

create index IF not exists idx_vendors_branch_status on public.vendors using btree (branch_id, status) TABLESPACE pg_default
where
  (branch_id is not null);

create index IF not exists idx_vendors_erp_vendor_id on public.vendors using btree (erp_vendor_id) TABLESPACE pg_default;

create index IF not exists idx_vendors_payment_priority on public.vendors using btree (payment_priority) TABLESPACE pg_default;

create index IF not exists idx_vendors_status on public.vendors using btree (status) TABLESPACE pg_default;

create index IF not exists idx_vendors_vendor_name on public.vendors using btree (vendor_name) TABLESPACE pg_default;

create index IF not exists idx_vendors_payment_method on public.vendors using gin (to_tsvector('english'::regconfig, payment_method)) TABLESPACE pg_default;

create index IF not exists idx_vendors_vat_applicable on public.vendors using btree (vat_applicable) TABLESPACE pg_default;

create index IF not exists idx_vendors_created_at on public.vendors using btree (created_at) TABLESPACE pg_default;