-- RPC function to quickly find products expiring within N days, grouped by branch
-- Uses server-side JSONB unnesting + filtering so we don't load 200K+ products client-side

CREATE OR REPLACE FUNCTION get_quick_expiry_report(days_threshold integer DEFAULT 15)
RETURNS TABLE (
  branch_id integer,
  barcode varchar(50),
  product_name_en varchar(500),
  product_name_ar varchar(500),
  expiry_date date,
  days_left integer,
  managed_by jsonb
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    (entry->>'branch_id')::integer AS branch_id,
    p.barcode,
    p.product_name_en,
    p.product_name_ar,
    (entry->>'expiry_date')::date AS expiry_date,
    ((entry->>'expiry_date')::date - CURRENT_DATE) AS days_left,
    p.managed_by
  FROM erp_synced_products p,
    jsonb_array_elements(p.expiry_dates) AS entry
  WHERE jsonb_array_length(p.expiry_dates) > 0
    AND (p.expiry_hidden IS NOT TRUE)
    AND (entry->>'expiry_date') IS NOT NULL
    AND (entry->>'branch_id') IS NOT NULL
    AND ((entry->>'expiry_date')::date - CURRENT_DATE) <= days_threshold
  ORDER BY p.barcode, ((entry->>'expiry_date')::date - CURRENT_DATE) ASC;
$$;
