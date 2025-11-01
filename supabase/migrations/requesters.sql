create table public.requesters (
  id uuid not null default gen_random_uuid (),
  requester_id character varying(50) not null,
  requester_name character varying(255) not null,
  contact_number character varying(20) null,
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  created_by uuid null,
  updated_by uuid null,
  constraint requesters_pkey primary key (id),
  constraint requesters_requester_id_key unique (requester_id)
) TABLESPACE pg_default;

create index IF not exists idx_requesters_requester_id on public.requesters using btree (requester_id) TABLESPACE pg_default;

create index IF not exists idx_requesters_name on public.requesters using btree (requester_name) TABLESPACE pg_default;

create trigger update_requesters_updated_at BEFORE
update on requesters for EACH row
execute FUNCTION update_updated_at_column ();
