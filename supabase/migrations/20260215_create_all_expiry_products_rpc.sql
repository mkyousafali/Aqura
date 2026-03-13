-- ============================================================
-- Materialized View: Cache the expensive JSONB unnesting
-- Refresh this after ERP sync to keep data fresh
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS mv_expiry_products;

CREATE MATERIALIZED VIEW mv_expiry_products AS
SELECT
  (entry->>'branch_id')::integer AS branch_id,
  p.barcode,
  p.product_name_en,
  p.product_name_ar,
  (entry->>'expiry_date')::date AS expiry_date,
  ((entry->>'expiry_date')::date - CURRENT_DATE) AS days_left,
  p.managed_by,
  p.expiry_hidden
FROM erp_synced_products p,
  jsonb_array_elements(p.expiry_dates) AS entry
WHERE jsonb_array_length(p.expiry_dates) > 0
  AND (entry->>'expiry_date') IS NOT NULL
  AND (entry->>'branch_id') IS NOT NULL;

-- Indexes for fast queries
CREATE INDEX idx_mv_expiry_branch ON mv_expiry_products (branch_id);
CREATE INDEX idx_mv_expiry_barcode ON mv_expiry_products (barcode);
CREATE INDEX idx_mv_expiry_days ON mv_expiry_products (days_left);
CREATE INDEX idx_mv_expiry_hidden ON mv_expiry_products (expiry_hidden);

-- ============================================================
-- Helper: Refresh the materialized view (call after ERP sync)
-- ============================================================
CREATE OR REPLACE FUNCTION refresh_expiry_cache()
RETURNS void
LANGUAGE sql
AS $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_expiry_products;
$$;

-- Need unique index for CONCURRENTLY refresh
CREATE UNIQUE INDEX idx_mv_expiry_unique ON mv_expiry_products (barcode, branch_id, expiry_date);

-- ============================================================
-- RPC: Paginated + server-side search (reads from cached view)
-- ============================================================

CREATE OR REPLACE FUNCTION get_all_expiry_products(
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 1000,
  p_search_barcode text DEFAULT NULL,
  p_search_name text DEFAULT NULL,
  p_branch_id integer DEFAULT NULL
)
RETURNS TABLE (
  branch_id integer,
  barcode varchar(50),
  product_name_en varchar(500),
  product_name_ar varchar(500),
  expiry_date date,
  days_left integer,
  managed_by jsonb,
  total_count bigint
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_offset integer;
  v_limit integer;
BEGIN
  v_offset := CASE WHEN (p_search_barcode IS NOT NULL OR p_search_name IS NOT NULL) THEN 0 ELSE (p_page - 1) * p_page_size END;
  v_limit := CASE WHEN (p_search_barcode IS NOT NULL OR p_search_name IS NOT NULL) THEN NULL ELSE p_page_size END;

  RETURN QUERY
  SELECT
    (entry->>'branch_id')::integer AS branch_id,
    p.barcode,
    p.product_name_en,
    p.product_name_ar,
    (entry->>'expiry_date')::date AS expiry_date,
    ((entry->>'expiry_date')::date - CURRENT_DATE)::integer AS days_left,
    p.managed_by,
    count(*) OVER() AS total_count
  FROM erp_synced_products p,
    jsonb_array_elements(p.expiry_dates) AS entry
  WHERE p.expiry_hidden IS NOT TRUE
    AND jsonb_array_length(p.expiry_dates) > 0
    AND (entry->>'expiry_date') IS NOT NULL
    AND (entry->>'branch_id') IS NOT NULL
    AND (p_branch_id IS NULL OR (entry->>'branch_id')::integer = p_branch_id)
    AND (p_search_barcode IS NULL OR p.barcode ILIKE '%' || p_search_barcode || '%')
    AND (p_search_name IS NULL OR p.product_name_en ILIKE '%' || p_search_name || '%' OR p.product_name_ar ILIKE '%' || p_search_name || '%')
  ORDER BY ((entry->>'expiry_date')::date - CURRENT_DATE) ASC, p.barcode
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;
