begin;

-- OTP messages must remain available to the service role long enough to send,
-- but their plaintext bodies must never be exposed through the shared mail UI.
create or replace function public.classify_sensitive_email_message()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.source_type in ('otp', 'security_otp')
     or new.subject like 'Aqura - Verification Code%'
     or new.subject like 'Aqura - Box Edit Approval Code%' then
    new.source_type := 'otp';
  end if;
  return new;
end;
$$;

drop trigger if exists classify_sensitive_email_message_trigger on public.email_messages;
create trigger classify_sensitive_email_message_trigger
before insert or update of subject, source_type on public.email_messages
for each row execute function public.classify_sensitive_email_message();

-- Automated senders historically inserted outgoing messages without a folder,
-- which made them visible in All Mail but absent from Sent.
create or replace function public.assign_outgoing_email_to_sent_folder()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.folder_id is null and new.direction in ('outbound', 'outgoing') then
    select id into new.folder_id
    from public.email_folders
    where email_account_id = new.email_account_id
      and folder_type = 'sent'
      and is_active = true
    limit 1;

    if new.folder_id is null then
      insert into public.email_folders (
        email_account_id, remote_folder_name, display_name, folder_type
      ) values (
        new.email_account_id, 'Sent', 'Sent', 'sent'
      ) returning id into new.folder_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists assign_outgoing_email_to_sent_folder_trigger on public.email_messages;
create trigger assign_outgoing_email_to_sent_folder_trigger
before insert or update of email_account_id, direction, folder_id on public.email_messages
for each row execute function public.assign_outgoing_email_to_sent_folder();

-- Protect OTP messages that were created before the classifier existed.
update public.email_messages
set source_type = 'otp'
where source_type in ('otp', 'security_otp')
   or subject like 'Aqura - Verification Code%'
   or subject like 'Aqura - Box Edit Approval Code%';

-- Backfill existing outgoing messages that were never assigned to Sent.
update public.email_messages em
set folder_id = (
  select ef.id
  from public.email_folders ef
  where ef.email_account_id = em.email_account_id
    and ef.folder_type = 'sent'
    and ef.is_active = true
  limit 1
)
where em.folder_id is null
  and em.direction in ('outbound', 'outgoing');

-- Direct table reads must not bypass the Mail Center RPC filtering.
revoke select on table public.email_messages from anon;
drop policy if exists email_messages_read on public.email_messages;
create policy email_messages_read
on public.email_messages
for select
to authenticated
using (source_type is distinct from 'otp');

-- OTP verification tables are internal implementation details. Even hashed
-- six-digit values must not be downloadable by browser roles.
revoke select on table public.email_otp_requests from anon, authenticated;
revoke select on table public.complete_box_edit_otp_requests from anon, authenticated;
drop policy if exists "Allow all access to complete_box_edit_otp_requests"
  on public.complete_box_edit_otp_requests;

create or replace function public.get_email_message(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.email_messages
  set is_read = true
  where id = p_message_id
    and is_read = false
    and source_type is distinct from 'otp';

  return (
    select jsonb_build_object(
      'message', row_to_json(em)::jsonb,
      'recipients', (select coalesce(jsonb_agg(row_to_json(r)::jsonb), '[]'::jsonb)
                     from public.email_message_recipients r where r.email_message_id = em.id),
      'attachments', (select coalesce(jsonb_agg(row_to_json(a)::jsonb), '[]'::jsonb)
                     from public.email_attachments a where a.email_message_id = em.id)
    )
    from public.email_messages em
    where em.id = p_message_id
      and em.source_type is distinct from 'otp'
  );
end;
$$;

create or replace function public.get_email_folders(p_account_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return (
    select coalesce(jsonb_agg(row_to_json(f)::jsonb), '[]'::jsonb)
    from (
      select ef.*,
        case
          when ef.folder_type = 'trash' then (
            select count(*)
            from public.email_messages em
            where em.folder_id = ef.id
              and em.is_deleted = true
              and em.source_type is distinct from 'otp'
          )
          else (
            select count(*)
            from public.email_messages em
            where em.folder_id = ef.id
              and em.direction = 'inbound'
              and em.is_read = false
              and em.is_deleted = false
              and em.source_type is distinct from 'otp'
          )
        end as unread_count
      from public.email_folders ef
      where ef.email_account_id = p_account_id
        and ef.is_active = true
      order by case ef.folder_type
        when 'inbox' then 1
        when 'sent' then 2
        when 'drafts' then 3
        when 'trash' then 4
        when 'spam' then 5
        when 'archive' then 6
        else 7
      end, ef.display_name
    ) f
  );
end;
$$;

create or replace function public.get_email_thread_messages(p_thread_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.email_messages
  set is_read = true
  where thread_id = p_thread_id
    and is_read = false
    and source_type is distinct from 'otp';

  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'message', row_to_json(em)::jsonb,
      'recipients', (select coalesce(jsonb_agg(row_to_json(r)::jsonb), '[]'::jsonb)
                     from public.email_message_recipients r where r.email_message_id = em.id)
    ) order by coalesce(em.received_at, em.sent_at, em.created_at) asc), '[]'::jsonb)
    from public.email_messages em
    where em.thread_id = p_thread_id
      and em.is_deleted = false
      and em.source_type is distinct from 'otp'
  );
