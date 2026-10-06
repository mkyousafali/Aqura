begin;

-- Old sponsor assignments must not be mapped to unrelated company IDs.
update public.hr_employee_master
set sponsor_id = null
where sponsor_id is not null;

alter table public.hr_employee_master
  drop constraint if exists hr_employee_master_sponsor_id_fkey;

alter table public.hr_employee_master
  add constraint hr_employee_master_sponsor_id_fkey
  foreign key (sponsor_id) references public.company_master(id)
  on delete set null;

create or replace function public.set_employee_sponsor(p_employee_id text, p_sponsor_id bigint)
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

  if not exists (select 1 from public.company_master where id = p_sponsor_id) then
    raise exception 'Company not found';
  end if;

  update public.hr_employee_master
     set sponsor_id = p_sponsor_id
   where id = p_employee_id;

  if not found then
    raise exception 'Employee not found';
  end if;
end;
$$;

revoke all on function public.set_employee_sponsor(text, bigint) from public, anon;
grant execute on function public.set_employee_sponsor(text, bigint) to authenticated, service_role;

drop function if exists public.create_hr_sponsor(text, text);
drop table if exists public.hr_sponsors;

commit;
