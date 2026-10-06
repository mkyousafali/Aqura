begin;

create or replace function public.update_company(
  p_company_id bigint,
  p_name_ar text,
  p_name_en text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.users where id = public.aqura_current_user_id()
  ) then
    raise exception 'Authentication required';
  end if;

  if nullif(trim(p_name_ar), '') is null or nullif(trim(p_name_en), '') is null then
    raise exception 'Arabic and English names are required';
  end if;

  update public.company_master
     set name_ar = trim(p_name_ar),
         name_en = trim(p_name_en),
         updated_at = now()
   where id = p_company_id;

  if not found then
    raise exception 'Company not found';
  end if;
end;
$$;

revoke all on function public.update_company(bigint, text, text) from public, anon;
grant execute on function public.update_company(bigint, text, text) to authenticated, service_role;

commit;
