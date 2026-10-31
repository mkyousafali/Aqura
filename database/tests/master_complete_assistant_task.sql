-- Appended to the temporary-schema payment-completion harness; rollback only.
do $tests$
declare
  master_id uuid := gen_random_uuid(); employee_id uuid := gen_random_uuid();
  v_task_id uuid := gen_random_uuid(); bill_id uuid := gen_random_uuid();
  schedule_id uuid := gen_random_uuid(); batch_id uuid := gen_random_uuid();
  reply jsonb; rejected boolean;
begin
  insert into pg_temp.users values (master_id, 'active', true), (employee_id, 'active', false);
  insert into pg_temp.vendor_payment_schedule (id, branch_id, vendor_id, bill_amount, final_bill_amount)
    values (bill_id, 3, 1508, 623, 623);
  insert into pg_temp.bank_payment_planner_schedule_items
    (schedule_id, application_batch_id, source_type, source_id, source_branch_id, paid_from_branch_id, vendor_id, amount)
    values (schedule_id, batch_id, 'Bill', bill_id::text, 3, 3, '1508', 10000);
  perform pg_temp.qa_planner(v_task_id, schedule_id, batch_id, '1508', 'bank_planner_bp', 3, 10000);
  rejected := false;
  begin
    update pg_temp.assistant_workflow_tasks set status = 'completed' where id = v_task_id;
  exception when others then rejected := true; end;
  perform pg_temp.qa_assert(rejected, 'ordinary completion still rejects changed bill amounts');

  perform set_config('test.actor', employee_id::text, true);
  rejected := false;
  begin perform pg_temp.master_complete_assistant_task(v_task_id, 'Master completion test');
  exception when others then rejected := true; end;
  perform pg_temp.qa_assert(rejected, 'non-master code identity cannot override completion');
  perform pg_temp.qa_assert(not exists(select 1 from pg_temp.assistant_task_manual_completions where task_id = v_task_id), 'denied request creates no audit record');

  perform set_config('test.actor', master_id::text, true);
  reply := pg_temp.master_complete_assistant_task(v_task_id, 'Master completion test');
  perform pg_temp.qa_assert(reply->>'success' = 'true' and reply->'task'->>'status' = 'completed', 'master task-only completion succeeds despite bill mismatch');
  perform pg_temp.qa_assert((select not is_paid and bill_amount = 623 and final_bill_amount = 623 from pg_temp.vendor_payment_schedule where id = bill_id), 'master completion leaves bill amount and paid status unchanged');
  perform pg_temp.qa_assert((select count(*) = 1 from pg_temp.assistant_task_manual_completions where completed_by = master_id), 'override records verified master identity');
  reply := pg_temp.master_complete_assistant_task(v_task_id, 'Master completion test');
  perform pg_temp.qa_assert(reply->>'success' = 'true', 'exact network retry succeeds idempotently');
  perform pg_temp.qa_assert((select count(*) = 1 from pg_temp.assistant_task_manual_completions where completed_by = master_id), 'retry cannot duplicate audit');
  rejected := false;
  begin perform pg_temp.master_complete_assistant_task(v_task_id, 'Changed outcome');
  exception when others then rejected := true; end;
  perform pg_temp.qa_assert(rejected, 'different outcome cannot overwrite completed task');
  update pg_temp.users set is_master_admin = false where id = master_id;
  rejected := false;
  begin perform pg_temp.master_complete_assistant_task(v_task_id, 'Master completion test');
  exception when others then rejected := true; end;
  perform pg_temp.qa_assert(rejected, 'revoked master role is checked even on retry');
end;
$tests$;
