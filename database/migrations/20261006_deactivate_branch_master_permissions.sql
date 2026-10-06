begin;

update public.button_permissions
set is_enabled = false
where button_code in ('BRANCHES', 'BRANCH_MASTER')
  and is_enabled is distinct from false;

commit;
