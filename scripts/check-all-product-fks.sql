-- Check all tables and columns that reference products.id
-- Purpose: Identify all foreign keys that need the product_id type conversion

SELECT 
    tc.table_name,
    kcu.column_name,
    ccu.column_name as referenced_column,
    c.data_type
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.columns AS c
    ON c.table_name = tc.table_name 
    AND c.column_name = kcu.column_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'products'
    AND ccu.column_name = 'id'
ORDER BY tc.table_name;
