begin;

update public.wa_ai_bot_config c
   set bot_name = 'Aqura Companion',
       bot_name_ar = 'مرافق أكورا',
       updated_at = now()
  from public.wa_internal_account i
 where i.singleton = true
   and c.wa_account_id = i.account_id;

commit;
