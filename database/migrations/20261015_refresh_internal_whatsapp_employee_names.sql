begin;

update public.wa_conversations c
set customer_name = coalesce(nullif(e.name_en, ''), nullif(e.name_ar, ''), c.customer_name)
from public.wa_internal_account ia,
     public.hr_employee_master e
where ia.singleton
  and c.wa_account_id = ia.account_id
  and regexp_replace(c.customer_phone, '[^0-9]', '', 'g') =
      regexp_replace(e.whatsapp_number, '[^0-9]', '', 'g');

commit;
