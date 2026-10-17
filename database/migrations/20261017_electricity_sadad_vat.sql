begin;

alter table public.electricity_sadad_accounts
  add column if not exists vat_applicable boolean not null default false;

create or replace function public.get_electricity_sadad_configuration()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  return jsonb_build_object(
    'posting_accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'branch_id', p.branch_id,
        'branch_name', coalesce(b.name_en, b.name_ar, 'Branch ' || p.branch_id),
        'branch_location', coalesce(b.location_en, b.location_ar, ''),
        'ledger_id', p.ledger_id,
        'ledger_code', p.ledger_code,
        'ledger_name', p.ledger_name
      ) order by b.name_en nulls last, b.name_ar nulls last)
      from public.electricity_sadad_posting_accounts p
      join public.branches b on b.id = p.branch_id
    ), '[]'::jsonb),
    'electricity_accounts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'electricity_account_number', a.electricity_account_number,
        'branch_id', a.branch_id,
        'branch_name', coalesce(b.name_en, b.name_ar, 'Branch ' || a.branch_id),
        'branch_location', coalesce(b.location_en, b.location_ar, ''),
        'vat_applicable', a.vat_applicable
      ) order by a.electricity_account_number)
      from public.electricity_sadad_accounts a
      join public.branches b on b.id = a.branch_id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.set_electricity_sadad_vat_applicable(
  p_id uuid,
  p_vat_applicable boolean
) returns void language plpgsql security definer set search_path = public as $$
declare v_actor uuid := public.aqura_current_user_id();
begin
  if not public.statements_manager_can_access(v_actor) then
    raise exception 'Statements Manager permission required.';
  end if;
  update public.electricity_sadad_accounts
  set vat_applicable = coalesce(p_vat_applicable, false), updated_by = v_actor, updated_at = now()
  where id = p_id;
  if not found then
    raise exception 'Electricity account mapping was not found.';
  end if;
end;
$$;

revoke all on function public.set_electricity_sadad_vat_applicable(uuid,boolean) from public, anon;
grant execute on function public.set_electricity_sadad_vat_applicable(uuid,boolean) to authenticated;

commit;
