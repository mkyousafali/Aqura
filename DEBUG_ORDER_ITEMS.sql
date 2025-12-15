-- Check if order items exist and are accessible
SELECT 
  COUNT(*) as total_items,
  order_id
FROM order_items
WHERE order_id IN (
  SELECT id FROM orders 
  WHERE order_number IN ('ORD-20251215-0013', 'ORD-20251215-0012')
)
GROUP BY order_id;

-- Get detailed view of what's in the database
SELECT 
  oi.id,
  oi.order_id,
  oi.product_id,
  oi.product_name_en,
  oi.quantity,
  oi.unit_price,
  oi.item_type,
  oi.is_bundle_item
FROM order_items oi
WHERE oi.order_id IN (
  SELECT id FROM orders 
  WHERE order_number = 'ORD-20251215-0013'
);
