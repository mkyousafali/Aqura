begin;

alter table public.hr_salary_notes
  drop constraint if exists hr_salary_notes_created_by_fkey;

alter table public.hr_salary_notes
  add constraint hr_salary_notes_created_by_fkey
  foreign key (created_by)
  references public.users(id)
  on delete set null;

commit;
