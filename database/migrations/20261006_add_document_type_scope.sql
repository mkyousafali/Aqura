begin;

alter table public.company_document_types
  add column if not exists scope text not null default 'common';

alter table public.company_document_types
  drop constraint if exists company_document_types_scope_check;

alter table public.company_document_types
  add constraint company_document_types_scope_check
  check (scope in ('common', 'branch_wise'));

drop function if exists public.create_company_document_type(text, text);

create function public.create_company_document_type(
  p_name_ar text,
  p_name_en text,
  p_scope text
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
  ) then
    raise exception 'Authentication required';
  end if;

  if nullif(trim(p_name_ar), '') is null or nullif(trim(p_name_en), '') is null then
    raise exception 'Arabic and English document names are required';
  end if;

  if p_scope not in ('common', 'branch_wise') then
    raise exception 'Document scope must be common or branch-wise';
  end if;

  insert into public.company_document_types (name_ar, name_en, scope)
  values (trim(p_name_ar), trim(p_name_en), p_scope)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.create_company_document_type(text, text, text) from public, anon;
grant execute on function public.create_company_document_type(text, text, text) to authenticated, service_role;

commit;
