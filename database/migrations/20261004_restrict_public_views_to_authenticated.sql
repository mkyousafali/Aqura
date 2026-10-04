-- Views do not support RLS. Restrict every public normal/materialized view
-- through SQL grants so anonymous API clients cannot read them.
begin;

do $$
declare
  item record;
begin
  for item in
    select n.nspname as schema_name, c.relname as relation_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('v', 'm')
  loop
    execute format(
      'revoke all privileges on table %I.%I from anon',
      item.schema_name,
      item.relation_name
    );
    execute format(
      'grant select on table %I.%I to authenticated',
      item.schema_name,
      item.relation_name
    );
  end loop;
end
$$;

commit;
