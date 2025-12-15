-- Debug: Check bundle offer pricing and structure
SELECT 
  o.id as offer_id,
  o.name_en,
  o.name_ar,
  o.type,
  o.is_active,
  o.start_date,
  o.end_date,
  ob.id as bundle_id,
  ob.bundle_name_en,
  ob.bundle_name_ar,
  ob.discount_type,
  ob.discount_value,
  ob.required_products
FROM offers o
LEFT JOIN offer_bundles ob ON o.id = ob.offer_id
WHERE o.type = 'bundle'
  AND o.is_active = true
ORDER BY o.created_at DESC
LIMIT 5;

-- Check the required products structure in a specific bundle
SELECT 
  ob.id,
  ob.bundle_name_en,
  ob.required_products,
  jsonb_array_length(ob.required_products::jsonb) as product_count
FROM offer_bundles ob
LIMIT 3;

-- Detailed product pricing for bundle items
SELECT 
  ob.bundle_name_en,
  p.product_name_en,
  p.sale_price,
  req->>'quantity' as bundle_quantity
FROM offer_bundles ob,
  jsonb_array_elements(ob.required_products::jsonb) as req
LEFT JOIN products p ON p.id::text = req->>'product_id'
ORDER BY ob.id DESC, req->>'product_id'
LIMIT 10;
