create table public.view_offer (
  id uuid not null default gen_random_uuid (),
  offer_name character varying(255) not null,
  branch_id bigint not null,
  start_date date not null,
  end_date date not null,
  file_url text not null,
  created_at timestamp with time zone null default CURRENT_TIMESTAMP,
  updated_at timestamp with time zone null default CURRENT_TIMESTAMP,
  start_time time without time zone null default '00:00:00'::time without time zone,
  end_time time without time zone null default '23:59:00'::time without time zone,
  thumbnail_url text null,
  constraint view_offer_pkey primary key (id),
  constraint view_offer_branch_id_fkey foreign KEY (branch_id) references branches (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_view_offer_branch_id on public.view_offer using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_view_offer_dates on public.view_offer using btree (start_date, end_date) TABLESPACE pg_default;

create index IF not exists idx_view_offer_datetime on public.view_offer using btree (start_date, start_time, end_date, end_time) TABLESPACE pg_default;