end;
$$;

create or replace function public.get_email_messages(
  p_account_id uuid,
  p_folder_id uuid default null,
  p_search text default null,
  p_is_read boolean default null,
  p_is_starred boolean default null,
  p_page integer default 1,
  p_page_size integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offset integer;
  v_total integer;
begin
  v_offset := (p_page - 1) * p_page_size;

  select count(*) into v_total
  from public.email_messages em
  where em.email_account_id = p_account_id
    and em.source_type is distinct from 'otp'
    and em.is_deleted = false
    and (p_folder_id is null or em.folder_id = p_folder_id)
    and (p_is_read is null or em.is_read = p_is_read)
    and (p_is_starred is null or em.is_starred = p_is_starred)
    and (p_search is null or em.subject ilike '%' || p_search || '%'
         or em.from_address ilike '%' || p_search || '%'
         or em.body_preview ilike '%' || p_search || '%');

  return jsonb_build_object(
    'total', v_total,
    'page', p_page,
    'page_size', p_page_size,
    'messages', (
      select coalesce(jsonb_agg(row_to_json(m)::jsonb), '[]'::jsonb)
      from (
        select em.id, em.folder_id, em.thread_id, em.direction, em.status, em.subject,
               em.from_name, em.from_address, em.body_preview, em.sent_at, em.received_at,
               em.is_read, em.is_starred, em.is_flagged, em.is_draft, em.priority,
               em.has_attachments, em.source_type,
               (select count(*) from public.email_message_recipients r
                where r.email_message_id = em.id) as recipient_count
        from public.email_messages em
        where em.email_account_id = p_account_id
          and em.source_type is distinct from 'otp'
          and em.is_deleted = false
          and (p_folder_id is null or em.folder_id = p_folder_id)
          and (p_is_read is null or em.is_read = p_is_read)
          and (p_is_starred is null or em.is_starred = p_is_starred)
          and (p_search is null or em.subject ilike '%' || p_search || '%'
               or em.from_address ilike '%' || p_search || '%'
               or em.body_preview ilike '%' || p_search || '%')
        order by coalesce(em.received_at, em.sent_at, em.created_at) desc
        limit p_page_size offset v_offset
      ) m
    )
  );
end;
$$;

create or replace function public.get_email_messages_threaded(
  p_account_id uuid,
  p_folder_id uuid default null,
  p_search text default null,
  p_page integer default 1,
  p_page_size integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offset integer;
  v_total integer;
  v_is_trash boolean := false;
begin
  v_offset := (p_page - 1) * p_page_size;

  if p_folder_id is not null then
    select (folder_type = 'trash') into v_is_trash
    from public.email_folders where id = p_folder_id;
  end if;

  select count(distinct coalesce(em.thread_id, em.id)) into v_total
  from public.email_messages em
  where em.email_account_id = p_account_id
    and em.source_type is distinct from 'otp'
    and (case when v_is_trash then em.is_deleted = true else em.is_deleted = false end)
    and (p_folder_id is null or em.folder_id = p_folder_id)
    and (p_search is null or em.subject ilike '%' || p_search || '%'
         or em.from_address ilike '%' || p_search || '%');

  return jsonb_build_object(
    'total', v_total,
    'page', p_page,
    'page_size', p_page_size,
    'is_trash', v_is_trash,
    'threads', (
      select coalesce(jsonb_agg(t order by t.latest_at desc), '[]'::jsonb)
      from (
        select distinct on (coalesce(em.thread_id, em.id))
          coalesce(em.thread_id, em.id) as thread_id,
          em.id as latest_message_id,
          em.subject,
          em.from_name,
          em.from_address,
          em.body_preview,
          em.is_read,
          em.is_starred,
          em.has_attachments,
          em.direction,
          (select r.email_address
           from public.email_message_recipients r
           where r.email_message_id = em.id and r.recipient_type = 'to'
           order by r.created_at asc
           limit 1) as to_address,
          coalesce(em.received_at, em.sent_at, em.created_at) as latest_at,
          (select count(*) from public.email_messages m2
           where m2.thread_id = em.thread_id and m2.thread_id is not null
             and m2.source_type is distinct from 'otp') as message_count,
          (select count(*) from public.email_messages m3
           where m3.thread_id = em.thread_id and m3.thread_id is not null
             and m3.is_read = false and m3.source_type is distinct from 'otp') as unread_in_thread
        from public.email_messages em
        where em.email_account_id = p_account_id
          and em.source_type is distinct from 'otp'
          and (case when v_is_trash then em.is_deleted = true else em.is_deleted = false end)
          and (p_folder_id is null or em.folder_id = p_folder_id)
          and (p_search is null or em.subject ilike '%' || p_search || '%'
               or em.from_address ilike '%' || p_search || '%')
        order by coalesce(em.thread_id, em.id),
                 coalesce(em.received_at, em.sent_at, em.created_at) desc
      ) t
      limit p_page_size offset v_offset
    )
  );
end;
$$;

commit;
