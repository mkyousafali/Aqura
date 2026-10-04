-- Allow the public login page to display published offers before sign-in.
begin;

grant select on table public.view_offer to anon;

drop policy if exists anon_read_published_offers on public.view_offer;
create policy anon_read_published_offers
  on public.view_offer
  for select
  to anon
  using (status = 'published');

commit;
