create table public.expense_parent_categories (
  id bigserial not null,
  name_en text not null,
  name_ar text not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  is_active boolean null default true,
  constraint expense_parent_categories_pkey primary key (id)
) TABLESPACE pg_default;

create index IF not exists idx_expense_parent_categories_is_active on public.expense_parent_categories using btree (is_active) TABLESPACE pg_default;
