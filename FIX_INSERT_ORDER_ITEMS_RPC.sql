-- Drop and recreate the RPC function with better error handling
DROP FUNCTION IF EXISTS insert_order_items(jsonb);

CREATE OR REPLACE FUNCTION insert_order_items(
  p_order_items jsonb
)
RETURNS TABLE(success boolean, message text) AS $$
DECLARE
  v_count integer;
  v_error_msg text;
BEGIN
  -- Log input
  RAISE NOTICE 'insert_order_items called with % items', jsonb_array_length(p_order_items);
  
  INSERT INTO order_items (
    order_id,
    product_id,
    product_name_ar,
    product_name_en,
    quantity,
    unit_price,
    original_price,
    discount_amount,
    final_price,
    line_total,
    has_offer,
    offer_id,
    item_type,
    is_bundle_item,
    is_bogo_free
  )
  SELECT
    (item->>'order_id')::uuid,
    item->>'product_id',
    item->>'product_name_ar',
    item->>'product_name_en',
    (item->>'quantity')::integer,
    (item->>'unit_price')::numeric,
    (item->>'original_price')::numeric,
    (item->>'discount_amount')::numeric,
    (item->>'final_price')::numeric,
    (item->>'line_total')::numeric,
    (item->>'has_offer')::boolean,
    CASE 
      WHEN item->>'offer_id' IS NULL OR item->>'offer_id' = 'null' THEN NULL::integer
      ELSE (item->>'offer_id')::integer
    END,
    item->>'item_type',
    (item->>'is_bundle_item')::boolean,
    (item->>'is_bogo_free')::boolean
  FROM jsonb_array_elements(p_order_items) AS item;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE NOTICE 'Inserted % order items', v_count;
  
  RETURN QUERY SELECT true, format('Order items inserted successfully (%s items)', v_count)::text;
  
EXCEPTION WHEN OTHERS THEN
  GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
  RAISE NOTICE 'Error in insert_order_items: %', v_error_msg;
  RETURN QUERY SELECT false, v_error_msg::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION insert_order_items(jsonb) TO authenticated;
