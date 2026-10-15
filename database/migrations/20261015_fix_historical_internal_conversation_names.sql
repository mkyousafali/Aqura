begin;

-- Historical attendance destinations can differ from the employee's current
-- Employee Master number. Resolve their names through the immutable recipient
-- user id stored on the original delivery instead of matching only by phone.
with historical_owner as (
  select distinct on (d.destination_snapshot)
    '+' || regexp_replace(d.destination_snapshot, '[^0-9]', '', 'g') as phone,
    coalesce(nullif(e.name_en, ''), nullif(e.name_ar, '')) as employee_name
  from public.attendance_no_show_deliveries d
  join public.hr_employee_master e on e.user_id = d.recipient_user_id
  where d.channel = 'whatsapp'
    and nullif(regexp_replace(d.destination_snapshot, '[^0-9]', '', 'g'), '') is not null
  order by d.destination_snapshot, d.sent_at desc nulls last, d.created_at desc
)
update public.wa_conversations c
set customer_name = h.employee_name
from public.wa_internal_account ia, historical_owner h
where ia.singleton
  and c.wa_account_id = ia.account_id
  and c.customer_phone = h.phone
  and h.employee_name is not null;

commit;
