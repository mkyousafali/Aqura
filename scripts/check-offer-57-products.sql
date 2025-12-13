-- Check offer_products for offer 57

SELECT 
    op.id,
    op.offer_id,
    op.product_id,
    op.offer_percentage,
    op.offer_price,
    p.id as product_id_check,
    p.product_name_en,
    p.is_active,
    p.is_customer_product
FROM offer_products op
LEFT JOIN products p ON op.product_id = p.id
WHERE op.offer_id = 57;
