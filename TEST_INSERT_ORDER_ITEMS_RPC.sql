-- Test the insert_order_items RPC function
SELECT * FROM insert_order_items('[
  {
    "order_id": "1ac82b0a-256b-4cb2-acba-962216e51e85",
    "product_id": "019100208360",
    "product_name_ar": "منتج اختبار",
    "product_name_en": "Test Product",
    "quantity": 1,
    "unit_price": 10.00,
    "original_price": 10.00,
    "discount_amount": 0,
    "final_price": 10.00,
    "line_total": 10.00,
    "has_offer": false,
    "offer_id": null,
    "item_type": "regular",
    "is_bundle_item": false,
    "is_bogo_free": false
  }
]'::jsonb);
