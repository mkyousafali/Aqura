begin;

create or replace function public."Autotask_set_pr_excel_verified"(
  p_source_table text,
  p_source_record_id text,
  p_verified boolean
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_verifier_user_id uuid;
begin
  if p_source_table not in ('receiving_records', 'pending_receiving_records') then
    raise exception 'Unsupported source table';
  end if;

  if p_verified then
    select u.id
      into v_verifier_user_id
      from public.users u
     where u.id = case
       when coalesce(auth.jwt() -> 'user_metadata' ->> 'aqura_user_id', '')
            ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
         then (auth.jwt() -> 'user_metadata' ->> 'aqura_user_id')::uuid
       else auth.uid()
     end
     limit 1;

    if v_verifier_user_id is null then
      raise exception 'Authenticated session is not linked to an Aqura user';
    end if;
  end if;

  execute format(
    'update public.%I set autotask_pr_excel_verified=$1 where id::text=$2',
    p_source_table
  ) using p_verified, p_source_record_id;

  if p_source_table = 'receiving_records' then
    update public.vendor_payment_schedule
       set pr_excel_verified = p_verified,
           pr_excel_verified_by = case when p_verified then v_verifier_user_id else null end,
           pr_excel_verified_date = case when p_verified then now() else null end
     where receiving_record_id::text = p_source_record_id;
  end if;

  perform public."Autotask_refresh_source"(p_source_table, p_source_record_id);

  return jsonb_build_object('success', true, 'verified', p_verified);
end
$function$;

commit;
