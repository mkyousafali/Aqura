begin;

alter table public.pos_scan_requests
  drop constraint if exists pos_scan_requests_request_target_check;

alter table public.pos_scan_requests
  add constraint pos_scan_requests_request_target_check check (
    (request_type = 'pos_reconciliation' and box_operation_id is not null and receiving_record_id is null)
    or (request_type = 'receiving_bank_slip' and receiving_record_id is not null and box_operation_id is null)
    or (request_type = 'pay_to_credit_slip' and box_operation_id is null and receiving_record_id is null)
  );

create unique index if not exists pos_scan_requests_one_pending_pay_to_credit
  on public.pos_scan_requests(requested_by)
  where request_type = 'pay_to_credit_slip' and status = 'pending';

commit;
