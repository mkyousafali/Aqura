begin;

alter table public.pos_scan_requests
  alter column box_operation_id drop not null,
  add column if not exists request_type text not null default 'pos_reconciliation',
  add column if not exists receiving_record_id uuid references public.receiving_records(id) on delete cascade,
  add column if not exists request_label text;

alter table public.pos_scan_requests
  drop constraint if exists pos_scan_requests_request_target_check;

alter table public.pos_scan_requests
  add constraint pos_scan_requests_request_target_check check (
    (request_type = 'pos_reconciliation' and box_operation_id is not null and receiving_record_id is null)
    or
    (request_type = 'receiving_bank_slip' and receiving_record_id is not null and box_operation_id is null)
  );

create unique index if not exists pos_scan_requests_one_pending_receiving_slip
  on public.pos_scan_requests(receiving_record_id)
  where request_type = 'receiving_bank_slip' and status = 'pending';

create index if not exists pos_scan_requests_receiving_record_idx
  on public.pos_scan_requests(receiving_record_id)
  where receiving_record_id is not null;

commit;
