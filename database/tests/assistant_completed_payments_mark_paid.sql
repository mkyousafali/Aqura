-- Run through the temporary-schema harness; all fixtures are rolled back.
begin;
create temp table vendor_payment_schedule (
  id uuid primary key, branch_id bigint, vendor_id integer,
  bill_amount numeric, final_bill_amount numeric, is_paid boolean default false,
  paid_date timestamp, transaction_date timestamptz, payment_reference text, updated_at timestamptz
);
create temp table expense_scheduler (
  id bigint primary key, branch_id bigint, vendor_id integer, amount numeric,
  is_paid boolean default false, status text default 'pending', paid_date timestamptz,
  payment_reference text, updated_at timestamptz, updated_by uuid
);
create temp table pos_scan_requests (
  id uuid primary key, branch_id bigint, request_type text default 'pay_to_credit_slip',
  payment_account_type text, extracted_amount numeric, completed_at timestamptz, status text
);
create temp table assistant_workflow_tasks (
  id uuid primary key, task_type text, source_record_id uuid, branch_id bigint,
  payload jsonb, status text default 'pending', completed_at timestamptz,
  created_at timestamptz default now(), assigned_to uuid
);
create temp table bank_payment_planner_schedule_items (
  id uuid primary key default gen_random_uuid(), schedule_id uuid,
  application_batch_id uuid, source_type text, source_id text,
  source_branch_id bigint, paid_from_branch_id bigint, vendor_id text,
  amount numeric, created_at timestamptz default now()
);
create temp table qa_results (name text);

-- INSTALL_MIGRATION_HERE

create function pg_temp.qa_assert(p_condition boolean, p_name text) returns void language plpgsql as $$
begin
  if not coalesce(p_condition, false) then raise exception 'FAIL: %', p_name; end if;
  insert into pg_temp.qa_results values (p_name);
end;
$$;

create function pg_temp.qa_credit(p_id uuid, p_type text, p_amount numeric, p_bills uuid[], p_expenses bigint[])
returns void language plpgsql as $$
begin
  insert into pg_temp.pos_scan_requests (id, branch_id, payment_account_type, extracted_amount, completed_at)
    values (p_id, 2, case when p_type = 'receiving_cash_payment' then 'cash' else 'bank' end, p_amount, '2026-10-18 12:00:00+03');
  insert into pg_temp.assistant_workflow_tasks (id, task_type, source_record_id, branch_id, payload)
    values (p_id, p_type, p_id, 2, jsonb_build_object('pay_to_credit_transaction_id', p_id,
      'amount', p_amount, 'payment_schedule_ids', p_bills, 'expense_schedule_ids', p_expenses));
end;
$$;

create function pg_temp.qa_planner(p_id uuid, p_schedule uuid, p_batch uuid, p_vendor text,
  p_type text, p_branch bigint, p_amount numeric) returns void language plpgsql as $$
begin
  insert into pg_temp.assistant_workflow_tasks (id, task_type, source_record_id, branch_id, payload)
    values (p_id, p_type, p_schedule, p_branch,
      jsonb_strip_nulls(jsonb_build_object('vendor_id', p_vendor, 'application_batch_id', p_batch, 'amount', p_amount)));
end;
$$;

do $tests$
declare
  b1 uuid := gen_random_uuid(); b2 uuid := gen_random_uuid();
  t1 uuid := gen_random_uuid(); t2 uuid := gen_random_uuid(); t3 uuid := gen_random_uuid();
  schedule_id uuid := gen_random_uuid(); batch_id uuid := gen_random_uuid(); other_batch uuid := gen_random_uuid();
  bp uuid := gen_random_uuid(); jv1 uuid := gen_random_uuid(); jv2 uuid := gen_random_uuid();
  jv3 uuid := gen_random_uuid(); jv4 uuid := gen_random_uuid();
  before_reference text;
