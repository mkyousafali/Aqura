begin;

delete from public.button_permissions bp
using public.users u, public.hr_positions p
where bp.user_id = u.id
  and p.id = u.position_id
  and bp.button_code = 'STATEMENTS_MANAGER'
  and lower(trim(p.position_title_en)) = 'branch manager';

commit;
