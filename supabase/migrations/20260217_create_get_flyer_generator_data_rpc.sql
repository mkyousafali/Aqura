-- RPC: get_flyer_generator_data
-- Consolidates multiple client-side queries into a single server-side call
-- Returns: offer products with full product details and variation info, all JOINed server-side
-- This replaces 3-4 separate API calls with 1 RPC call for massive speed improvement

CREATE OR REPLACE FUNCTION get_flyer_generator_data(p_offer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  WITH 
  -- Step 1: Get all offer products for this offer
  offer_products AS (
    SELECT 
      fop.id,
      fop.offer_id,
      fop.product_barcode,
      fop.cost,
      fop.sales_price,
      fop.offer_price,
      fop.profit_amount,
      fop.profit_percent,
      fop.profit_after_offer,
      fop.decrease_amount,
      fop.offer_qty,
      fop.limit_qty,
      fop.free_qty,
      fop.created_at,
      fop.page_number,
      fop.page_order,
      fop.total_sales_price,
      fop.total_offer_price
    FROM flyer_offer_products fop
    WHERE fop.offer_id = p_offer_id
  ),
  -- Step 2: Get product details for all barcodes in the offer
  product_details AS (
    SELECT 
      p.barcode,
      p.product_name_en,
      p.product_name_ar,
      p.image_url,
      p.is_variation,
      p.parent_product_barcode,
      p.variation_group_name_en,
      p.variation_group_name_ar,
      p.variation_image_override,
      p.variation_order,
      pu.name_ar AS unit_name_ar,
      pu.name_en AS unit_name_en
    FROM products p
    LEFT JOIN product_units pu ON p.unit_id = pu.id
    WHERE p.barcode IN (SELECT product_barcode FROM offer_products)
  ),
  -- Step 3: Get variation images for all variations in the offer
  -- (grouped by parent_product_barcode)
  variation_images AS (
    SELECT 
      p.parent_product_barcode,
      jsonb_agg(
        jsonb_build_object(
          'barcode', p.barcode,
          'image_url', p.image_url,
          'variation_order', COALESCE(p.variation_order, 0)
        ) ORDER BY COALESCE(p.variation_order, 0)
      ) AS images
    FROM products p
    WHERE p.is_variation = true
      AND p.parent_product_barcode IS NOT NULL
      AND p.barcode IN (SELECT product_barcode FROM offer_products)
    GROUP BY p.parent_product_barcode
  ),
  -- Step 4: Build combined result for each offer product
  combined AS (
    SELECT 
      jsonb_build_object(
        'id', op.id,
        'offer_id', op.offer_id,
        'product_barcode', op.product_barcode,
        'cost', op.cost,
        'sales_price', op.sales_price,
        'offer_price', op.offer_price,
        'profit_amount', op.profit_amount,
        'profit_percent', op.profit_percent,
        'profit_after_offer', op.profit_after_offer,
        'decrease_amount', op.decrease_amount,
        'offer_qty', op.offer_qty,
        'limit_qty', op.limit_qty,
        'free_qty', op.free_qty,
        'created_at', op.created_at,
        'page_number', COALESCE(op.page_number, 1),
        'page_order', COALESCE(op.page_order, 1),
        'total_sales_price', op.total_sales_price,
        'total_offer_price', op.total_offer_price,
        'product_name_en', COALESCE(pd.product_name_en, ''),
        'product_name_ar', COALESCE(pd.product_name_ar, ''),
        'unit_name', COALESCE(pd.unit_name_ar, ''),
        'image_url', COALESCE(pd.image_url, pd.variation_image_override),
        'is_variation', COALESCE(pd.is_variation, false),
        'parent_product_barcode', pd.parent_product_barcode,
        'variation_group_name_en', pd.variation_group_name_en,
        'variation_group_name_ar', pd.variation_group_name_ar,
        'variation_order', pd.variation_order,
        'variation_images', COALESCE(vi.images, '[]'::jsonb)
      ) AS product_data
    FROM offer_products op
    LEFT JOIN product_details pd ON pd.barcode = op.product_barcode
    LEFT JOIN variation_images vi ON vi.parent_product_barcode = op.product_barcode
                                  OR vi.parent_product_barcode = pd.parent_product_barcode
  )
  SELECT jsonb_build_object(
    'products', COALESCE(jsonb_agg(c.product_data), '[]'::jsonb)
  )
  INTO result
  FROM combined c;

  RETURN COALESCE(result, jsonb_build_object('products', '[]'::jsonb));
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_flyer_generator_data(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_flyer_generator_data(uuid) TO anon;
GRANT EXECUTE ON FUNCTION get_flyer_generator_data(uuid) TO service_role;
