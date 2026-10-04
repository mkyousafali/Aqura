-- Allow the public login page to load its configured branding before sign-in.
begin;

grant select on table public.login_layout to anon;

drop policy if exists anon_read_login_layout on public.login_layout;
create policy anon_read_login_layout
  on public.login_layout
  for select
  to anon
  using (true);

commit;
