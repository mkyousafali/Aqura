-- Check if minim_qty and minimum_qty_alert columns exist in products table
DO $$
DECLARE
    col_count INTEGER := 0;
BEGIN
    SELECT COUNT(*) INTO col_count FROM information_schema.columns 
    WHERE table_name = 'products' 
    AND column_name IN ('minim_qty', 'minimum_qty_alert');
    
    IF col_count = 0 THEN
        RAISE NOTICE 'Column check: minim_qty and minimum_qty_alert do NOT exist in products table';
        RAISE NOTICE 'These columns only exist in flyer_products table';
    ELSIF col_count = 1 THEN
        RAISE NOTICE 'Only 1 of 2 columns exists - inconsistent';
    ELSE
        RAISE NOTICE 'Both columns exist in products table';
    END IF;
END $$;

-- Show what columns exist in products table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'products'
ORDER BY ordinal_position;
