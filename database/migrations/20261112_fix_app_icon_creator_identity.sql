begin;

-- app_icons.created_by references auth.users, not public.users. Keep the
-- Supabase Auth ID here; aqura_current_user_id() belongs on public.users FKs.
create or replace function public.upsert_app_icon(
  p_icon_key text,
  p_name text,
  p_category text,
  p_storage_path text,
  p_mime_type text default null,
  p_file_size bigint default 0,
  p_description text default null
) returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_id uuid;
begin
  insert into public.app_icons (
    icon_key, name, category, storage_path, mime_type, file_size, description, created_by
  ) values (
    p_icon_key, p_name, p_category, p_storage_path, p_mime_type, p_file_size, p_description, auth.uid()
  )
  on conflict (icon_key) do update set
    name = excluded.name,
    category = excluded.category,
    storage_path = excluded.storage_path,
    mime_type = excluded.mime_type,
    file_size = excluded.file_size,
    description = excluded.description,
    updated_at = now()
  returning id into v_id;

  return v_id;
end;
$function$;

commit;
