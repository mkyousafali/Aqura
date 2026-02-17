-- RPC: get_product_master_init_data
-- Combines 6 sequential HTTP calls into 1 fast RPC call
-- Returns: product counts (total, with images, without images), all units, all categories
-- Used by: ProductMaster.svelte on mount

CREATE OR REPLACE FUNCTION get_product_master_init_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_products int;
  v_with_images int;
  v_without_images int;
  v_units jsonb;
  v_categories jsonb;
BEGIN
  -- Get total products count
  SELECT count(*) INTO v_total_products FROM products;
  
  -- Get products with images count
  SELECT count(*) INTO v_with_images 
  FROM products 
  WHERE image_url IS NOT NULL AND image_url <> '';
  
  -- Get products without images count
  v_without_images := v_total_products - v_with_images;
  
  -- Get all units
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object('id', id, 'name_en', name_en, 'name_ar', name_ar)
    ORDER BY name_en
  ), '[]'::jsonb) INTO v_units
  FROM product_units;
  
  -- Get all categories
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object('id', id, 'name_en', name_en, 'name_ar', name_ar)
    ORDER BY name_en
  ), '[]'::jsonb) INTO v_categories
  FROM product_categories;
  
  RETURN jsonb_build_object(
    'total_products', v_total_products,
    'products_with_images', v_with_images,
    'products_without_images', v_without_images,
    'units', v_units,
    'categories', v_categories
  );
END;
$$;

-- Grant access
GRANT EXECUTE ON FUNCTION get_product_master_init_data() TO anon, authenticated, service_role;
