begin;

alter table public.assistant_workflow_tasks
  add column if not exists workflow_key text;

create unique index if not exists assistant_workflow_tasks_workflow_key_unique
  on public.assistant_workflow_tasks (workflow_key)
  where workflow_key is not null;

comment on column public.assistant_workflow_tasks.workflow_key is
  'Stable business key used to prevent duplicate workflow tasks after refresh or retry.';

commit;
