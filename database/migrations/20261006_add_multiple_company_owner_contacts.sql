begin;

alter table public.company_master
  add column if not exists owner_emails text[] not null default '{}',
  add column if not exists owner_whatsapp_numbers text[] not null default '{}';

update public.company_master
set owner_emails = case
      when nullif(trim(owner_email), '') is not null then array[trim(owner_email)]
      else '{}'
    end,
    owner_whatsapp_numbers = case
      when nullif(trim(owner_whatsapp), '') is not null then array[trim(owner_whatsapp)]
      else '{}'
    end
where cardinality(owner_emails) = 0
   or cardinality(owner_whatsapp_numbers) = 0;

drop function if exists public.create_company(text, text, text, text);
drop function if exists public.update_company(bigint, text, text, text, text);

create function public.create_company(
  p_name_ar text,
  p_name_en text,
  p_owner_emails text[],
  p_owner_whatsapp_numbers text[]
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare v_id bigint;
begin
  if auth.uid() is null or not exists (
    select 1 from public.users where id = public.aqura_current_user_id()
  ) then raise exception 'Authentication required'; end if;
  if nullif(trim(p_name_ar), '') is null or nullif(trim(p_name_en), '') is null then
    raise exception 'Arabic and English names are required';
  end if;
  insert into public.company_master (name_ar, name_en, owner_emails, owner_whatsapp_numbers)
  values (trim(p_name_ar), trim(p_name_en), coalesce(p_owner_emails, '{}'), coalesce(p_owner_whatsapp_numbers, '{}'))
  returning id into v_id;
  return v_id;
end;
$$;

create function public.update_company(
  p_company_id bigint,
  p_name_ar text,
  p_name_en text,
  p_owner_emails text[],
  p_owner_whatsapp_numbers text[]
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
      owner_emails = coalesce(p_owner_emails, '{}'),
      owner_whatsapp_numbers = coalesce(p_owner_whatsapp_numbers, '{}'),
      updated_at = now()
  where id = p_company_id;
  if not found then raise exception 'Company not found'; end if;
end;
$$;

revoke all on function public.create_company(text, text, text[], text[]) from public, anon;
grant execute on function public.create_company(text, text, text[], text[]) to authenticated, service_role;
revoke all on function public.update_company(bigint, text, text, text[], text[]) from public, anon;
grant execute on function public.update_company(bigint, text, text, text[], text[]) to authenticated, service_role;

commit;
