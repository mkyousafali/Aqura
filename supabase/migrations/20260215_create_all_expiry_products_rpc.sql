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
BEGIN
  RETURN QUERY
  SELECT
    m.branch_id,
    m.barcode,
    m.product_name_en,
    m.product_name_ar,
    m.expiry_date,
    m.days_left,
    m.managed_by,
    count(*) OVER() AS total_count
  FROM mv_expiry_products m
  WHERE m.expiry_hidden IS NOT TRUE
    AND (p_branch_id IS NULL OR m.branch_id = p_branch_id)
    AND (p_search_barcode IS NULL OR m.barcode ILIKE '%' || p_search_barcode || '%')
    AND (p_search_name IS NULL OR m.product_name_en ILIKE '%' || p_search_name || '%' OR m.product_name_ar ILIKE '%' || p_search_name || '%')
  ORDER BY m.days_left ASC, m.barcode
  LIMIT CASE WHEN (p_search_barcode IS NOT NULL OR p_search_name IS NOT NULL) THEN NULL ELSE p_page_size END
  OFFSET CASE WHEN (p_search_barcode IS NOT NULL OR p_search_name IS NOT NULL) THEN 0 ELSE (p_page - 1) * p_page_size END;
END;
$$;
