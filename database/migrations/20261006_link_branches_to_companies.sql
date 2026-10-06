begin;

alter table public.branches
  add column if not exists company_id bigint;

update public.branches
set company_id = (select id from public.company_master order by id limit 1)
where company_id is null;

do $$
begin
  if exists (select 1 from public.branches where company_id is null) then
    raise exception 'A company must exist before branches can be linked';
  end if;
end
$$;

alter table public.branches
  alter column company_id set not null;

alter table public.branches
  drop constraint if exists branches_company_id_fkey;

alter table public.branches
  add constraint branches_company_id_fkey
  foreign key (company_id) references public.company_master(id)
  on delete restrict;

create index if not exists branches_company_id_idx
  on public.branches(company_id);

commit;
