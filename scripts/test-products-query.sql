-- Test basic products query to debug the 400 error
-- This mimics what the frontend is trying to do

-- Test 1: Simple select without any filters
SELECT id, product_name_en FROM products LIMIT 5;

-- Test 2: Select with is_active filter
SELECT id, product_name_en FROM products WHERE is_active = true LIMIT 5;

-- Test 3: Select the exact columns the offer windows are using
SELECT 
  id, product_name_ar, product_name_en, barcode, 
  sale_price, cost, unit_name_en, unit_name_ar, unit_qty, 
  image_url, current_stock, minim_qty, minimum_qty_alert
FROM products 
WHERE is_active = true 
LIMIT 5;

-- Test 4: Check if minim_qty and minimum_qty_alert columns are accessible
SELECT 
  id, minim_qty, minimum_qty_alert
FROM products 
WHERE is_active = true 
LIMIT 5;
