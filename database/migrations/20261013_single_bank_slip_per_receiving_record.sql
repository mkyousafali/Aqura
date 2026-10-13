begin;

alter table public.receiving_record_bank_slips
  add constraint receiving_record_bank_slips_one_per_record unique (receiving_record_id);

drop policy if exists receiving_record_bank_slips_update on public.receiving_record_bank_slips;
create policy receiving_record_bank_slips_update on public.receiving_record_bank_slips
  for update to authenticated using (
    exists (select 1 from public.users u where u.id = public.aqura_current_user_id()
      and u.status = 'active' and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp where bp.user_id = u.id
          and bp.button_code = 'RECEIVING_RECORDS' and bp.is_enabled = true)))
  ) with check (
    uploaded_by = public.aqura_current_user_id()
  );

grant update on public.receiving_record_bank_slips to authenticated;

drop policy if exists receiving_bank_slips_delete on storage.objects;
create policy receiving_bank_slips_delete on storage.objects
  for delete to authenticated using (
    bucket_id = 'receiving-bank-slips'
    and exists (select 1 from public.users u where u.id = public.aqura_current_user_id()
      and u.status = 'active' and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp where bp.user_id = u.id
          and bp.button_code = 'RECEIVING_RECORDS' and bp.is_enabled = true)))
  );

commit;
