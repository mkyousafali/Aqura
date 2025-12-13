-- Check offers in the database
-- See what offers exist and their date ranges

SELECT 
    id,
    name_en,
    name_ar,
    type,
    is_active,
    start_date,
    end_date,
    NOW() as current_utc_time,
    start_date <= NOW() as start_ok,
    end_date >= NOW() as end_ok,
    (start_date <= NOW() AND end_date >= NOW()) as should_display
FROM offers
WHERE type IN ('product', 'bogo', 'bundle')
ORDER BY created_at DESC
LIMIT 20;

-- Also check offer_products to see if they exist
SELECT 
    op.id,
    op.offer_id,
    op.product_id,
    op.offer_percentage,
    p.product_name_en,
    p.product_name_ar
FROM offer_products op
LEFT JOIN products p ON op.product_id = p.id
ORDER BY op.created_at DESC
LIMIT 10;
