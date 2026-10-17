begin;
with actor as (
  select coalesce(
    (select created_by from public.electricity_sadad_accounts limit 1),
    (select id from public.users order by created_at limit 1)
  ) id
), seed(provider,subscriber_number) as (values
  ('mobily','1001256022906365'),
  ('stc','05255270771'),
  ('stc','05255268483'),
  ('mobily','966544236201')
)
insert into public.telecom_sadad_subscribers(provider,subscriber_number,branch_id,created_by)
select seed.provider,seed.subscriber_number,1,actor.id from seed cross join actor
on conflict(provider,subscriber_number) do update set branch_id=1,updated_at=now();
commit;
