-- ============================================
-- Sample Offers Data - Based on Real Products
-- ============================================
-- Purpose: Insert realistic sample offers using existing product data
-- Note: Run this AFTER create-offers-schema.sql
-- Product IDs are from actual products table
-- ============================================

-- ============================================
-- 1. Weekend Special - Fresh Fruits & Vegetables (Product Offer - Global - Both Services)
-- ============================================
INSERT INTO offers (
    type, name_ar, name_en, description_ar, description_en,
    discount_type, discount_value,
    start_date, end_date,
    is_active, priority,
    branch_id, service_type,
    show_on_product_page, show_in_carousel, send_push_notification
) VALUES (
    'product',
    'عرض نهاية الأسبوع - خضار وفواكه طازجة',
    'Weekend Special - Fresh Fruits & Vegetables',
    'خصم 20% على جميع الفواكه والخضروات الطازجة',
    '20% off on all fresh fruits and vegetables',
    'percentage', 20.00,
    NOW(), NOW() + INTERVAL '30 days',
    true, 8,
    NULL, 'both',
    true, true, true
) RETURNING id;

-- Link offer to specific products (Fresh Apples, Organic Carrots, Fresh Tomatoes)
INSERT INTO offer_products (offer_id, product_id, unit_id) VALUES
((SELECT id FROM offers WHERE name_en = 'Weekend Special - Fresh Fruits & Vegetables'), '64d1ee39-234b-4e56-bc97-ec5340e729f2', '9426f391-dc89-4331-90b3-2b5b49db1b50'),
((SELECT id FROM offers WHERE name_en = 'Weekend Special - Fresh Fruits & Vegetables'), '076c30ef-fc7a-4a0c-adf9-6efb5d7d69be', '9426f391-dc89-4331-90b3-2b5b49db1b50'),
((SELECT id FROM offers WHERE name_en = 'Weekend Special - Fresh Fruits & Vegetables'), 'b68dd985-0334-4f2b-b1c6-50de883d4081', '9426f391-dc89-4331-90b3-2b5b49db1b50');

-- ============================================
-- 2. Free Delivery - Minimum Purchase (Cart Offer - Global - Delivery Only)
-- ============================================
INSERT INTO offers (
    type, name_ar, name_en, description_ar, description_en,
    discount_type, discount_value,
    start_date, end_date,
    is_active, priority,
    min_amount,
    branch_id, service_type,
    show_on_product_page, show_in_carousel, send_push_notification
) VALUES (
    'min_purchase',
    'توصيل مجاني للطلبات فوق 100 ريال',
    'Free Delivery on Orders Above 100 SAR',
    'اطلب بقيمة 100 ريال أو أكثر واحصل على توصيل مجاني',
    'Order 100 SAR or more and get free delivery',
    'fixed', 15.00,
    NOW(), NOW() + INTERVAL '60 days',
    true, 9,
    100.00,
    NULL, 'delivery',
    false, true, true
);

-- ============================================
-- 3. Pickup Discount - Store Pickup Incentive (Product Offer - Global - Pickup Only)
-- ============================================
INSERT INTO offers (
    type, name_ar, name_en, description_ar, description_en,
    discount_type, discount_value,
    start_date, end_date,
    is_active, priority,
    branch_id, service_type,
    show_on_product_page, show_in_carousel, send_push_notification
) VALUES (
    'product',
    'خصم 15% للاستلام من المتجر',
    '15% Off for Store Pickup',
    'وفّر 15% على جميع المنتجات عند الاستلام من المتجر',
    'Save 15% on all products when you pickup from store',
    'percentage', 15.00,
    NOW(), NOW() + INTERVAL '45 days',
    true, 7,
    NULL, 'pickup',
    true, true, false
);

-- Link to dairy products (Fresh Milk)
INSERT INTO offer_products (offer_id, product_id, unit_id) VALUES
((SELECT id FROM offers WHERE name_en = '15% Off for Store Pickup'), '39a232c1-6f15-4a23-9829-fb2331f8f570', (SELECT unit_id FROM products WHERE id = '39a232c1-6f15-4a23-9829-fb2331f8f570')),
((SELECT id FROM offers WHERE name_en = '15% Off for Store Pickup'), 'b469a4bc-3e52-4e99-9537-08dd336cc3ff', (SELECT unit_id FROM products WHERE id = 'b469a4bc-3e52-4e99-9537-08dd336cc3ff'));

-- ============================================
-- 4. BOGO - Buy 2 Get 1 Free (BOGO Offer - Branch-Specific - Both Services)
-- ============================================
INSERT INTO offers (
    type, name_ar, name_en, description_ar, description_en,
    discount_type, discount_value,
    bogo_buy_quantity, bogo_get_quantity,
    start_date, end_date,
    is_active, priority,
    branch_id, service_type,
    show_on_product_page, show_in_carousel, send_push_notification
) VALUES (
    'bogo',
    'اشتري 2 واحصل على 1 مجاناً - حليب طازج',
    'Buy 2 Get 1 Free - Fresh Milk',
    'اشتري 2 لتر من الحليب الطازج واحصل على لتر إضافي مجاناً',
    'Buy 2 liters of fresh milk and get 1 liter free',
    'percentage', 33.33,
    2, 1,
    NOW(), NOW() + INTERVAL '14 days',
    true, 8,
    1, 'both',
    true, true, true
);

