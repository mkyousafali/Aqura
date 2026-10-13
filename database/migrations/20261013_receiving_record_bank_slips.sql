begin;

create table if not exists public.receiving_record_bank_slips (
  id uuid primary key default gen_random_uuid(),
  receiving_record_id uuid not null unique references public.receiving_records(id) on delete cascade,
  storage_path text not null unique,
  original_file_name text not null,
  file_mime_type text,
  file_size bigint,
  uploaded_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create index if not exists receiving_record_bank_slips_record_idx
  on public.receiving_record_bank_slips(receiving_record_id, created_at desc);

alter table public.receiving_record_bank_slips enable row level security;

drop policy if exists receiving_record_bank_slips_select on public.receiving_record_bank_slips;
create policy receiving_record_bank_slips_select on public.receiving_record_bank_slips
  for select to authenticated using (
    exists (select 1 from public.users u where u.id = public.aqura_current_user_id()
      and u.status = 'active' and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp where bp.user_id = u.id
          and bp.button_code = 'RECEIVING_RECORDS' and bp.is_enabled = true)))
  );

drop policy if exists receiving_record_bank_slips_insert on public.receiving_record_bank_slips;
create policy receiving_record_bank_slips_insert on public.receiving_record_bank_slips
  for insert to authenticated with check (
    uploaded_by = public.aqura_current_user_id()
    and exists (select 1 from public.users u where u.id = public.aqura_current_user_id()
      and u.status = 'active' and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp where bp.user_id = u.id
          and bp.button_code = 'RECEIVING_RECORDS' and bp.is_enabled = true)))
  );

grant select, insert on public.receiving_record_bank_slips to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receiving-bank-slips', 'receiving-bank-slips', false, 10485760,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists receiving_bank_slips_select on storage.objects;
create policy receiving_bank_slips_select on storage.objects
  for select to authenticated using (
    bucket_id = 'receiving-bank-slips'
    and exists (select 1 from public.users u where u.id = public.aqura_current_user_id()
      and u.status = 'active' and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp where bp.user_id = u.id
          and bp.button_code = 'RECEIVING_RECORDS' and bp.is_enabled = true)))
  );

drop policy if exists receiving_bank_slips_insert on storage.objects;
create policy receiving_bank_slips_insert on storage.objects
  for insert to authenticated with check (
    bucket_id = 'receiving-bank-slips'
    and exists (select 1 from public.users u where u.id = public.aqura_current_user_id()
      and u.status = 'active' and (coalesce(u.is_master_admin, false) or exists (
        select 1 from public.button_permissions bp where bp.user_id = u.id
          and bp.button_code = 'RECEIVING_RECORDS' and bp.is_enabled = true)))
  );

commit;
