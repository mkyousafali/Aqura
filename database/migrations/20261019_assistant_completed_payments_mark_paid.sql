begin;

-- Internal helper. Only the completion trigger may mark these source records.
create or replace function public.assistant_mark_payment_sources_paid(
  p_sources jsonb, p_reference text, p_paid_at timestamptz, p_actor uuid
) returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_source jsonb;
  v_bill public.vendor_payment_schedule%rowtype;
  v_expense public.expense_scheduler%rowtype;
  v_changed integer := 0;
  v_rows integer;
begin
  if jsonb_typeof(p_sources) is distinct from 'array' or jsonb_array_length(p_sources) = 0 then
    raise exception 'No linked payment sources were found.';
  end if;
  if (select count(*) from jsonb_array_elements(p_sources)) <>
     (select count(distinct (value->>'type', value->>'id')) from jsonb_array_elements(p_sources)) then
    raise exception 'Duplicate linked payment sources.';
  end if;

  -- Stable lock order also protects overlapping payment groups and splits.
  for v_source in select value from jsonb_array_elements(p_sources)
    order by value->>'type', value->>'id'
  loop
    if coalesce((v_source->>'amount')::numeric, 0) <= 0
       or (v_source->>'amount')::numeric::text in ('NaN', 'Infinity', '-Infinity') then
      raise exception 'Invalid linked payment amount.';
    end if;
    if v_source->>'type' = 'Bill' then
      select * into v_bill from public.vendor_payment_schedule
        where id = (v_source->>'id')::uuid for update;
      if not found or v_bill.branch_id is distinct from (v_source->>'branch_id')::bigint
         or coalesce(v_bill.final_bill_amount, v_bill.bill_amount, 0) is distinct from (v_source->>'amount')::numeric
         or (v_source ? 'vendor_id' and v_bill.vendor_id::text is distinct from v_source->>'vendor_id') then
        raise exception 'Linked vendor bill changed or was not found; review this ERP posting.';
      end if;
      update public.vendor_payment_schedule set
        is_paid = true, paid_date = p_paid_at, transaction_date = p_paid_at,
        payment_reference = coalesce(nullif(payment_reference, ''), p_reference), updated_at = now()
        where id = v_bill.id and not coalesce(is_paid, false);
    elsif v_source->>'type' = 'Expense' then
      select * into v_expense from public.expense_scheduler
        where id = (v_source->>'id')::bigint for update;
      if not found or v_expense.branch_id is distinct from (v_source->>'branch_id')::bigint
         or v_expense.amount is distinct from (v_source->>'amount')::numeric
         or (v_source ? 'vendor_id' and v_expense.vendor_id::text is distinct from v_source->>'vendor_id') then
        raise exception 'Linked expense changed or was not found; review this ERP posting.';
      end if;
      update public.expense_scheduler set
        is_paid = true, status = 'paid', paid_date = p_paid_at,
        payment_reference = coalesce(nullif(payment_reference, ''), p_reference),
        updated_by = p_actor, updated_at = now()
        where id = v_expense.id and not coalesce(is_paid, false);
    else
      raise exception 'Invalid linked payment source type.';
    end if;
    get diagnostics v_rows = row_count;
    v_changed := v_changed + v_rows;
  end loop;
  return v_changed;
end;
$$;

revoke all on function public.assistant_mark_payment_sources_paid(jsonb, text, timestamptz, uuid)
  from public, anon, authenticated, service_role;

create or replace function public.sync_assistant_payment_sources_paid()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_sources jsonb := '[]'::jsonb;
  v_bill_ids uuid[];
  v_expense_ids bigint[];
  v_total numeric := 0;
  v_expected numeric;
  v_source record;
  v_scan public.pos_scan_requests%rowtype;
  v_bp public.assistant_workflow_tasks%rowtype;
  v_vendor text;
  v_task_batch text;
  v_item_batch text;
  v_batch_count integer;
  v_items jsonb;
  v_paying_branch bigint;
  v_first_task_at timestamptz;
