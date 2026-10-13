begin;

alter table public.assistant_workflow_tasks
  add column if not exists source_record_id uuid;

create unique index if not exists assistant_workflow_tasks_receiving_bp_unique
  on public.assistant_workflow_tasks (source_record_id)
  where task_type = 'receiving_bank_payment' and source_record_id is not null;

comment on column public.assistant_workflow_tasks.source_record_id is
  'Source business record for idempotent assistant workflow task creation.';

commit;
