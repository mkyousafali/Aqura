begin;
alter table public.non_approved_payment_scheduler
  add column if not exists vendor_id integer,
  add column if not exists vendor_name text;

-- Canonical vendor identities must belong to the schedule branch.
create or replace function public.scheduler_vendor_recipient()
returns trigger language plpgsql set search_path = public as $$
declare
 v_name text;
begin
 if new.vendor_id is not null then
  select vendor_name into v_name from public.vendors
   where erp_vendor_id = new.vendor_id and branch_id = new.branch_id;
  if not found then raise exception 'Select a vendor from this schedule branch.'; end if;
  new.vendor_name := v_name;
 end if;
 return new;
end;
$$;
revoke all on function public.scheduler_vendor_recipient() from public,anon,authenticated;
drop trigger if exists scheduler_vendor_recipient on public.non_approved_payment_scheduler;
create trigger scheduler_vendor_recipient before insert or update of vendor_id,vendor_name,branch_id
 on public.non_approved_payment_scheduler for each row execute function public.scheduler_vendor_recipient();
drop trigger if exists scheduler_vendor_recipient on public.expense_scheduler;
create trigger scheduler_vendor_recipient before insert or update of vendor_id,vendor_name,branch_id
 on public.expense_scheduler for each row execute function public.scheduler_vendor_recipient();
-- Preserve the current recurrence implementation while carrying the same
-- recipient into every generated row (both pending and approved source tables).
do $migration$
declare
 v_definition text;
 v_columns integer;
 v_values integer;
begin
 select pg_get_functiondef('public.generate_recurring_occurrences(integer,text)'::regprocedure)
  into v_definition;
 if strpos(v_definition, 'rec.vendor_id') = 0 then
  select count(*) into v_columns from regexp_matches(v_definition, '(^|[^[:alnum:]_.])branch_name,', 'g');
  select count(*) into v_values from regexp_matches(v_definition, 'rec\.branch_name,', 'g');
  if v_columns = 0 or v_columns <> v_values then
   raise exception 'Recurring generator structure changed; review vendor propagation before deployment.';
  end if;
  v_definition := regexp_replace(v_definition, '(^|[^[:alnum:]_.])branch_name,', '\1branch_name, vendor_id, vendor_name,', 'g');
  v_definition := replace(v_definition, 'rec.branch_name,', 'rec.branch_name, rec.vendor_id, rec.vendor_name,');
  execute v_definition;
 end if;
end;
$migration$;
notify pgrst, 'reload schema';
commit;
