begin;

-- Notification Center and the Electron realtime listener both filter recipient
-- rows by user_id. Add the missing leading-column index for fast user loads.
create index if not exists idx_notification_recipients_user_id_created_at
  on public.notification_recipients (user_id, created_at desc);

create or replace function public.get_user_notification_feed(
  p_user_id uuid,
  p_offset integer default 0,
  p_limit integer default 30
)
returns table (
  id uuid, notification_id uuid, recipient_id uuid,
  title varchar, message text, title_en text, title_ar text,
  message_en text, message_ar text, type varchar, priority varchar,
  status varchar, created_at timestamptz, created_by varchar,
  created_by_name varchar, metadata jsonb, task_id uuid,
  task_assignment_id uuid, target_type varchar, target_users jsonb,
  read_count integer, total_recipients integer, is_read boolean,
  read_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    n.id, nr.notification_id, nr.id, n.title, n.message,
    n.title_en, n.title_ar, n.message_en, n.message_ar,
    n.type, n.priority, n.status, n.created_at, n.created_by,
    n.created_by_name, n.metadata, n.task_id, n.task_assignment_id,
    n.target_type, n.target_users, n.read_count, n.total_recipients,
    coalesce(nrs.is_read, false), nrs.read_at
  from public.notification_recipients nr
  join public.notifications n on n.id = nr.notification_id
  left join public.notification_read_states nrs
    on nrs.notification_id = nr.notification_id
   and nrs.user_id = p_user_id::text
  where nr.user_id = p_user_id
    and n.status = 'published'
    and n.deleted_at is null
  order by nr.created_at desc
  offset greatest(coalesce(p_offset, 0), 0)
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

grant execute on function public.get_user_notification_feed(uuid, integer, integer)
  to anon, authenticated, service_role;

commit;