begin
  if new.status <> 'completed' or old.status is not distinct from new.status then return new; end if;

  if new.task_type in ('receiving_bank_payment', 'receiving_cash_payment')
     and new.payload ? 'pay_to_credit_transaction_id' then
    perform pg_advisory_xact_lock(hashtextextended('assistant-paid:credit:' || new.source_record_id::text, 0));
    select * into v_scan from public.pos_scan_requests
      where id = new.source_record_id and request_type = 'pay_to_credit_slip' for update;
    if not found or v_scan.branch_id is distinct from new.branch_id
       or v_scan.id::text is distinct from new.payload->>'pay_to_credit_transaction_id' then
      raise exception 'Linked Pay to Credit transaction was not found or does not match this task.';
    end if;
    if (new.task_type = 'receiving_cash_payment' and v_scan.payment_account_type is distinct from 'cash')
       or (new.task_type = 'receiving_bank_payment' and v_scan.payment_account_type is distinct from 'bank') then
      raise exception 'Pay to Credit payment type does not match the completed task.';
    end if;
    select coalesce(array_agg(value::uuid), '{}'::uuid[]) into v_bill_ids
      from jsonb_array_elements_text(coalesce(new.payload->'payment_schedule_ids', '[]'::jsonb));
    select coalesce(array_agg(value::bigint), '{}'::bigint[]) into v_expense_ids
      from jsonb_array_elements_text(coalesce(new.payload->'expense_schedule_ids', '[]'::jsonb));

    for v_source in
      select id, branch_id, coalesce(final_bill_amount, bill_amount, 0) as amount
      from public.vendor_payment_schedule where id = any(v_bill_ids) order by id for update
    loop
      v_sources := v_sources || jsonb_build_array(jsonb_build_object(
        'type', 'Bill', 'id', v_source.id::text, 'branch_id', new.branch_id, 'amount', v_source.amount));
      if v_source.branch_id is distinct from new.branch_id then raise exception 'Linked bill belongs to another branch.'; end if;
      v_total := v_total + v_source.amount;
    end loop;
    for v_source in
      select id, branch_id, amount from public.expense_scheduler
      where id = any(v_expense_ids) order by id::text for update
    loop
      v_sources := v_sources || jsonb_build_array(jsonb_build_object(
        'type', 'Expense', 'id', v_source.id::text, 'branch_id', new.branch_id, 'amount', v_source.amount));
      if v_source.branch_id is distinct from new.branch_id then raise exception 'Linked expense belongs to another branch.'; end if;
      v_total := v_total + v_source.amount;
    end loop;
    v_expected := (new.payload->>'amount')::numeric;
    if jsonb_array_length(v_sources) <> cardinality(v_bill_ids) + cardinality(v_expense_ids)
       or v_expected is null or v_expected <= 0 or v_expected::text in ('NaN', 'Infinity', '-Infinity')
       or v_total is distinct from v_expected
       or v_expected > coalesce(v_scan.extracted_amount, 0) then
      raise exception 'Selected payment sources or amounts changed; review this ERP posting.';
    end if;
    perform public.assistant_mark_payment_sources_paid(v_sources, 'AI task ' || new.id::text,
      coalesce(v_scan.completed_at, new.completed_at, now()), new.assigned_to);

  elsif new.task_type in ('bank_planner_bp', 'bank_planner_jv') then
    v_vendor := nullif(new.payload->>'vendor_id', '');
    v_task_batch := nullif(new.payload->>'application_batch_id', '');
    if new.source_record_id is null or v_vendor is null then return new; end if;
    perform pg_advisory_xact_lock(hashtextextended('assistant-paid:planner:' || new.source_record_id::text
      || ':' || v_vendor || ':' || coalesce(v_task_batch, 'legacy'), 0));

    -- Never wait for unrelated vendors, dates or application batches.
    if exists (select 1 from public.assistant_workflow_tasks t
      where t.source_record_id = new.source_record_id
        and t.task_type in ('bank_planner_bp', 'bank_planner_jv')
        and t.payload->>'vendor_id' = v_vendor
        and nullif(t.payload->>'application_batch_id', '') is not distinct from v_task_batch
        and t.status <> 'completed') then return new; end if;
    if (select count(*) from public.assistant_workflow_tasks t
      where t.source_record_id = new.source_record_id and t.task_type = 'bank_planner_bp'
        and t.payload->>'vendor_id' = v_vendor
        and nullif(t.payload->>'application_batch_id', '') is not distinct from v_task_batch) <> 1 then return new; end if;
    select * into v_bp from public.assistant_workflow_tasks t
      where t.source_record_id = new.source_record_id and t.task_type = 'bank_planner_bp'
        and t.payload->>'vendor_id' = v_vendor
        and nullif(t.payload->>'application_batch_id', '') is not distinct from v_task_batch;
    select min(t.created_at) into v_first_task_at from public.assistant_workflow_tasks t
      where t.source_record_id = new.source_record_id
        and t.task_type in ('bank_planner_bp', 'bank_planner_jv')
        and t.payload->>'vendor_id' = v_vendor
        and nullif(t.payload->>'application_batch_id', '') is not distinct from v_task_batch;

    v_item_batch := v_task_batch;
    if v_item_batch is null then
      -- Older tasks have no batch ID: resolve only an unambiguous original batch.
      select count(distinct i.application_batch_id), min(i.application_batch_id::text)
        into v_batch_count, v_item_batch from public.bank_payment_planner_schedule_items i
        where i.schedule_id = new.source_record_id and i.vendor_id = v_vendor;
      if v_batch_count <> 1 then return new; end if;
    end if;
    select jsonb_agg(to_jsonb(i) order by i.source_type, i.source_id) into v_items
      from public.bank_payment_planner_schedule_items i
      where i.schedule_id = new.source_record_id and i.vendor_id = v_vendor
        and i.application_batch_id::text = v_item_batch;
    if v_items is null then return new; end if;
    v_paying_branch := (v_items->0->>'paid_from_branch_id')::bigint;
    if v_paying_branch is null or exists (
      select 1 from jsonb_array_elements(v_items) i where
        (i->>'paid_from_branch_id')::bigint is distinct from v_paying_branch
        or nullif(i->>'source_branch_id', '') is null
        or (i->>'created_at')::timestamptz > v_first_task_at
    ) then return new; end if;

    -- The planner creates one BP plus two JVs for each other source branch.
    -- Check the expected multiset, so a deleted/missing JV cannot imply success.
    if exists (
      with branch_amounts as (
        select (i->>'source_branch_id')::bigint as branch_id, sum((i->>'amount')::numeric) as amount
        from jsonb_array_elements(v_items) i group by (i->>'source_branch_id')::bigint
      ), expected as (
        select 'bank_planner_bp'::text as task_type, v_paying_branch as branch_id, sum(amount) as amount from branch_amounts
        union all select 'bank_planner_jv', v_paying_branch, amount from branch_amounts where branch_id <> v_paying_branch
        union all select 'bank_planner_jv', branch_id, amount from branch_amounts where branch_id <> v_paying_branch
      ), expected_counts as (
        select task_type, branch_id, amount, count(*) as n from expected group by task_type, branch_id, amount
      ), actual_counts as (
        select t.task_type, t.branch_id, (t.payload->>'amount')::numeric as amount, count(*) as n
        from public.assistant_workflow_tasks t where t.source_record_id = new.source_record_id
          and t.task_type in ('bank_planner_bp', 'bank_planner_jv') and t.payload->>'vendor_id' = v_vendor
          and nullif(t.payload->>'application_batch_id', '') is not distinct from v_task_batch
        group by t.task_type, t.branch_id, (t.payload->>'amount')::numeric
      ) select 1 from expected_counts e full join actual_counts a
        using (task_type, branch_id, amount) where e.n is distinct from a.n
    ) then return new; end if;

    select jsonb_agg(jsonb_build_object('type', i->>'source_type', 'id', i->>'source_id',
      'branch_id', (i->>'source_branch_id')::bigint, 'vendor_id', i->>'vendor_id',
      'amount', (i->>'amount')::numeric)) into v_sources from jsonb_array_elements(v_items) i;
    perform public.assistant_mark_payment_sources_paid(v_sources, 'AI planner task ' || v_bp.id::text,
      coalesce(new.completed_at, now()), new.assigned_to);
  end if;
  return new;
end;
$$;

revoke all on function public.sync_assistant_payment_sources_paid() from public, anon, authenticated, service_role;
drop trigger if exists assistant_task_mark_payment_sources_paid on public.assistant_workflow_tasks;
create trigger assistant_task_mark_payment_sources_paid
after update of status on public.assistant_workflow_tasks
for each row execute function public.sync_assistant_payment_sources_paid();

-- Future completions only. Do not rewrite financial history in this migration.
notify pgrst, 'reload schema';
commit;
