begin;

-- Import attendance messages that were successfully sent before attendance
-- notifications started writing to Internal WhatsApp Live Chat.
with internal_account as (
  select account_id from public.wa_internal_account where singleton limit 1
), historical_recipients as (
  select distinct
    ia.account_id,
    '+' || regexp_replace(l.phone_number, '[^0-9]', '', 'g') as phone,
    coalesce(e.name_ar, e.name_en, l.phone_number) as recipient_name
  from public.whatsapp_message_log l
  cross join internal_account ia
  left join public.hr_employee_master e
    on regexp_replace(e.whatsapp_number, '[^0-9]', '', 'g') = regexp_replace(l.phone_number, '[^0-9]', '', 'g')
  where l.message_type in ('attendance_no_show', 'attendance_no_show_test')
    and l.status = 'sent'
    and nullif(regexp_replace(l.phone_number, '[^0-9]', '', 'g'), '') is not null
)
insert into public.wa_conversations (
  wa_account_id, customer_phone, customer_name, status, handled_by,
  is_bot_handling, bot_type, last_message_at, unread_count
)
select account_id, phone, max(recipient_name), 'active', 'bot', true, 'ai', now(), 0
from historical_recipients
group by account_id, phone
on conflict (wa_account_id, customer_phone) do update
set customer_name = coalesce(excluded.customer_name, public.wa_conversations.customer_name);

with internal_account as (
  select account_id from public.wa_internal_account where singleton limit 1
), historical as (
  select
    l.*,
    ia.account_id,
    '+' || regexp_replace(l.phone_number, '[^0-9]', '', 'g') as normalized_phone,
    a.shift_date,
    a.shift_name,
    a.shift_start_at,
    a.shift_end_at,
    coalesce(emp.name_ar, emp.name_en, a.employee_id) as absent_employee
  from public.whatsapp_message_log l
  cross join internal_account ia
  left join public.attendance_no_show_deliveries d
    on d.provider_message_id = l.whatsapp_message_id and d.channel = 'whatsapp'
  left join public.attendance_no_show_alerts a on a.id = d.alert_id
  left join public.hr_employee_master emp on emp.id = a.employee_id
  where l.message_type in ('attendance_no_show', 'attendance_no_show_test')
    and l.status = 'sent'
    and nullif(regexp_replace(l.phone_number, '[^0-9]', '', 'g'), '') is not null
)
insert into public.wa_messages (
  conversation_id, wa_account_id, whatsapp_message_id, direction,
  message_type, content, template_name, template_language, status,
  sent_by, created_at, metadata
)
select
  c.id,
  h.account_id,
  h.whatsapp_message_id,
  'outbound',
  'template',
  case
    when h.message_type = 'attendance_no_show_test' then
      'اختبار إشعار الحضور' || E'\n' ||
      'هذا إشعار تجريبي سابق فقط، ولم تحدث حالة حضور فعلية.'
    when h.shift_date is not null then
      'تنبيه الحضور' || E'\n' ||
      'الموظف: ' || coalesce(h.absent_employee, '—') || E'\n' ||
      'الحالة: لم يحضر للعمل حتى وقت إرسال التنبيه' || E'\n' ||
      'التاريخ: ' || h.shift_date::text || E'\n' ||
      'الوردية: ' || coalesce(to_char(h.shift_start_at at time zone 'Asia/Riyadh', 'HH24:MI'), '—') ||
      ' - ' || coalesce(to_char(h.shift_end_at at time zone 'Asia/Riyadh', 'HH24:MI'), '—') ||
      case when nullif(h.shift_name, '') is not null then ' (' || h.shift_name || ')' else '' end
    else
      'تنبيه حضور سابق'
  end,
  h.template_name,
  h.template_language,
  'sent',
  'system',
  h.created_at,
  jsonb_build_object('backfilled', true, 'source', 'whatsapp_message_log', 'source_id', h.id)
from historical h
join public.wa_conversations c
  on c.wa_account_id = h.account_id and c.customer_phone = h.normalized_phone
where nullif(h.whatsapp_message_id, '') is not null
on conflict (whatsapp_message_id) do nothing;

-- Refresh each affected conversation from its actual newest stored message.
with affected as (
  select distinct c.id
  from public.wa_conversations c
  join public.wa_internal_account ia on ia.account_id = c.wa_account_id and ia.singleton
  join public.wa_messages m on m.conversation_id = c.id
  where m.metadata->>'source' = 'whatsapp_message_log'
), latest as (
  select distinct on (m.conversation_id)
    m.conversation_id, m.created_at, left(coalesce(m.content, ''), 100) as preview
  from public.wa_messages m
  join affected a on a.id = m.conversation_id
  order by m.conversation_id, m.created_at desc
)
update public.wa_conversations c
set last_message_at = l.created_at,
    last_message_preview = l.preview
from latest l
where c.id = l.conversation_id;

commit;
