-- Validation Script: Compare products and flyer_products table structures
-- Purpose: Ensure both tables have compatible schemas before migration
-- Date: 2024-12-13

-- ============================================
-- PART 1: Get all columns from products table
-- ============================================
SELECT 
  'products' as table_name,
  column_name,
  data_type,
  is_nullable,
  column_default,
  ordinal_position
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'products'
ORDER BY ordinal_position;

-- ============================================
-- PART 2: Get all columns from flyer_products table
-- ============================================
SELECT 
  'flyer_products' as table_name,
  column_name,
  data_type,
  is_nullable,
  column_default,
  ordinal_position
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'flyer_products'
ORDER BY ordinal_position;

-- ============================================
-- PART 3: Find columns in products NOT in flyer_products
-- ============================================
SELECT 
  'Missing in flyer_products' as status,
  p.column_name,
  p.data_type,
  p.is_nullable,
  p.column_default
FROM information_schema.columns p
WHERE p.table_schema = 'public' 
  AND p.table_name = 'products'
  AND NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns fp
    WHERE fp.table_schema = 'public' 
      AND fp.table_name = 'flyer_products'
      AND fp.column_name = p.column_name
  )
ORDER BY p.column_name;

-- ============================================
-- PART 4: Find columns in flyer_products NOT in products
-- ============================================
SELECT 
  'Extra in flyer_products' as status,
  fp.column_name,
  fp.data_type,
  fp.is_nullable,
  fp.column_default
FROM information_schema.columns fp
WHERE fp.table_schema = 'public' 
  AND fp.table_name = 'flyer_products'
  AND NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns p
    WHERE p.table_schema = 'public' 
      AND p.table_name = 'products'
      AND p.column_name = fp.column_name
  )
ORDER BY fp.column_name;

-- ============================================
-- PART 5: Compare data types for matching columns
-- ============================================
SELECT 
  p.column_name,
  p.data_type as products_type,
  fp.data_type as flyer_products_type,
  CASE 
    WHEN p.data_type = fp.data_type THEN 'MATCH'
    ELSE 'MISMATCH'
  END as type_comparison,
  p.is_nullable as products_nullable,
  fp.is_nullable as flyer_nullable
FROM information_schema.columns p
INNER JOIN information_schema.columns fp 
  ON p.column_name = fp.column_name
WHERE p.table_schema = 'public' 
  AND p.table_name = 'products'
  AND fp.table_schema = 'public'
  AND fp.table_name = 'flyer_products'
ORDER BY p.column_name;

-- ============================================
-- PART 6: Summary comparison
-- ============================================
SELECT 
  'products' as table_name,
  COUNT(*) as column_count
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'products'
UNION ALL
SELECT 
  'flyer_products',
  COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'flyer_products';

-- ============================================
-- PART 7: Check indexes on both tables
-- ============================================
SELECT 
  'products' as table_name,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public' 
  AND tablename = 'products'
ORDER BY indexname;

SELECT 
  'flyer_products' as table_name,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public' 
  AND tablename = 'flyer_products'
ORDER BY indexname;

-- ============================================
-- PART 8: Check foreign key constraints
-- ============================================
SELECT 
  tc.table_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name IN ('products', 'flyer_products')
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================
-- EXPECTED RESULTS:
-- ============================================
-- After running 20241212_add_columns_to_flyer_products.sql:
-- 
-- 1. Both tables should have similar column counts
-- 2. flyer_products should have all required columns:
--    - product_serial, sale_price, cost, profit, profit_percentage
--    - current_stock, minim_qty, minimum_qty_alert, maximum_qty
--    - category_id, tax_category_id, tax_percentage
--    - unit_id, unit_qty, unit_name_en, unit_name_ar
--    - is_active
-- 3. Data types should match for common columns
-- 4. Extra columns in flyer_products (variation-related) are OK
-- ============================================
