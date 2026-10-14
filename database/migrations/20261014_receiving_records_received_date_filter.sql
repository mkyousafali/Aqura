begin;

drop function if exists public.get_receiving_records_with_details(
  integer, integer, text, text, text, text, text, date, date, text
);

create function public.get_receiving_records_with_details(
  p_limit integer default 500,
  p_offset integer default 0,
  p_branch_id text default null,
  p_vendor_search text default null,
  p_pr_excel_filter text default null,
  p_erp_ref_filter text default null,
  p_erp_reference_search text default null,
  p_bill_date_from date default null,
  p_bill_date_to date default null,
  p_erp_check_status_filter text default null,
  p_received_date_from date default null,
  p_received_date_to date default null
) returns table(
  id text, bill_number text, vendor_id text, branch_id text, bill_date date,
  bill_amount numeric, created_at timestamptz, user_id text,
  original_bill_url text, erp_purchase_invoice_reference text,
  certificate_url text, due_date date, pr_excel_file_url text,
  final_bill_amount numeric, payment_method text, credit_period integer,
  bank_name text, iban text, branch_name_en text, branch_name_ar text,
  branch_location_en text, branch_location_ar text, vendor_name text,
  vat_number text, username text, user_display_name text,
  user_display_name_en text, user_display_name_ar text, is_scheduled boolean,
  is_paid boolean, pr_excel_verified boolean, pr_excel_verified_by text,
  pr_excel_verified_date timestamptz, erp_check_result jsonb,
  original_bill_check_result jsonb, total_count bigint
)
language plpgsql stable
as $$
declare
  v_total bigint;
