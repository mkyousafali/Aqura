-- Count ALL order items in the table
SELECT COUNT(*) as total_order_items FROM order_items;

-- Get the most recent order items
SELECT 
  oi.id,
  oi.order_id,
  oi.product_id,
  oi.product_name_en,
  oi.quantity,
  o.order_number,
  o.created_at
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
ORDER BY o.created_at DESC
LIMIT 10;
