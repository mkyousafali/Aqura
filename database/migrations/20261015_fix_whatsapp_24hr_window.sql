begin;

-- Meta's customer-service window is opened only by an inbound message. Outbound
-- notifications update last_message_at, so that column cannot determine access.
create or replace function public.get_wa_conversations_fast(
  p_account_id uuid,
  p_limit integer default 50,
  p_offset integer default 0,
  p_search text default null,
  p_filter text default 'all'
)
returns table (
  id uuid, customer_phone character varying, customer_name text,
  last_message_at timestamp with time zone, last_message_preview text,
  unread_count integer, is_bot_handling boolean, bot_type character varying,
  handled_by character varying, needs_human boolean, status character varying,
  is_inside_24hr boolean, is_sos boolean, total_count bigint
)
language plpgsql stable
as $$
begin
  return query
  select
    c.id, c.customer_phone, c.customer_name, c.last_message_at,
    c.last_message_preview, c.unread_count, c.is_bot_handling, c.bot_type,
    c.handled_by, c.needs_human, c.status,
    coalesce(c.window_expires_at > now(), false),
    c.is_sos, count(*) over()
  from public.wa_conversations c
  where c.wa_account_id = p_account_id
    and c.status = 'active'
    and c.is_sos is not true
    and c.needs_human is not true
    and (
      p_search is null or p_search = ''
      or c.customer_name ilike '%' || p_search || '%'
      or c.customer_phone ilike '%' || p_search || '%'
    )
    and (
      p_filter = 'all'
      or (p_filter = 'unread' and c.unread_count > 0)
      or (p_filter = 'ai' and c.is_bot_handling = true and c.bot_type = 'ai')
      or (p_filter = 'bot' and c.is_bot_handling = true and c.bot_type = 'auto_reply')
      or (p_filter = 'human' and c.is_bot_handling = false)
    )
  order by c.last_message_at desc nulls last
  limit p_limit offset p_offset;
end;
$$;

create or replace function public.get_wa_priority_conversations(p_account_id uuid)
returns table (
  id uuid, customer_phone character varying, customer_name text,
  last_message_at timestamp with time zone, last_message_preview text,
  unread_count integer, is_bot_handling boolean, bot_type character varying,
  handled_by character varying, needs_human boolean, status character varying,
  is_inside_24hr boolean, is_sos boolean, total_count bigint
)
language plpgsql stable
as $$
begin
  return query
  select
    c.id, c.customer_phone, c.customer_name, c.last_message_at,
    c.last_message_preview, c.unread_count, c.is_bot_handling, c.bot_type,
    c.handled_by, c.needs_human, c.status,
    coalesce(c.window_expires_at > now(), false),
    c.is_sos, count(*) over()
  from public.wa_conversations c
  where c.wa_account_id = p_account_id
    and c.status = 'active'
    and (c.is_sos = true or c.needs_human = true)
  order by case when c.is_sos = true then 0 else 1 end, c.last_message_at desc nulls last;
end;
$$;

commit;
