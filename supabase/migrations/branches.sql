create table public.branches (
  id bigserial not null,
  name_en character varying(255) not null,
  name_ar character varying(255) not null,
  location_en character varying(500) not null,
  location_ar character varying(500) not null,
  is_active boolean null default true,
  is_main_branch boolean null default false,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  created_by bigint null,
  updated_by bigint null,
  vat_number character varying(50) null,
  constraint branches_pkey primary key (id),
  constraint check_vat_number_not_empty check (
    (
      (vat_number is null)
      or (
        length(
          TRIM(
            both
            from
              vat_number
          )
        ) > 0
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_branches_name_en on public.branches using btree (name_en) TABLESPACE pg_default;

create index IF not exists idx_branches_name_ar on public.branches using btree (name_ar) TABLESPACE pg_default;

create index IF not exists idx_branches_active on public.branches using btree (is_active) TABLESPACE pg_default;

create index IF not exists idx_branches_main on public.branches using btree (is_main_branch) TABLESPACE pg_default;

create index IF not exists idx_branches_vat_number on public.branches using btree (vat_number) TABLESPACE pg_default
where
  (vat_number is not null);

create trigger trigger_update_branches_updated_at BEFORE
update on branches for EACH row
execute FUNCTION update_branches_updated_at ();