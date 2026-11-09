begin;

alter table public.pos_scan_requests
  add column if not exists pending_receiving_record_id uuid references public.pending_receiving_records(id) on delete cascade,
  add column if not exists bill_storage_path text;

alter table public.pos_scan_requests drop constraint if exists pos_scan_requests_request_target_check;
alter table public.pos_scan_requests add constraint pos_scan_requests_request_target_check check (
  (request_type = 'pos_reconciliation' and box_operation_id is not null and receiving_record_id is null and pending_receiving_record_id is null)
  or (request_type in ('receiving_bank_slip', 'receiving_bill') and receiving_record_id is not null and box_operation_id is null and pending_receiving_record_id is null)
  or (request_type = 'pay_to_credit_slip' and box_operation_id is null and receiving_record_id is null and pending_receiving_record_id is null)
  or (request_type = 'receiving_draft_bill' and box_operation_id is null and not (receiving_record_id is not null and pending_receiving_record_id is not null))
);

create or replace function public.receiving_bill_scan_actor()
returns uuid language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_actor uuid;
begin
  if auth.uid() is null then raise exception 'Signed-in session required' using errcode = '42501'; end if;
  select u.id into v_actor from public.users u where u.status = 'active' and (
    (to_jsonb(u) ->> 'auth_user_id') = auth.uid()::text or u.id = auth.uid()
    or u.id::text = (auth.jwt() -> 'app_metadata' ->> 'aqura_user_id'))
  order by case when (to_jsonb(u) ->> 'auth_user_id') = auth.uid()::text then 0 when u.id = auth.uid() then 1 else 2 end limit 1;
  if v_actor is null then raise exception 'Active user required' using errcode = '42501'; end if;
  return v_actor;
end;
$$;

-- One request can be completed before or after the receiving record is saved.
create or replace function public.complete_start_receiving_bill_scan(
  p_request_id uuid, p_storage_path text, p_document_url text
) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.receiving_bill_scan_actor();
  v_request public.pos_scan_requests%rowtype;
  v_original text;
  v_posted_id uuid;
begin
  select * into v_request from public.pos_scan_requests
  where id = p_request_id and request_type = 'receiving_draft_bill' for update;
  if not found or v_request.requested_by is distinct from v_actor then
    raise exception 'Bill scan request is unavailable' using errcode = '42501';
  end if;
  if v_request.status <> 'pending' then raise exception 'This scan request is no longer pending'; end if;
  if p_storage_path is null or p_document_url is null
    or p_storage_path !~ ('^drafts/' || p_request_id::text || '/[a-f0-9-]+[.](pdf|jpg|jpeg|png|webp)$')
    or p_document_url !~ '^https?://[^/]+/storage/v1/object/public/original-bills/'
    or right(p_document_url, length('/storage/v1/object/public/original-bills/' || p_storage_path))
      <> '/storage/v1/object/public/original-bills/' || p_storage_path then
    raise exception 'Invalid bill document path';
  end if;
  if not exists (select 1 from storage.objects where bucket_id = 'original-bills' and name = p_storage_path
    and metadata ->> 'mimetype' in ('application/pdf', 'image/jpeg', 'image/png', 'image/webp')) then
    raise exception 'Upload the bill document before saving';
  end if;
  if v_request.pending_receiving_record_id is not null then
    select original_bill_url, posted_receiving_record_id into v_original, v_posted_id
    from public.pending_receiving_records where id = v_request.pending_receiving_record_id for update;
    if not found then raise exception 'Receiving record no longer exists'; end if;
    if nullif(v_original, '') is not null then raise exception 'The original bill changed. Upload from Receiving Records instead.'; end if;
    update public.pending_receiving_records set original_bill_url = p_document_url, original_bill_uploaded = true, updated_at = now()
    where id = v_request.pending_receiving_record_id;
  end if;
  if coalesce(v_posted_id, v_request.receiving_record_id) is not null then
    select original_bill_url into v_original from public.receiving_records
    where id = coalesce(v_posted_id, v_request.receiving_record_id) for update;
    if not found then raise exception 'Receiving record no longer exists'; end if;
    if nullif(v_original, '') is not null then raise exception 'The original bill changed. Upload from Receiving Records instead.'; end if;
    update public.receiving_records set original_bill_url = p_document_url, original_bill_check_result = null, updated_at = now()
    where id = coalesce(v_posted_id, v_request.receiving_record_id);
  end if;
  update public.pos_scan_requests set status = 'completed', photo_url = p_document_url, bill_storage_path = p_storage_path,
    completed_by = v_actor, completed_at = now(), updated_at = now() where id = p_request_id;
end;
$$;

-- Lock the same request as completion, so an upload racing a record save is attached exactly once.
create or replace function public.link_start_receiving_bill_scan(p_request_id uuid, p_record_id uuid, p_is_pending boolean)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_actor uuid := public.receiving_bill_scan_actor();
  v_request public.pos_scan_requests%rowtype;
  v_owner uuid;
  v_branch integer;
  v_original text;
begin
  if p_is_pending is null then raise exception 'Receiving record type is required'; end if;
  select * into v_request from public.pos_scan_requests
  where id = p_request_id and request_type = 'receiving_draft_bill' for update;
  if not found or v_request.requested_by is distinct from v_actor then
    raise exception 'Bill scan request is unavailable' using errcode = '42501';
  end if;
  if v_request.status not in ('pending', 'completed') then raise exception 'Bill scan request is unavailable'; end if;
  if (v_request.receiving_record_id is not null and (p_is_pending or v_request.receiving_record_id <> p_record_id))
    or (v_request.pending_receiving_record_id is not null and (not p_is_pending or v_request.pending_receiving_record_id <> p_record_id)) then
    raise exception 'Scan request is already linked to another record';
  end if;
  if p_is_pending then
    select user_id, branch_id, original_bill_url into v_owner, v_branch, v_original
    from public.pending_receiving_records where id = p_record_id for update;
  else
    select user_id, branch_id, original_bill_url into v_owner, v_branch, v_original
    from public.receiving_records where id = p_record_id for update;
  end if;
  if not found or v_owner is distinct from v_actor or v_branch is distinct from v_request.branch_id then
    raise exception 'Receiving record is unavailable' using errcode = '42501';
  end if;
  if v_request.status = 'completed' then
    if nullif(v_request.photo_url, '') is null then raise exception 'Scanned bill is missing'; end if;
    if nullif(v_original, '') is not null and v_original <> v_request.photo_url then raise exception 'The original bill changed'; end if;
    if p_is_pending then
      update public.pending_receiving_records set original_bill_url = v_request.photo_url, original_bill_uploaded = true, updated_at = now() where id = p_record_id;
    else
      update public.receiving_records set original_bill_url = v_request.photo_url, updated_at = now() where id = p_record_id;
    end if;
  end if;
  update public.pos_scan_requests set
    receiving_record_id = case when not p_is_pending then p_record_id else null end,
    pending_receiving_record_id = case when p_is_pending then p_record_id else null end,
    updated_at = now() where id = p_request_id;
end;
$$;

revoke all on function public.receiving_bill_scan_actor() from public;
revoke all on function public.complete_start_receiving_bill_scan(uuid, text, text) from public;
revoke all on function public.link_start_receiving_bill_scan(uuid, uuid, boolean) from public;
grant execute on function public.receiving_bill_scan_actor() to authenticated;
grant execute on function public.complete_start_receiving_bill_scan(uuid, text, text) to authenticated;
grant execute on function public.link_start_receiving_bill_scan(uuid, uuid, boolean) to authenticated;

notify pgrst, 'reload schema';
commit;
