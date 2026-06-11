CREATE OR REPLACE FUNCTION public.get_vendor_management_list(
  p_branch_id bigint DEFAULT NULL,
  p_mode text DEFAULT 'all',
  p_search text DEFAULT NULL
)
RETURNS TABLE (
  erp_vendor_id integer,
  vendor_name text,
  branch_id bigint,
  salesman_name text,
  salesman_contact text,
  supervisor_name text,
  supervisor_contact text,
  vendor_contact_number text,
  payment_method text,
  payment_priority text,
  credit_period integer,
  bank_name text,
  iban text,
  place text,
  location_link text,
  categories text[],
  delivery_modes text[],
  status text,
  last_visit timestamp without time zone,
  return_expired_products text,
  return_near_expiry_products text,
  return_over_stock text,
  return_damage_products text,
  no_return boolean,
  vat_applicable text,
  vat_number text,
  no_vat_note text,
  branch_name_en text,
  branch_name_ar text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH filtered_vendors AS (
    SELECT v.*
    FROM public.vendors v
    LEFT JOIN public.branches b ON b.id = v.branch_id
    WHERE
      (
        p_mode IS NULL
        OR p_mode = 'all'
        OR (p_mode = 'branch' AND p_branch_id IS NOT NULL AND v.branch_id = p_branch_id)
        OR (p_mode = 'unassigned' AND v.branch_id IS NULL)
      )
      AND (
        p_search IS NULL
        OR trim(p_search) = ''
        OR v.vendor_name ILIKE '%' || trim(p_search) || '%'
        OR v.salesman_name ILIKE '%' || trim(p_search) || '%'
        OR v.vendor_contact_number ILIKE '%' || trim(p_search) || '%'
        OR v.payment_method ILIKE '%' || trim(p_search) || '%'
        OR v.place ILIKE '%' || trim(p_search) || '%'
        OR b.name_en ILIKE '%' || trim(p_search) || '%'
        OR b.name_ar ILIKE '%' || trim(p_search) || '%'
      )
  )
  SELECT
    fv.erp_vendor_id,
    fv.vendor_name,
    fv.branch_id,
    fv.salesman_name,
    fv.salesman_contact,
    fv.supervisor_name,
    fv.supervisor_contact,
    fv.vendor_contact_number,
    fv.payment_method,
    fv.payment_priority,
    fv.credit_period,
    fv.bank_name,
    fv.iban,
    fv.place,
    fv.location_link,
    fv.categories,
    fv.delivery_modes,
    fv.status,
    fv.last_visit,
    fv.return_expired_products,
    fv.return_near_expiry_products,
    fv.return_over_stock,
    fv.return_damage_products,
    fv.no_return,
    fv.vat_applicable,
    fv.vat_number,
    fv.no_vat_note,
    b.name_en AS branch_name_en,
    b.name_ar AS branch_name_ar
  FROM filtered_vendors fv
  LEFT JOIN public.branches b ON b.id = fv.branch_id
  ORDER BY fv.erp_vendor_id ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_vendor_management_list(bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_vendor_management_list(bigint, text, text) TO anon;
