-- Create RPC function to insert order items
CREATE OR REPLACE FUNCTION insert_order_items(
  p_order_items jsonb
)
RETURNS TABLE(success boolean, message text) AS $$
BEGIN
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
    (item->>'offer_id')::integer,
    item->>'item_type',
    (item->>'is_bundle_item')::boolean,
    (item->>'is_bogo_free')::boolean
  FROM jsonb_array_elements(p_order_items) AS item;
  
  RETURN QUERY SELECT true, 'Order items inserted successfully'::text;
EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT false, SQLERRM::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION insert_order_items(jsonb) TO authenticated;
