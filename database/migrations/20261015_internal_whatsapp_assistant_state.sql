begin;

create table if not exists public.wa_internal_assistant_state (
  conversation_id uuid primary key references public.wa_conversations(id) on delete cascade,
  pending_action text not null,
  context jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.wa_internal_assistant_state enable row level security;
revoke all on public.wa_internal_assistant_state from public, anon, authenticated;
grant all on public.wa_internal_assistant_state to service_role;

commit;
