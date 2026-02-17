-- RPC: get_all_products_master
-- Loads all products with unit and category joins in a single fast query
-- Replaces the chunked loading loop (multiple HTTP requests)

CREATE OR REPLACE FUNCTION get_all_products_master()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'barcode', p.barcode,
      'product_name_en', p.product_name_en,
      'product_name_ar', p.product_name_ar,
      'image_url', p.image_url,
      'unit_name', COALESCE(u.name_en, ''),
      'unit_name_ar', COALESCE(u.name_ar, ''),
      'parent_category', COALESCE(c.name_en, ''),
      'parent_category_ar', COALESCE(c.name_ar, '')
    )
    ORDER BY (CASE WHEN p.image_url IS NOT NULL AND p.image_url <> '' THEN 0 ELSE 1 END), p.product_name_en
  ), '[]'::jsonb) INTO v_result
  FROM products p
  LEFT JOIN product_units u ON p.unit_id = u.id
  LEFT JOIN product_categories c ON p.category_id = c.id;
  
  RETURN v_result;
END;
$$;

-- Grant access
GRANT EXECUTE ON FUNCTION get_all_products_master() TO anon, authenticated, service_role;
