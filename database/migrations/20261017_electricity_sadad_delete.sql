begin;

create or replace function public.delete_electricity_sadad_account(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  delete from public.electricity_sadad_accounts where id = p_id;
  if not found then
    raise exception 'Electricity account mapping was not found.';
  end if;
end;
$$;

revoke all on function public.delete_electricity_sadad_account(uuid) from public, anon;
grant execute on function public.delete_electricity_sadad_account(uuid) to authenticated;

commit;
