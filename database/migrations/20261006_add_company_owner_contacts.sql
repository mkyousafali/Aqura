begin;

alter table public.company_master
  add column if not exists owner_email text,
  add column if not exists owner_whatsapp text;

drop function if exists public.create_company(text, text);
drop function if exists public.update_company(bigint, text, text);

create function public.create_company(
  p_name_ar text,
  p_name_en text,
  p_owner_email text,
  p_owner_whatsapp text
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
begin
  if auth.uid() is null or not exists (
    select 1 from public.users where id = public.aqura_current_user_id()
  ) then raise exception 'Authentication required'; end if;

  if nullif(trim(p_name_ar), '') is null or nullif(trim(p_name_en), '') is null then
    raise exception 'Arabic and English names are required';
  end if;

  insert into public.company_master (name_ar, name_en, owner_email, owner_whatsapp)
  values (trim(p_name_ar), trim(p_name_en), nullif(trim(p_owner_email), ''), nullif(trim(p_owner_whatsapp), ''))
  returning id into v_id;
  return v_id;
end;
$$;

create function public.update_company(
  p_company_id bigint,
  p_name_ar text,
  p_name_en text,
  p_owner_email text,
  p_owner_whatsapp text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.users where id = public.aqura_current_user_id()
  ) then raise exception 'Authentication required'; end if;

  if nullif(trim(p_name_ar), '') is null or nullif(trim(p_name_en), '') is null then
    raise exception 'Arabic and English names are required';
  end if;

  update public.company_master
  set name_ar = trim(p_name_ar), name_en = trim(p_name_en),
      owner_email = nullif(trim(p_owner_email), ''),
      owner_whatsapp = nullif(trim(p_owner_whatsapp), ''), updated_at = now()
  where id = p_company_id;
  if not found then raise exception 'Company not found'; end if;
end;
$$;

revoke all on function public.create_company(text, text, text, text) from public, anon;
grant execute on function public.create_company(text, text, text, text) to authenticated, service_role;
revoke all on function public.update_company(bigint, text, text, text, text) from public, anon;
grant execute on function public.update_company(bigint, text, text, text, text) to authenticated, service_role;

commit;
