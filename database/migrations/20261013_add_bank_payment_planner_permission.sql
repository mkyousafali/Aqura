begin;

insert into public.button_permissions (user_id, button_code, is_enabled, updated_at)
select user_id, 'BANK_PAYMENT_PLANNER', is_enabled, now()
from public.button_permissions
where button_code = 'DAY_BUDGET_PLANNER'
on conflict (user_id, button_code) do nothing;

commit;
