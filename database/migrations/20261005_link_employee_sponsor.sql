begin;

alter table public.hr_employee_master
  add column if not exists sponsor_id bigint;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'hr_employee_master_sponsor_id_fkey'
      and conrelid = 'public.hr_employee_master'::regclass
  ) then
    alter table public.hr_employee_master
      add constraint hr_employee_master_sponsor_id_fkey
      foreign key (sponsor_id) references public.hr_sponsors(id)
      on delete set null;
  end if;
end
$$;

create index if not exists hr_employee_master_sponsor_id_idx
  on public.hr_employee_master(sponsor_id);

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

  if not exists (select 1 from public.hr_sponsors where id = p_sponsor_id) then
    raise exception 'Sponsor not found';
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

commit;
