begin;

-- Receiving Records tasks post the full receiving bill. Pay to Credit and
-- planner completions keep their existing, separate source-selection rules.
create or replace function public.sync_assistant_receiving_payment_paid()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_record public.receiving_records%rowtype;
  v_payment public.vendor_payment_schedule%rowtype;
  v_record_id uuid;
  v_expected numeric;
  v_total numeric := 0;
  v_sources jsonb := '[]'::jsonb;
  v_schedule_ids uuid[] := '{}'::uuid[];
  v_task_schedule_ids uuid[];
begin
  if new.status <> 'completed' or old.status is not distinct from new.status
     or new.task_type not in ('receiving_bank_payment', 'receiving_cash_payment')
     or new.payload ? 'pay_to_credit_transaction_id'
     or not (new.payload ? 'receiving_record_id') then return new; end if;

  -- Explicit master-admin overrides are task-only, never proof of ERP payment.
  if exists (select 1 from public.assistant_task_manual_completions where task_id = new.id) then
    return new;
  end if;

  v_record_id := (new.payload->>'receiving_record_id')::uuid;
  if v_record_id is null or new.source_record_id is distinct from v_record_id then
    raise exception 'Linked receiving record does not match this payment task.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('assistant-paid:receiving:' || v_record_id::text, 0));
  select * into v_record from public.receiving_records where id = v_record_id for update;
  if not found or v_record.branch_id is distinct from new.branch_id then
    raise exception 'Linked receiving record was not found or belongs to another branch.';
  end if;
  if (new.task_type = 'receiving_cash_payment' and lower(trim(v_record.payment_method)) is distinct from 'cash on delivery')
     or (new.task_type = 'receiving_bank_payment' and lower(trim(v_record.payment_method)) is distinct from 'bank on delivery') then
    raise exception 'Receiving payment method does not match the completed task.';
  end if;
  if new.payload ? 'vendor_id' and new.payload->>'vendor_id' is distinct from v_record.vendor_id::text then
    raise exception 'Receiving vendor changed; review this ERP posting.';
  end if;
  v_expected := (new.payload->>'amount')::numeric;
  if v_expected is null or v_expected <= 0 or v_expected::text in ('NaN', 'Infinity', '-Infinity')
     or v_expected is distinct from coalesce(v_record.final_bill_amount, v_record.bill_amount, 0) then
    raise exception 'Receiving bill amount changed; review this ERP posting.';
  end if;

  for v_payment in select * from public.vendor_payment_schedule
    where receiving_record_id = v_record_id order by id for update
  loop
    if v_payment.branch_id is distinct from new.branch_id
       or v_payment.vendor_id is distinct from v_record.vendor_id
       or v_payment.approval_status is distinct from 'approved' then
      raise exception 'Linked receiving payments must belong to this vendor and branch and be approved.';
    end if;
    v_schedule_ids := array_append(v_schedule_ids, v_payment.id);
    v_total := v_total + coalesce(v_payment.final_bill_amount, v_payment.bill_amount, 0);
    v_sources := v_sources || jsonb_build_array(jsonb_build_object(
      'type', 'Bill', 'id', v_payment.id::text, 'branch_id', v_payment.branch_id,
      'vendor_id', v_payment.vendor_id::text,
      'amount', coalesce(v_payment.final_bill_amount, v_payment.bill_amount, 0)));
  end loop;
  if cardinality(v_schedule_ids) = 0 or v_total is distinct from v_expected then
    raise exception 'Linked receiving payment schedules or amounts changed; review this ERP posting.';
  end if;

  -- New tasks pin their exact schedules. Older receiving tasks are supported
  -- only when the current approved schedules still total the full posted bill.
  if new.payload ? 'payment_schedule_ids' then
    if jsonb_typeof(new.payload->'payment_schedule_ids') is distinct from 'array' then
      raise exception 'Invalid receiving payment schedule selection.';
    end if;
    select coalesce(array_agg(value::uuid order by value::uuid), '{}'::uuid[])
      into v_task_schedule_ids from jsonb_array_elements_text(new.payload->'payment_schedule_ids');
    if v_task_schedule_ids is distinct from v_schedule_ids then
      raise exception 'Linked receiving payment schedules changed; review this ERP posting.';
    end if;
  end if;

  perform public.assistant_mark_payment_sources_paid(v_sources, 'AI receiving task ' || new.id::text,
    coalesce(new.completed_at, now()), new.assigned_to);
  return new;
end;
$$;

revoke all on function public.sync_assistant_receiving_payment_paid() from public, anon, authenticated, service_role;
drop trigger if exists assistant_task_mark_receiving_payment_paid on public.assistant_workflow_tasks;
create trigger assistant_task_mark_receiving_payment_paid
after update of status on public.assistant_workflow_tasks
for each row execute function public.sync_assistant_receiving_payment_paid();

-- Future completions only; do not infer payment from historical task statuses.
notify pgrst, 'reload schema';
commit;
