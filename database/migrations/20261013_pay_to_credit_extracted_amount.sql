begin;

alter table public.pos_scan_requests
  add column if not exists extracted_amount numeric(18, 2);

commit;