begin
  -- Cash Pay to Credit: mixed sources, plus an untouched split remainder.
  insert into pg_temp.vendor_payment_schedule (id, branch_id, vendor_id, bill_amount) values (b1, 2, 77, 100);
  insert into pg_temp.expense_scheduler (id, branch_id, vendor_id, amount) values (1, 2, 77, 200), (2, 2, 77, 1616.65);
  perform pg_temp.qa_credit(t1, 'receiving_cash_payment', 300, array[b1], array[1::bigint]);
  update pg_temp.assistant_workflow_tasks set status = 'in_progress' where id = t1;
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.vendor_payment_schedule where id = b1), 'in-progress bill stays unpaid');
  update pg_temp.assistant_workflow_tasks set status = 'failed' where id = t1;
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.expense_scheduler where id = 1), 'failed expense stays unpaid');
  update pg_temp.assistant_workflow_tasks set status = 'completed', completed_at = now() where id = t1;
  perform pg_temp.qa_assert((select is_paid from pg_temp.vendor_payment_schedule where id = b1), 'completed CP marks bill paid');
  perform pg_temp.qa_assert((select is_paid and status = 'paid' and paid_date is not null from pg_temp.expense_scheduler where id = 1), 'completed CP marks expense paid with status/date');
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.expense_scheduler where id = 2), 'split remainder stays unpaid');
  select payment_reference into before_reference from pg_temp.expense_scheduler where id = 1;
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t1;
  perform pg_temp.qa_assert((select payment_reference = before_reference from pg_temp.expense_scheduler where id = 1), 'repeated completion preserves reference');

  -- Bank Pay to Credit: expense-only and legacy bill-only payloads.
  perform pg_temp.qa_credit(t2, 'receiving_bank_payment', 1616.65, '{}'::uuid[], array[2::bigint]);
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t2;
  perform pg_temp.qa_assert((select is_paid from pg_temp.expense_scheduler where id = 2), 'completed bank task supports expense-only selection');
  insert into pg_temp.vendor_payment_schedule (id, branch_id, vendor_id, bill_amount) values (b2, 2, 77, 50);
  perform pg_temp.qa_credit(t3, 'receiving_bank_payment', 50, array[b2], '{}'::bigint[]);
  update pg_temp.assistant_workflow_tasks set payload = payload - 'expense_schedule_ids' where id = t3;
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t3;
  perform pg_temp.qa_assert((select is_paid from pg_temp.vendor_payment_schedule where id = b2), 'legacy bill-only payload still works');

  -- An already-paid source retains its existing audit details.
  update pg_temp.expense_scheduler set payment_reference = 'existing bank reference' where id = 2;
  t2 := gen_random_uuid();
  perform pg_temp.qa_credit(t2, 'receiving_cash_payment', 1616.65, '{}'::uuid[], array[2::bigint]);
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t2;
  perform pg_temp.qa_assert((select payment_reference = 'existing bank reference' from pg_temp.expense_scheduler where id = 2), 'already-paid reference remains unchanged');

  -- A changed balance or another branch cannot be silently marked paid.
  insert into pg_temp.expense_scheduler (id, branch_id, vendor_id, amount) values (3, 2, 77, 40), (4, 3, 77, 50);
  t1 := gen_random_uuid();
  perform pg_temp.qa_credit(t1, 'receiving_cash_payment', 50, '{}'::uuid[], array[3::bigint]);
  begin
    update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t1;
    raise exception 'TEST expected changed amount rejection';
  exception when others then
    if sqlerrm not like 'Selected payment sources or amounts changed%' then raise; end if;
  end;
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.expense_scheduler where id = 3), 'changed balance rejects Paid update');
  t1 := gen_random_uuid();
  perform pg_temp.qa_credit(t1, 'receiving_cash_payment', 50, '{}'::uuid[], array[4::bigint]);
  begin
    update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t1;
    raise exception 'TEST expected wrong branch rejection';
  exception when others then
    if sqlerrm <> 'Linked expense belongs to another branch.' then raise; end if;
  end;
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.expense_scheduler where id = 4), 'wrong branch rejects Paid update');

  -- Same-branch planner needs only its own BP; unrelated tasks do not block it.
  b1 := gen_random_uuid();
  insert into pg_temp.vendor_payment_schedule (id, branch_id, vendor_id, bill_amount) values (b1, 2, 77, 100);
  insert into pg_temp.bank_payment_planner_schedule_items
    (schedule_id, application_batch_id, source_type, source_id, source_branch_id, paid_from_branch_id, vendor_id, amount)
    values (schedule_id, batch_id, 'Bill', b1::text, 2, 2, '77', 100);
  perform pg_temp.qa_planner(bp, schedule_id, batch_id, '77', 'bank_planner_bp', 2, 100);
  perform pg_temp.qa_planner(gen_random_uuid(), schedule_id, other_batch, '77', 'bank_planner_bp', 2, 123);
  perform pg_temp.qa_planner(gen_random_uuid(), schedule_id, batch_id, '88', 'bank_planner_bp', 2, 123);
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = bp;
  perform pg_temp.qa_assert((select is_paid from pg_temp.vendor_payment_schedule where id = b1), 'planner ignores unrelated vendor and batch tasks');

  -- Cross-branch batch: BP and both related JVs must finish.
  batch_id := gen_random_uuid(); bp := gen_random_uuid();
  insert into pg_temp.expense_scheduler (id, branch_id, vendor_id, amount) values (5, 3, 77, 200);
  insert into pg_temp.bank_payment_planner_schedule_items
    (schedule_id, application_batch_id, source_type, source_id, source_branch_id, paid_from_branch_id, vendor_id, amount)
    values (schedule_id, batch_id, 'Expense', '5', 3, 2, '77', 200);
  perform pg_temp.qa_planner(bp, schedule_id, batch_id, '77', 'bank_planner_bp', 2, 200);
  perform pg_temp.qa_planner(jv1, schedule_id, batch_id, '77', 'bank_planner_jv', 2, 200);
  perform pg_temp.qa_planner(jv2, schedule_id, batch_id, '77', 'bank_planner_jv', 3, 200);
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = bp;
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.expense_scheduler where id = 5), 'planner BP alone does not mark cross-branch expense paid');
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = jv1;
  update pg_temp.assistant_workflow_tasks set status = 'failed' where id = jv2;
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.expense_scheduler where id = 5), 'failed related JV keeps expense unpaid');
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = jv2;
  perform pg_temp.qa_assert((select is_paid from pg_temp.expense_scheduler where id = 5), 'last successful JV marks group expense paid');

  -- Deleted/missing JVs must not make an incomplete group look complete.
  batch_id := gen_random_uuid(); bp := gen_random_uuid();
  insert into pg_temp.expense_scheduler (id, branch_id, vendor_id, amount) values (6, 3, 77, 200);
  insert into pg_temp.bank_payment_planner_schedule_items
    (schedule_id, application_batch_id, source_type, source_id, source_branch_id, paid_from_branch_id, vendor_id, amount)
    values (schedule_id, batch_id, 'Expense', '6', 3, 2, '77', 200);
  perform pg_temp.qa_planner(bp, schedule_id, batch_id, '77', 'bank_planner_bp', 2, 200);
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = bp;
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.expense_scheduler where id = 6), 'missing JV cannot imply group completion');

  -- Planner source amount must still match its saved schedule snapshot.
  batch_id := gen_random_uuid(); bp := gen_random_uuid();
  insert into pg_temp.expense_scheduler (id, branch_id, vendor_id, amount) values (7, 2, 77, 75);
  insert into pg_temp.bank_payment_planner_schedule_items
    (schedule_id, application_batch_id, source_type, source_id, source_branch_id, paid_from_branch_id, vendor_id, amount)
    values (schedule_id, batch_id, 'Expense', '7', 2, 2, '77', 100);
  perform pg_temp.qa_planner(bp, schedule_id, batch_id, '77', 'bank_planner_bp', 2, 100);
  begin
    update pg_temp.assistant_workflow_tasks set status = 'completed' where id = bp;
    raise exception 'TEST expected changed planner amount rejection';
  exception when others then
    if sqlerrm not like 'Linked expense changed%' then raise; end if;
  end;
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.expense_scheduler where id = 7), 'planner rejects a changed source balance');

  -- Two other branches with equal totals need two distinct paying-side JVs.
  batch_id := gen_random_uuid(); bp := gen_random_uuid();
  jv1 := gen_random_uuid(); jv2 := gen_random_uuid();
  insert into pg_temp.expense_scheduler (id, branch_id, vendor_id, amount) values (8, 3, 77, 50), (9, 4, 77, 50);
  insert into pg_temp.bank_payment_planner_schedule_items
    (schedule_id, application_batch_id, source_type, source_id, source_branch_id, paid_from_branch_id, vendor_id, amount)
    values (schedule_id, batch_id, 'Expense', '8', 3, 2, '77', 50),
           (schedule_id, batch_id, 'Expense', '9', 4, 2, '77', 50);
  perform pg_temp.qa_planner(bp, schedule_id, batch_id, '77', 'bank_planner_bp', 2, 100);
  perform pg_temp.qa_planner(jv1, schedule_id, batch_id, '77', 'bank_planner_jv', 2, 50);
  perform pg_temp.qa_planner(jv2, schedule_id, batch_id, '77', 'bank_planner_jv', 3, 50);
  perform pg_temp.qa_planner(jv3, schedule_id, batch_id, '77', 'bank_planner_jv', 2, 50);
  perform pg_temp.qa_planner(jv4, schedule_id, batch_id, '77', 'bank_planner_jv', 4, 50);
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id in (jv1, jv2, jv3, jv4);
  perform pg_temp.qa_assert(not exists (select 1 from pg_temp.expense_scheduler where id in (8, 9) and is_paid), 'JVs alone cannot mark sources paid before BP');
  update pg_temp.assistant_workflow_tasks set status = 'cancelled' where id = bp;
  perform pg_temp.qa_assert(not exists (select 1 from pg_temp.expense_scheduler where id in (8, 9) and is_paid), 'cancelled BP keeps group unpaid');
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = bp;
  perform pg_temp.qa_assert((select count(*) = 2 from pg_temp.expense_scheduler where id in (8, 9) and is_paid), 'BP finishing last handles equal-amount JV groups');

  -- Legacy planner tasks resolve only a single original batch for that vendor.
  batch_id := gen_random_uuid(); bp := gen_random_uuid();
  insert into pg_temp.expense_scheduler (id, branch_id, vendor_id, amount) values (10, 2, 99, 40);
  insert into pg_temp.bank_payment_planner_schedule_items
    (schedule_id, application_batch_id, source_type, source_id, source_branch_id, paid_from_branch_id, vendor_id, amount)
    values (schedule_id, batch_id, 'Expense', '10', 2, 2, '99', 40);
  perform pg_temp.qa_planner(bp, schedule_id, null, '99', 'bank_planner_bp', 2, 40);
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = bp;
  perform pg_temp.qa_assert((select is_paid from pg_temp.expense_scheduler where id = 10), 'unambiguous legacy planner group remains supported');
end;
$tests$;

select 'PASS: ' || count(*) || ' payment completion assertions' from pg_temp.qa_results;
rollback;
