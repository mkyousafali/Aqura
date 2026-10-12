begin;

create table if not exists public.assistant_workflow_tasks (
    id uuid primary key default gen_random_uuid(),
    task_type text not null,
    title text not null,
    branch_id bigint not null references public.branches(id) on delete cascade,
    assigned_to uuid not null references public.users(id),
    created_by uuid not null references public.users(id),
    payload jsonb not null default '{}'::jsonb,
    status text not null default 'pending' check (status in ('pending','in_progress','completed','failed','cancelled')),
    result jsonb,
    created_at timestamptz not null default now(),
    started_at timestamptz,
    completed_at timestamptz,
    updated_at timestamptz not null default now()
);

create index if not exists assistant_workflow_tasks_assignee_idx
    on public.assistant_workflow_tasks (assigned_to, status, created_at desc);
create index if not exists assistant_workflow_tasks_branch_idx
    on public.assistant_workflow_tasks (branch_id, created_at desc);

create or replace function public.touch_assistant_workflow_tasks_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists assistant_workflow_tasks_updated_at on public.assistant_workflow_tasks;
create trigger assistant_workflow_tasks_updated_at before update on public.assistant_workflow_tasks
for each row execute function public.touch_assistant_workflow_tasks_updated_at();

alter table public.assistant_workflow_tasks enable row level security;
revoke all on public.assistant_workflow_tasks from anon, authenticated;
grant all on public.assistant_workflow_tasks to service_role;

commit;
