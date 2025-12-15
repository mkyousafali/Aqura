-- Check the most recent order (ORD-20251215-0003) to see if it has items
SELECT 
  o.order_number,
  o.id,
  COUNT(oi.id) as item_count
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE o.order_number = 'ORD-20251215-0003'
GROUP BY o.order_number, o.id;

-- Get any items for this order
SELECT 
  oi.id,
  oi.product_id,
  oi.product_name_en,
  oi.item_type,
  oi.is_bundle_item
FROM order_items oi
WHERE oi.order_id = (SELECT id FROM orders WHERE order_number = 'ORD-20251215-0003');