begin
  select count(*) into v_total
  from public.receiving_records r
  left join public.vendors v on v.erp_vendor_id = r.vendor_id and v.branch_id = r.branch_id
  left join lateral (
    select vps.pr_excel_verified
    from public.vendor_payment_schedule vps
    where vps.receiving_record_id = r.id
    limit 1
  ) ps_count on true
  where (p_branch_id is null or r.branch_id::text = p_branch_id)
    and (p_vendor_search is null or p_vendor_search = '' or v.vendor_name ilike '%' || p_vendor_search || '%')
    and (p_pr_excel_filter is null or p_pr_excel_filter = ''
      or (p_pr_excel_filter = 'verified' and coalesce(ps_count.pr_excel_verified, false))
      or (p_pr_excel_filter = 'unverified' and not coalesce(ps_count.pr_excel_verified, false)))
    and (p_erp_ref_filter is null or p_erp_ref_filter = ''
      or (p_erp_ref_filter = 'entered' and nullif(trim(r.erp_purchase_invoice_reference::text), '') is not null)
      or (p_erp_ref_filter = 'not_entered' and nullif(trim(r.erp_purchase_invoice_reference::text), '') is null))
    and (p_erp_reference_search is null or p_erp_reference_search = ''
      or r.erp_purchase_invoice_reference::text ilike '%' || p_erp_reference_search || '%')
    and (p_bill_date_from is null or r.bill_date >= p_bill_date_from)
    and (p_bill_date_to is null or r.bill_date <= p_bill_date_to)
    and (p_received_date_from is null
      or r.created_at >= (p_received_date_from::timestamp at time zone 'Asia/Riyadh'))
    and (p_received_date_to is null
      or r.created_at < ((p_received_date_to + 1)::timestamp at time zone 'Asia/Riyadh'))
    and (p_erp_check_status_filter is null or p_erp_check_status_filter = ''
      or (p_erp_check_status_filter = 'issues' and (
        r.original_bill_check_result->>'status' = 'mismatch'
        or r.erp_check_result->>'status' in ('mismatch', 'not_found')
      ))
      or (p_erp_check_status_filter <> 'issues'
        and r.erp_check_result->>'status' = p_erp_check_status_filter));

  return query
  select r.id::text, r.bill_number::text, r.vendor_id::text, r.branch_id::text,
    r.bill_date, r.bill_amount, r.created_at, r.user_id::text,
    r.original_bill_url::text, r.erp_purchase_invoice_reference::text,
    r.certificate_url::text, r.due_date, r.pr_excel_file_url::text,
    r.final_bill_amount, r.payment_method::text, r.credit_period,
    r.bank_name::text, r.iban::text,
    coalesce(b.name_en, 'N/A')::text, coalesce(b.name_ar, b.name_en, 'N/A')::text,
    coalesce(b.location_en, '')::text, coalesce(b.location_ar, b.location_en, '')::text,
    coalesce(v.vendor_name, 'N/A')::text, v.vat_number::text,
    coalesce(u.username, '')::text,
    coalesce(he.name_en, he.name_ar, u.username, '')::text,
    coalesce(he.name_en, '')::text, coalesce(he.name_ar, '')::text,
    (ps.receiving_record_id is not null), coalesce(ps.is_paid, false),
    coalesce(ps.pr_excel_verified, false), ps.pr_excel_verified_by::text,
    ps.pr_excel_verified_date, r.erp_check_result, r.original_bill_check_result, v_total
  from public.receiving_records r
  left join public.branches b on b.id = r.branch_id
  left join public.vendors v on v.erp_vendor_id = r.vendor_id and v.branch_id = r.branch_id
  left join public.users u on u.id = r.user_id
  left join public.hr_employee_master he on he.user_id = r.user_id
  left join lateral (
    select vps.receiving_record_id, vps.is_paid, vps.pr_excel_verified,
      vps.pr_excel_verified_by, vps.pr_excel_verified_date
    from public.vendor_payment_schedule vps
    where vps.receiving_record_id = r.id
    limit 1
  ) ps on true
  where (p_branch_id is null or r.branch_id::text = p_branch_id)
    and (p_vendor_search is null or p_vendor_search = '' or v.vendor_name ilike '%' || p_vendor_search || '%')
    and (p_pr_excel_filter is null or p_pr_excel_filter = ''
      or (p_pr_excel_filter = 'verified' and coalesce(ps.pr_excel_verified, false))
      or (p_pr_excel_filter = 'unverified' and not coalesce(ps.pr_excel_verified, false)))
    and (p_erp_ref_filter is null or p_erp_ref_filter = ''
      or (p_erp_ref_filter = 'entered' and nullif(trim(r.erp_purchase_invoice_reference::text), '') is not null)
      or (p_erp_ref_filter = 'not_entered' and nullif(trim(r.erp_purchase_invoice_reference::text), '') is null))
    and (p_erp_reference_search is null or p_erp_reference_search = ''
      or r.erp_purchase_invoice_reference::text ilike '%' || p_erp_reference_search || '%')
    and (p_bill_date_from is null or r.bill_date >= p_bill_date_from)
    and (p_bill_date_to is null or r.bill_date <= p_bill_date_to)
    and (p_received_date_from is null
      or r.created_at >= (p_received_date_from::timestamp at time zone 'Asia/Riyadh'))
    and (p_received_date_to is null
      or r.created_at < ((p_received_date_to + 1)::timestamp at time zone 'Asia/Riyadh'))
    and (p_erp_check_status_filter is null or p_erp_check_status_filter = ''
      or (p_erp_check_status_filter = 'issues' and (
        r.original_bill_check_result->>'status' = 'mismatch'
        or r.erp_check_result->>'status' in ('mismatch', 'not_found')
      ))
      or (p_erp_check_status_filter <> 'issues'
        and r.erp_check_result->>'status' = p_erp_check_status_filter))
  order by r.created_at desc
  limit p_limit offset p_offset;
end;
$$;

grant execute on function public.get_receiving_records_with_details(
  integer, integer, text, text, text, text, text, date, date, text, date, date
) to anon, authenticated, service_role;

notify pgrst, 'reload schema';

commit;
