-- Appended to the temporary-schema harness. No business records are modified.
create function pg_temp.qa_receiving(p_task uuid, p_type text, p_amount numeric,
  p_splits numeric[] default null, p_legacy boolean default false)
returns void language plpgsql as $$
declare v_piece numeric; v_ids uuid[];
begin
  insert into pg_temp.receiving_records values (p_task, 2, 77,
    case when p_type = 'receiving_cash_payment' then 'Cash on Delivery' else 'Bank on Delivery' end,
    p_amount, p_amount);
  foreach v_piece in array coalesce(p_splits, array[p_amount]) loop
    insert into pg_temp.vendor_payment_schedule
      (id, receiving_record_id, branch_id, vendor_id, bill_amount, final_bill_amount, approval_status)
      values (gen_random_uuid(), p_task, 2, 77, v_piece, v_piece, 'approved');
  end loop;
  select array_agg(id order by id) into v_ids from pg_temp.vendor_payment_schedule where receiving_record_id = p_task;
  insert into pg_temp.assistant_workflow_tasks (id, task_type, source_record_id, branch_id, payload)
    values (p_task, p_type, p_task, 2,
      jsonb_build_object('receiving_record_id', p_task, 'amount', p_amount, 'vendor_id', 77) ||
      case when p_legacy then '{}'::jsonb else jsonb_build_object('payment_schedule_ids', v_ids) end);
end;
$$;

create function pg_temp.qa_receiving_reject(p_task uuid, p_error text, p_name text)
returns void language plpgsql as $$
declare v_rejected boolean := false;
begin
  begin
    update pg_temp.assistant_workflow_tasks set status = 'completed', completed_at = now() where id = p_task;
  exception when others then
    if sqlerrm not like p_error then raise; end if;
    v_rejected := true;
  end;
  perform pg_temp.qa_assert(v_rejected, p_name);
  perform pg_temp.qa_assert(not exists (select 1 from pg_temp.vendor_payment_schedule
    where receiving_record_id = p_task and is_paid), p_name || ' leaves sources unpaid');
  perform pg_temp.qa_assert((select status <> 'completed' from pg_temp.assistant_workflow_tasks where id = p_task),
    p_name || ' rolls back task completion');
end;
$$;

do $tests$
declare
  t uuid; typ text; master_id uuid := gen_random_uuid();
  original_reference text; original_date timestamp;
