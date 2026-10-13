begin;

create unique index if not exists assistant_workflow_tasks_receiving_cp_unique
  on public.assistant_workflow_tasks (source_record_id)
  where task_type = 'receiving_cash_payment' and source_record_id is not null;

commit;
