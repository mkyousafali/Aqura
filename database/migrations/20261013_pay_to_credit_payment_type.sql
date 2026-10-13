begin;

alter table public.pos_scan_requests
  add column if not exists payment_account_type text;

alter table public.pos_scan_requests
  drop constraint if exists pos_scan_requests_payment_account_type_check;

alter table public.pos_scan_requests
  add constraint pos_scan_requests_payment_account_type_check
  check (payment_account_type is null or payment_account_type in ('bank', 'cash'));

commit;
