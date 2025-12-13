-- Check the exact offer we just created with its dates

SELECT 
    id,
    name_en,
    name_ar,
    type,
    is_active,
    start_date,
    end_date,
    branch_id,
    service_type,
    show_on_product_page,
    NOW() as current_utc_time,
    start_date <= NOW() as start_date_ok,
    end_date >= NOW() as end_date_ok,
    (start_date <= NOW() AND end_date >= NOW()) as should_display
FROM offers
WHERE name_en = 'offer test' OR name_ar LIKE '%test%'
ORDER BY created_at DESC;

-- Also check the offer_products
SELECT 
    COUNT(*) as total_products,
    offer_id
FROM offer_products
WHERE offer_id IN (
    SELECT id FROM offers WHERE name_en = 'offer test' OR name_ar LIKE '%test%'
)
GROUP BY offer_id;
