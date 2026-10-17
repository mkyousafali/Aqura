begin;
alter table public.telecom_sadad_subscribers add column if not exists vat_applicable boolean not null default false;

create or replace function public.set_telecom_sadad_vat_applicable(p_id uuid,p_vat_applicable boolean) returns void language plpgsql security definer set search_path=public as $$
declare v_actor uuid:=public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then raise exception 'Statements Manager permission required.'; end if;
  update public.telecom_sadad_subscribers set vat_applicable=coalesce(p_vat_applicable,false),updated_at=now() where id=p_id;
  if not found then raise exception 'Telecom subscriber mapping was not found.'; end if;
end $$;

revoke all on function public.set_telecom_sadad_vat_applicable(uuid,boolean) from public,anon;
grant execute on function public.set_telecom_sadad_vat_applicable(uuid,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
