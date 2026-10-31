begin;
create temp table users (id uuid primary key, status text, is_master_admin boolean, branch_id bigint);
create temp table denomination_permissions (user_id uuid, can_edit boolean, can_see_all_branches boolean);
create temp table expense_requisitions (id bigint primary key, status text);
create temp table expense_scheduler (
 id bigserial primary key, branch_id bigint, requisition_id bigint, bill_number text,
 requisition_number text, amount numeric, due_date date, is_paid boolean default false,
 paid_date timestamptz, payment_reference text, created_at timestamptz, updated_at timestamptz, updated_by uuid
);
create function pg_temp.aqura_current_user_id() returns uuid language sql stable as $$
 select nullif(current_setting('test.actor', true), '')::uuid;
$$;
-- INSTALL_MIGRATION_HERE
create temp table qa_results (name text);
create function pg_temp.qa_assert(p_condition boolean, p_name text) returns void language plpgsql as $$
begin
 if not coalesce(p_condition, false) then raise exception 'FAIL: %', p_name; end if;
 insert into pg_temp.qa_results values(p_name);
end;
$$;
do $tests$
declare
 actor uuid := gen_random_uuid(); req_status text; original_id bigint;
 split_result jsonb; denied boolean; i bigint := 1;
begin
 insert into pg_temp.users values(actor, 'active', false, 3);
 insert into pg_temp.denomination_permissions values(actor, true, false);
 perform set_config('test.actor', actor::text, true);
 foreach req_status in array array['approved','completed','closed'] loop
  insert into pg_temp.expense_requisitions values(i, req_status);
  insert into pg_temp.expense_scheduler(branch_id,requisition_id,amount,requisition_number)
   values(3,i,1616.65,'REQ-TEST') returning id into original_id;
  split_result := pg_temp.denomination_split_expense_payment(original_id::text,616.65,'2026-10-31',1616.65);
  perform pg_temp.qa_assert((select amount = 1000 from pg_temp.expense_scheduler where id = original_id), req_status || ' retains correct remainder');
  perform pg_temp.qa_assert((select amount = 616.65 and not is_paid and requisition_id = i from pg_temp.expense_scheduler where id = (split_result->>'source_id')::bigint), req_status || ' creates unpaid linked split');
  i := i + 1;
 end loop;
 foreach req_status in array array['pending','rejected','sent_for_approval','missing'] loop
  if req_status <> 'missing' then insert into pg_temp.expense_requisitions values(i,req_status); end if;
  insert into pg_temp.expense_scheduler(branch_id,requisition_id,amount) values(3,i,1616.65) returning id into original_id;
  denied := false;
  begin perform pg_temp.denomination_split_expense_payment(original_id::text,616.65,'2026-10-31',1616.65);
  exception when others then denied := true; end;
  perform pg_temp.qa_assert(denied,req_status || ' cannot split');
  perform pg_temp.qa_assert((select amount = 1616.65 from pg_temp.expense_scheduler where id = original_id),req_status || ' remains unchanged');
  i := i + 1;
 end loop;
end;
$tests$;
select 'PASS: ' || count(*) || ' expense split assertions' from pg_temp.qa_results;
rollback;
