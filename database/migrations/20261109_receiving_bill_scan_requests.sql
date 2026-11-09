begin;

alter table public.pos_scan_requests
  drop constraint if exists pos_scan_requests_request_target_check;
alter table public.pos_scan_requests
  add constraint pos_scan_requests_request_target_check check (
    (request_type = 'pos_reconciliation' and box_operation_id is not null and receiving_record_id is null)
    or (request_type in ('receiving_bank_slip', 'receiving_bill') and receiving_record_id is not null and box_operation_id is null)
    or (request_type = 'pay_to_credit_slip' and box_operation_id is null and receiving_record_id is null)
  );

create unique index if not exists pos_scan_requests_one_pending_receiving_bill
  on public.pos_scan_requests(receiving_record_id)
  where request_type = 'receiving_bill' and status = 'pending';

-- Link the PDF and complete its request together. A stale mobile page must never
-- replace an upload made after that page opened, or complete a cancelled request.
create or replace function public.complete_receiving_bill_scan(
  p_request_id uuid, p_storage_path text, p_pdf_url text,
  p_expected_original_bill_url text
) returns void language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  v_actor uuid;
  v_request public.pos_scan_requests%rowtype;
  v_original_url text;
begin
  if auth.uid() is null then
    raise exception 'Signed-in session required' using errcode = '42501';
  end if;
  select u.id into v_actor from public.users u
  where (to_jsonb(u) ->> 'auth_user_id') = auth.uid()::text or u.id = auth.uid()
    or u.id::text = (auth.jwt() -> 'app_metadata' ->> 'aqura_user_id')
  order by case when (to_jsonb(u) ->> 'auth_user_id') = auth.uid()::text then 0 when u.id = auth.uid() then 1 else 2 end
  limit 1;

  select * into v_request from public.pos_scan_requests
  where id = p_request_id and request_type = 'receiving_bill' for update;
  if not found or v_actor is null or v_request.requested_by is distinct from v_actor then
    raise exception 'Bill scan request is unavailable' using errcode = '42501';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'This scan request is no longer pending';
  end if;
  if p_storage_path is null or p_pdf_url is null
    or p_storage_path !~ ('^' || v_request.receiving_record_id::text || '/' || p_request_id::text || '/[a-f0-9-]+[.]pdf$')
    or p_pdf_url !~ '^https?://[^/]+/storage/v1/object/public/original-bills/'
    or right(p_pdf_url, length('/storage/v1/object/public/original-bills/' || p_storage_path))
      <> '/storage/v1/object/public/original-bills/' || p_storage_path then
    raise exception 'Invalid bill PDF path';
  end if;
  if not exists (select 1 from storage.objects where bucket_id = 'original-bills'
    and name = p_storage_path and metadata ->> 'mimetype' = 'application/pdf') then
    raise exception 'Upload the bill PDF before saving';
  end if;

  select original_bill_url into v_original_url from public.receiving_records
  where id = v_request.receiving_record_id for update;
  if not found then raise exception 'Receiving record no longer exists'; end if;
  if v_original_url is distinct from p_expected_original_bill_url then
    raise exception 'The original bill changed. Reopen the request before saving.';
  end if;
  update public.receiving_records set original_bill_url = p_pdf_url,
    original_bill_check_result = null, updated_at = now()
  where id = v_request.receiving_record_id;
  update public.pos_scan_requests set status = 'completed', photo_url = p_pdf_url,
    completed_by = v_actor, completed_at = now(), updated_at = now()
  where id = p_request_id;
end;
$$;
revoke all on function public.complete_receiving_bill_scan(uuid, text, text, text) from public;
grant execute on function public.complete_receiving_bill_scan(uuid, text, text, text) to authenticated;

notify pgrst, 'reload schema';
commit;
