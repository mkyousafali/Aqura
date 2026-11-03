begin;

create or replace function public.direct_order_actor(p_interface text)
returns uuid language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v_actor uuid;
begin
  if auth.uid() is null then raise exception 'Signed-in session required' using errcode = '42501'; end if;
  -- Older installations do not have users.auth_user_id. Reading the optional
  -- mapping through JSON supports both schemas without trusting user_metadata.
  select u.id into v_actor from public.users u
  where (to_jsonb(u) ->> 'auth_user_id') = auth.uid()::text or u.id = auth.uid()
    or u.id::text = (auth.jwt() -> 'app_metadata' ->> 'aqura_user_id')
  order by case when (to_jsonb(u) ->> 'auth_user_id') = auth.uid()::text then 0 when u.id = auth.uid() then 1 else 2 end
  limit 1;
  if not public.direct_order_user_allowed(v_actor, p_interface) then
    raise exception 'Direct Order access required' using errcode = '42501';
  end if;
  return v_actor;
end;
$$;

notify pgrst, 'reload schema';
commit;
