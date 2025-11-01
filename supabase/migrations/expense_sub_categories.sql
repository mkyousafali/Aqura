create table public.expense_sub_categories (
  id bigserial not null,
  parent_category_id bigint not null,
  name_en text not null,
  name_ar text not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  is_active boolean null default true,
  constraint expense_sub_categories_pkey primary key (id),
  constraint expense_sub_categories_parent_category_id_fkey foreign KEY (parent_category_id) references expense_parent_categories (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_expense_sub_categories_parent on public.expense_sub_categories using btree (parent_category_id) TABLESPACE pg_default;

create index IF not exists idx_expense_sub_categories_is_active on public.expense_sub_categories using btree (is_active) TABLESPACE pg_default;