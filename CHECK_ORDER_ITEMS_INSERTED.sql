-- Check if order items were inserted for the recent order
SELECT 
  oi.id,
  oi.order_id,
  oi.product_id,
  oi.product_name_en,
  oi.product_name_ar,
  oi.quantity,
  oi.unit_price,
  oi.line_total,
  oi.item_type,
  oi.is_bundle_item,
  oi.created_at
FROM order_items oi
WHERE oi.order_id IN (
  SELECT id FROM orders 
  WHERE order_number IN ('ORD-20251215-0013', 'ORD-20251215-0012')
)
ORDER BY oi.created_at DESC;

-- Also check the order totals to verify if they calculated correctly
SELECT 
  id,
  order_number,
  subtotal_amount,
  discount_amount,
  delivery_fee,
  total_amount,
  created_at
FROM orders
WHERE order_number IN ('ORD-20251215-0013', 'ORD-20251215-0012')
ORDER BY created_at DESC;