-- Link to Fresh Milk products
INSERT INTO offer_products (offer_id, product_id, unit_id) VALUES
((SELECT id FROM offers WHERE name_en = 'Buy 2 Get 1 Free - Fresh Milk'), '39a232c1-6f15-4a23-9829-fb2331f8f570', (SELECT unit_id FROM products WHERE id = '39a232c1-6f15-4a23-9829-fb2331f8f570'));

-- ============================================
-- 5. Flash Sale - Limited Time (Product Offer - Global - Both Services)
-- ============================================
INSERT INTO offers (
    type, name_ar, name_en, description_ar, description_en,
    discount_type, discount_value,
    start_date, end_date,
    is_active, priority,
    max_total_uses,
    branch_id, service_type,
    show_on_product_page, show_in_carousel, send_push_notification
) VALUES (
    'product',
    'تخفيضات سريعة - تفاح طازج',
    'Flash Sale - Fresh Apples',
    'خصم 30% لأول 50 طلب فقط',
    '30% off - First 50 orders only',
    'percentage', 30.00,
    NOW(), NOW() + INTERVAL '7 days',
    true, 10,
    50,
    NULL, 'both',
    true, true, true
);

-- Link to Fresh Apples
INSERT INTO offer_products (offer_id, product_id, unit_id) VALUES
((SELECT id FROM offers WHERE name_en = 'Flash Sale - Fresh Apples'), '64d1ee39-234b-4e56-bc97-ec5340e729f2', '9426f391-dc89-4331-90b3-2b5b49db1b50');

-- ============================================
-- 6. Bundle Offer - Healthy Breakfast Bundle (Bundle Offer - Global - Both Services)
-- ============================================
INSERT INTO offers (
    type, name_ar, name_en, description_ar, description_en,
    discount_type, discount_value,
    start_date, end_date,
    is_active, priority,
    branch_id, service_type,
    show_on_product_page, show_in_carousel, send_push_notification
) VALUES (
    'bundle',
    'حزمة الفطور الصحي',
    'Healthy Breakfast Bundle',
    'اشتري تفاح + حليب واحصل على خصم 10 ريال',
    'Buy apples + milk and save 10 SAR',
    'fixed', 10.00,
    NOW(), NOW() + INTERVAL '30 days',
    true, 7,
    NULL, 'both',
    true, true, true
);

-- Create bundle configuration
INSERT INTO offer_bundles (
    offer_id,
    bundle_name_ar, bundle_name_en,
    required_products,
    discount_amount
) VALUES (
    (SELECT id FROM offers WHERE name_en = 'Healthy Breakfast Bundle'),
    'حزمة الفطور الصحي', 'Healthy Breakfast Bundle',
    '[
        {"product_id": "64d1ee39-234b-4e56-bc97-ec5340e729f2", "unit_id": "9426f391-dc89-4331-90b3-2b5b49db1b50", "quantity": 1},
        {"product_id": "39a232c1-6f15-4a23-9829-fb2331f8f570", "unit_id": null, "quantity": 2}
    ]'::jsonb,
    10.00
);

-- ============================================
-- 7. Customer-Specific VIP Offer (Customer Offer - Global - Both Services)
-- ============================================
-- Note: This creates the offer template. Customer assignments should be done separately via admin interface
INSERT INTO offers (
    type, name_ar, name_en, description_ar, description_en,
    discount_type, discount_value,
    start_date, end_date,
    is_active, priority,
    max_uses_per_customer,
    branch_id, service_type,
    show_on_product_page, show_in_carousel, send_push_notification
) VALUES (
    'customer',
    'عرض العملاء المميزين',
    'VIP Customer Exclusive',
    'خصم 25% حصري للعملاء المميزين',
    '25% exclusive discount for VIP customers',
    'percentage', 25.00,
    NOW(), NOW() + INTERVAL '90 days',
    true, 10,
    5,
    NULL, 'both',
    false, false, true
);

-- ============================================
-- Summary
-- ============================================
-- Created 7 sample offers:
-- 1. Weekend Special (Product, 20% off, Global, Both services)
-- 2. Free Delivery (Min Purchase, 15 SAR off, Global, Delivery only)
-- 3. Pickup Discount (Product, 15% off, Global, Pickup only)
-- 4. BOGO Milk (BOGO, Buy 2 Get 1, Branch 1, Both services)
-- 5. Flash Sale (Product, 30% off, Global, Both services, Limited to 50 uses)
-- 6. Breakfast Bundle (Bundle, 10 SAR off, Global, Both services)
-- 7. VIP Exclusive (Customer-specific, 25% off, Global, Both services)
-- ============================================

SELECT 
    name_en,
    type,
    CASE 
        WHEN branch_id IS NULL THEN 'Global'
        ELSE 'Branch ' || branch_id
    END as scope,
    service_type,
    CASE 
        WHEN discount_type = 'percentage' THEN discount_value || '%'
        ELSE discount_value || ' SAR'
    END as discount,
    CASE 
        WHEN is_active THEN '✓ Active'
        ELSE '✗ Inactive'
    END as status
FROM offers
ORDER BY priority DESC, created_at DESC;
