-- Create RPC function to fetch system expiry dates by barcodes
-- This function avoids long URL issues by processing the query server-side

CREATE OR REPLACE FUNCTION public.get_system_expiry_dates(barcode_list text[], branch_id_param integer)
RETURNS TABLE (barcode text, expiry_date_formatted text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    esp.barcode,
    COALESCE(
      (SELECT TO_CHAR((e->>'expiry_date')::date, 'DD-MM-YYYY')
       FROM jsonb_array_elements(esp.expiry_dates) as e
       WHERE (e->>'branch_id')::integer = branch_id_param
       LIMIT 1),
      '—'
    ) as expiry_date_formatted
  FROM erp_synced_products esp
  WHERE esp.barcode = ANY(barcode_list)
  ORDER BY esp.barcode;
$$;

-- Grant execute permissions to authenticated and anonymous users
GRANT EXECUTE ON FUNCTION public.get_system_expiry_dates(text[], integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_system_expiry_dates(text[], integer) TO anon;
