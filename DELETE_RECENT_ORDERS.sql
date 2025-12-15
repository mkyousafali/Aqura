-- Delete recent orders and their items to start fresh
-- Delete order items first (foreign key constraint)
DELETE FROM order_items 
WHERE order_id IN (
  SELECT id FROM orders 
  WHERE order_number IN ('ORD-20251215-0001', 'ORD-20251215-0002', 'ORD-20251215-0003', 
                          'ORD-20251215-0007', 'ORD-20251215-0008', 'ORD-20251215-0009',
                          'ORD-20251215-0010', 'ORD-20251215-0012', 'ORD-20251215-0013')
);

-- Delete the orders themselves
DELETE FROM orders 
WHERE order_number IN ('ORD-20251215-0001', 'ORD-20251215-0002', 'ORD-20251215-0003',
                       'ORD-20251215-0007', 'ORD-20251215-0008', 'ORD-20251215-0009',
                       'ORD-20251215-0010', 'ORD-20251215-0012', 'ORD-20251215-0013');

-- Verify they're deleted
SELECT COUNT(*) as remaining_orders FROM orders WHERE order_number LIKE 'ORD-20251215-%';
