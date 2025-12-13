-- Check if product_serial column exists in products table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'products'
AND column_name = 'product_serial'
ORDER BY ordinal_position;

-- If it doesn't exist, check what similar columns do exist
SELECT column_name, data_type
FROM information_schema.columns 
WHERE table_name = 'products'
AND (column_name LIKE '%serial%' OR column_name LIKE '%product%' OR column_name LIKE '%name%')
ORDER BY ordinal_position;