begin
  foreach typ in array array['receiving_cash_payment', 'receiving_bank_payment'] loop
    t := gen_random_uuid();
    perform pg_temp.qa_receiving(t, typ, 348.54);
    perform pg_temp.qa_assert(not (select is_paid from pg_temp.vendor_payment_schedule where receiving_record_id = t), typ || ' task creation stays unpaid');
    update pg_temp.assistant_workflow_tasks set status = 'in_progress' where id = t;
    perform pg_temp.qa_assert(not (select is_paid from pg_temp.vendor_payment_schedule where receiving_record_id = t), typ || ' processing stays unpaid');
    update pg_temp.assistant_workflow_tasks set status = 'failed' where id = t;
    perform pg_temp.qa_assert(not (select is_paid from pg_temp.vendor_payment_schedule where receiving_record_id = t), typ || ' failed posting stays unpaid');
    update pg_temp.assistant_workflow_tasks set status = 'pending' where id = t;
    perform pg_temp.qa_assert(not (select is_paid from pg_temp.vendor_payment_schedule where receiving_record_id = t), typ || ' test-only pending result stays unpaid');
    update pg_temp.assistant_workflow_tasks set status = 'completed', completed_at = '2026-11-12 12:00:00+03' where id = t;
    perform pg_temp.qa_assert((select is_paid and paid_date is not null and transaction_date = '2026-11-12 12:00:00+03'::timestamptz
      and payment_reference = 'AI receiving task ' || t::text from pg_temp.vendor_payment_schedule where receiving_record_id = t), typ || ' successful posting marks payment paid with audit details');
    select payment_reference, paid_date into original_reference, original_date from pg_temp.vendor_payment_schedule where receiving_record_id = t;
    update pg_temp.assistant_workflow_tasks set status = 'completed', completed_at = now() where id = t;
    perform pg_temp.qa_assert((select payment_reference = original_reference and paid_date = original_date from pg_temp.vendor_payment_schedule where receiving_record_id = t), typ || ' repeated acknowledgement preserves payment audit');

    -- Split schedules represent a single full receiving-bill voucher.
    t := gen_random_uuid();
    perform pg_temp.qa_receiving(t, typ, 300, array[100::numeric, 200::numeric]);
    update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t;
    perform pg_temp.qa_assert((select count(*) = 2 and bool_and(is_paid) from pg_temp.vendor_payment_schedule where receiving_record_id = t), typ || ' completion pays all matching approved installments');

    t := gen_random_uuid();
    perform pg_temp.qa_receiving(t, typ, 50, null, true);
    update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t;
    perform pg_temp.qa_assert((select is_paid from pg_temp.vendor_payment_schedule where receiving_record_id = t), typ || ' legacy receiving payload is supported');
  end loop;

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_cash_payment', 100);
  update pg_temp.vendor_payment_schedule set approval_status = 'pending' where receiving_record_id = t;
  perform pg_temp.qa_receiving_reject(t, 'Linked receiving payments must%', 'unapproved bill rejects automatic Paid');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_bank_payment', 100);
  update pg_temp.receiving_records set branch_id = 3 where id = t;
  perform pg_temp.qa_receiving_reject(t, 'Linked receiving record was not found%', 'wrong receiving branch is rejected');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_cash_payment', 100);
  update pg_temp.vendor_payment_schedule set branch_id = 3 where receiving_record_id = t;
  perform pg_temp.qa_receiving_reject(t, 'Linked receiving payments must%', 'wrong payment branch is rejected');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_cash_payment', 100);
  update pg_temp.vendor_payment_schedule set vendor_id = 88 where receiving_record_id = t;
  perform pg_temp.qa_receiving_reject(t, 'Linked receiving payments must%', 'wrong payment vendor is rejected');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_bank_payment', 100);
  update pg_temp.receiving_records set payment_method = 'Cash on Delivery' where id = t;
  perform pg_temp.qa_receiving_reject(t, 'Receiving payment method does not match%', 'wrong payment method is rejected');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_bank_payment', 100);
  update pg_temp.receiving_records set final_bill_amount = 80 where id = t;
  perform pg_temp.qa_receiving_reject(t, 'Receiving bill amount changed%', 'changed receiving amount is rejected');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_bank_payment', 100);
  update pg_temp.vendor_payment_schedule set final_bill_amount = 80 where receiving_record_id = t;
  perform pg_temp.qa_receiving_reject(t, 'Linked receiving payment schedules or amounts changed%', 'changed schedule amount is rejected');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_cash_payment', 100);
  delete from pg_temp.vendor_payment_schedule where receiving_record_id = t;
  perform pg_temp.qa_receiving_reject(t, 'Linked receiving payment schedules or amounts changed%', 'missing schedule is rejected');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_cash_payment', 100);
  update pg_temp.vendor_payment_schedule set id = gen_random_uuid() where receiving_record_id = t;
  perform pg_temp.qa_receiving_reject(t, 'Linked receiving payment schedules changed%', 'replaced schedule snapshot is rejected even with the same total');

  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_cash_payment', 100);
  update pg_temp.assistant_workflow_tasks set source_record_id = gen_random_uuid() where id = t;
  perform pg_temp.qa_receiving_reject(t, 'Linked receiving record does not match%', 'mismatched source record is rejected');

  -- Already-paid records retain their earlier reference and paid date.
  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_bank_payment', 100);
  update pg_temp.vendor_payment_schedule set is_paid = true, payment_reference = 'existing receipt', paid_date = '2026-11-01'
    where receiving_record_id = t;
  update pg_temp.assistant_workflow_tasks set status = 'completed' where id = t;
  perform pg_temp.qa_assert((select payment_reference = 'existing receipt' and paid_date = '2026-11-01'::timestamp
    from pg_temp.vendor_payment_schedule where receiving_record_id = t), 'existing paid audit remains intact');

  -- Manual completion must not automatically pay a receiving bill.
  t := gen_random_uuid();
  perform pg_temp.qa_receiving(t, 'receiving_cash_payment', 100);
  insert into pg_temp.users values (master_id, 'active', true);
  perform set_config('test.actor', master_id::text, true);
  perform pg_temp.master_complete_assistant_task(t, 'Manual task-only completion');
  perform pg_temp.qa_assert((select status = 'completed' from pg_temp.assistant_workflow_tasks where id = t), 'manual receiving task completion remains supported');
  perform pg_temp.qa_assert(not (select is_paid from pg_temp.vendor_payment_schedule where receiving_record_id = t), 'manual task-only receiving completion leaves payment unpaid');
end;
$tests$;
