begin;

update public.company_master
set owner_emails = case
      when array_position(owner_emails, 'hmamts30@hotmail.com') is null
        then owner_emails || 'hmamts30@hotmail.com'::text
      else owner_emails
    end,
    owner_whatsapp_numbers = case
      when array_position(owner_whatsapp_numbers, '+966540533445') is null
        then owner_whatsapp_numbers || '+966540533445'::text
      else owner_whatsapp_numbers
    end;

create or replace function public.create_company(
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
declare v_id bigint; v_emails text[]; v_numbers text[];
begin
  if auth.uid() is null or not exists (
    select 1 from public.users where id = public.aqura_current_user_id()
  ) then raise exception 'Authentication required'; end if;
  if nullif(trim(p_name_ar), '') is null or nullif(trim(p_name_en), '') is null then
    raise exception 'Arabic and English names are required';
  end if;
  select coalesce(array_agg(trim(value)), '{}') into v_emails from unnest(coalesce(p_owner_emails, '{}')) value where nullif(trim(value), '') is not null;
  select coalesce(array_agg(trim(value)), '{}') into v_numbers from unnest(coalesce(p_owner_whatsapp_numbers, '{}')) value where nullif(trim(value), '') is not null;
  if cardinality(v_emails) = 0 then raise exception 'At least one owner email is required'; end if;
  if cardinality(v_numbers) = 0 then raise exception 'At least one owner WhatsApp number is required'; end if;
  insert into public.company_master (name_ar, name_en, owner_emails, owner_whatsapp_numbers)
  values (trim(p_name_ar), trim(p_name_en), v_emails, v_numbers)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.update_company(
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
declare v_emails text[]; v_numbers text[];
begin
  if auth.uid() is null or not exists (
    select 1 from public.users where id = public.aqura_current_user_id()
  ) then raise exception 'Authentication required'; end if;
  if nullif(trim(p_name_ar), '') is null or nullif(trim(p_name_en), '') is null then
    raise exception 'Arabic and English names are required';
  end if;
  select coalesce(array_agg(trim(value)), '{}') into v_emails from unnest(coalesce(p_owner_emails, '{}')) value where nullif(trim(value), '') is not null;
  select coalesce(array_agg(trim(value)), '{}') into v_numbers from unnest(coalesce(p_owner_whatsapp_numbers, '{}')) value where nullif(trim(value), '') is not null;
  if cardinality(v_emails) = 0 then raise exception 'At least one owner email is required'; end if;
  if cardinality(v_numbers) = 0 then raise exception 'At least one owner WhatsApp number is required'; end if;
  update public.company_master
  set name_ar = trim(p_name_ar), name_en = trim(p_name_en), owner_emails = v_emails,
      owner_whatsapp_numbers = v_numbers, updated_at = now()
  where id = p_company_id;
  if not found then raise exception 'Company not found'; end if;
end;
$$;

commit;
