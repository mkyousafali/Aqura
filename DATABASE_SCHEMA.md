# Supabase Database Schema

**Generated:** December 1, 2025 at 01:10:08 PM  
**Total Tables:** 88  
**Total Columns:** 1400

---

## Table of Contents

1. [app_functions](#app_functions) - 8 columns
2. [approval_permissions](#approval_permissions) - 18 columns
3. [biometric_connections](#biometric_connections) - 15 columns
4. [bogo_offer_rules](#bogo_offer_rules) - 10 columns
5. [branches](#branches) - 26 columns
6. [coupon_campaigns](#coupon_campaigns) - 18 columns
7. [coupon_claims](#coupon_claims) - 13 columns
8. [coupon_eligible_customers](#coupon_eligible_customers) - 8 columns
9. [coupon_products](#coupon_products) - 16 columns
10. [customer_access_code_history](#customer_access_code_history) - 8 columns
11. [customer_app_media](#customer_app_media) - 20 columns
12. [customer_recovery_requests](#customer_recovery_requests) - 11 columns
13. [customers](#customers) - 24 columns
14. [deleted_bundle_offers](#deleted_bundle_offers) - 7 columns
15. [delivery_fee_tiers](#delivery_fee_tiers) - 13 columns
16. [delivery_service_settings](#delivery_service_settings) - 11 columns
17. [employee_fine_payments](#employee_fine_payments) - 15 columns
18. [employee_warning_history](#employee_warning_history) - 11 columns
19. [employee_warnings](#employee_warnings) - 48 columns
20. [erp_connections](#erp_connections) - 13 columns
21. [erp_daily_sales](#erp_daily_sales) - 16 columns
22. [expense_parent_categories](#expense_parent_categories) - 6 columns
23. [expense_requisitions](#expense_requisitions) - 31 columns
24. [expense_scheduler](#expense_scheduler) - 35 columns
25. [expense_sub_categories](#expense_sub_categories) - 7 columns
26. [flyer_offer_products](#flyer_offer_products) - 14 columns
27. [flyer_offers](#flyer_offers) - 8 columns
28. [flyer_products](#flyer_products) - 20 columns
29. [flyer_templates](#flyer_templates) - 19 columns
30. [hr_departments](#hr_departments) - 5 columns
31. [hr_employee_contacts](#hr_employee_contacts) - 7 columns
32. [hr_employee_documents](#hr_employee_documents) - 30 columns
33. [hr_employees](#hr_employees) - 7 columns
34. [hr_fingerprint_transactions](#hr_fingerprint_transactions) - 10 columns
35. [hr_levels](#hr_levels) - 6 columns
36. [hr_position_assignments](#hr_position_assignments) - 9 columns
37. [hr_position_reporting_template](#hr_position_reporting_template) - 9 columns
38. [hr_positions](#hr_positions) - 7 columns
39. [hr_salary_components](#hr_salary_components) - 12 columns
40. [hr_salary_wages](#hr_salary_wages) - 7 columns
41. [interface_permissions](#interface_permissions) - 10 columns
42. [non_approved_payment_scheduler](#non_approved_payment_scheduler) - 34 columns
43. [notification_attachments](#notification_attachments) - 8 columns
44. [notification_queue](#notification_queue) - 19 columns
45. [notification_read_states](#notification_read_states) - 6 columns
46. [notification_recipients](#notification_recipients) - 14 columns
47. [notifications](#notifications) - 25 columns
48. [offer_bundles](#offer_bundles) - 9 columns
49. [offer_cart_tiers](#offer_cart_tiers) - 9 columns
50. [offer_products](#offer_products) - 14 columns
51. [offer_usage_logs](#offer_usage_logs) - 11 columns
52. [offers](#offers) - 20 columns
53. [order_audit_logs](#order_audit_logs) - 18 columns
54. [order_items](#order_items) - 34 columns
55. [orders](#orders) - 40 columns
56. [product_categories](#product_categories) - 9 columns
57. [product_units](#product_units) - 7 columns
58. [products](#products) - 29 columns
59. [push_subscriptions](#push_subscriptions) - 14 columns
60. [quick_task_assignments](#quick_task_assignments) - 12 columns
61. [quick_task_comments](#quick_task_comments) - 6 columns
62. [quick_task_completions](#quick_task_completions) - 13 columns
63. [quick_task_files](#quick_task_files) - 10 columns
64. [quick_task_user_preferences](#quick_task_user_preferences) - 9 columns
65. [quick_tasks](#quick_tasks) - 17 columns
66. [receiving_records](#receiving_records) - 56 columns
67. [receiving_task_templates](#receiving_task_templates) - 13 columns
68. [receiving_tasks](#receiving_tasks) - 26 columns
69. [recurring_assignment_schedules](#recurring_assignment_schedules) - 19 columns
70. [recurring_schedule_check_log](#recurring_schedule_check_log) - 5 columns
71. [requesters](#requesters) - 8 columns
72. [role_permissions](#role_permissions) - 10 columns
73. [shelf_paper_templates](#shelf_paper_templates) - 10 columns
74. [task_assignments](#task_assignments) - 27 columns
75. [task_completions](#task_completions) - 17 columns
76. [task_images](#task_images) - 14 columns
77. [task_reminder_logs](#task_reminder_logs) - 11 columns
78. [tasks](#tasks) - 21 columns
79. [tax_categories](#tax_categories) - 8 columns
80. [user_audit_logs](#user_audit_logs) - 12 columns
81. [user_device_sessions](#user_device_sessions) - 14 columns
82. [user_password_history](#user_password_history) - 5 columns
83. [user_roles](#user_roles) - 10 columns
84. [user_sessions](#user_sessions) - 10 columns
85. [users](#users) - 28 columns
86. [variation_audit_log](#variation_audit_log) - 11 columns
87. [vendor_payment_schedule](#vendor_payment_schedule) - 56 columns
88. [vendors](#vendors) - 34 columns

---

## app_functions

**Total Columns:** 8

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `function_name` | `character varying` | ✗ No | - |
| `function_code` | `character varying` | ✗ No | - |
| `description` | `text` | ✓ Yes | - |
| `category` | `character varying` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## approval_permissions

**Total Columns:** 18

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `bigint` | ✗ No | `nextval('approval_permissions_id_seq'::regclass)` |
| `user_id` | `uuid` | ✗ No | - |
| `can_approve_requisitions` | `boolean` | ✗ No | `false` |
| `requisition_amount_limit` | `numeric` | ✓ Yes | `0.00` |
| `can_approve_single_bill` | `boolean` | ✗ No | `false` |
| `single_bill_amount_limit` | `numeric` | ✓ Yes | `0.00` |
| `can_approve_multiple_bill` | `boolean` | ✗ No | `false` |
| `multiple_bill_amount_limit` | `numeric` | ✓ Yes | `0.00` |
| `can_approve_recurring_bill` | `boolean` | ✗ No | `false` |
| `recurring_bill_amount_limit` | `numeric` | ✓ Yes | `0.00` |
| `can_approve_vendor_payments` | `boolean` | ✗ No | `false` |
| `vendor_payment_amount_limit` | `numeric` | ✓ Yes | `0.00` |
| `can_approve_leave_requests` | `boolean` | ✗ No | `false` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `uuid` | ✓ Yes | - |
| `updated_by` | `uuid` | ✓ Yes | - |
| `is_active` | `boolean` | ✗ No | `true` |

## biometric_connections

**Total Columns:** 15

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `branch_id` | `integer` | ✗ No | - |
| `branch_name` | `text` | ✗ No | - |
| `server_ip` | `text` | ✗ No | - |
| `server_name` | `text` | ✓ Yes | - |
| `database_name` | `text` | ✗ No | - |
| `username` | `text` | ✗ No | - |
| `password` | `text` | ✗ No | - |
| `device_id` | `text` | ✗ No | - |
| `terminal_sn` | `text` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `last_sync_at` | `timestamp with time zone` | ✓ Yes | - |
| `last_employee_sync_at` | `timestamp with time zone` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## bogo_offer_rules

**Total Columns:** 10

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `integer` | ✗ No | `nextval('bogo_offer_rules_id_seq'::regclass)` |
| `offer_id` | `integer` | ✗ No | - |
| `buy_product_id` | `uuid` | ✗ No | - |
| `buy_quantity` | `integer` | ✗ No | - |
| `get_product_id` | `uuid` | ✗ No | - |
| `get_quantity` | `integer` | ✗ No | - |
| `discount_type` | `character varying` | ✗ No | - |
| `discount_value` | `numeric` | ✓ Yes | `0` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## branches

**Total Columns:** 26

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `bigint` | ✗ No | `nextval('branches_id_seq'::regclass)` |
| `name_en` | `character varying` | ✗ No | - |
| `name_ar` | `character varying` | ✗ No | - |
| `location_en` | `character varying` | ✗ No | - |
| `location_ar` | `character varying` | ✗ No | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `is_main_branch` | `boolean` | ✓ Yes | `false` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `bigint` | ✓ Yes | - |
| `updated_by` | `bigint` | ✓ Yes | - |
| `vat_number` | `character varying` | ✓ Yes | - |
| `delivery_service_enabled` | `boolean` | ✗ No | `true` |
| `pickup_service_enabled` | `boolean` | ✗ No | `true` |
| `minimum_order_amount` | `numeric` | ✓ Yes | `15.00` |
| `is_24_hours` | `boolean` | ✓ Yes | `true` |
| `operating_start_time` | `time without time zone` | ✓ Yes | - |
| `operating_end_time` | `time without time zone` | ✓ Yes | - |
| `delivery_message_ar` | `text` | ✓ Yes | - |
| `delivery_message_en` | `text` | ✓ Yes | - |
| `delivery_is_24_hours` | `boolean` | ✓ Yes | `true` |
| `delivery_start_time` | `time without time zone` | ✓ Yes | - |
| `delivery_end_time` | `time without time zone` | ✓ Yes | - |
| `pickup_is_24_hours` | `boolean` | ✓ Yes | `true` |
| `pickup_start_time` | `time without time zone` | ✓ Yes | - |
| `pickup_end_time` | `time without time zone` | ✓ Yes | - |

## coupon_campaigns

**Total Columns:** 18

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `campaign_name` | `character varying` | ✓ Yes | - |
| `campaign_code` | `character varying` | ✗ No | - |
| `description` | `text` | ✓ Yes | - |
| `validity_start_date` | `timestamp with time zone` | ✓ Yes | - |
| `validity_end_date` | `timestamp with time zone` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `terms_conditions_en` | `text` | ✓ Yes | - |
| `terms_conditions_ar` | `text` | ✓ Yes | - |
| `created_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `deleted_at` | `timestamp with time zone` | ✓ Yes | - |
| `name_en` | `character varying` | ✗ No | - |
| `name_ar` | `character varying` | ✗ No | - |
| `start_date` | `timestamp with time zone` | ✗ No | - |
| `end_date` | `timestamp with time zone` | ✗ No | - |
| `max_claims_per_customer` | `integer` | ✓ Yes | `1` |

## coupon_claims

**Total Columns:** 13

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `campaign_id` | `uuid` | ✗ No | - |
| `customer_mobile` | `character varying` | ✗ No | - |
| `product_id` | `uuid` | ✓ Yes | - |
| `branch_id` | `bigint` | ✓ Yes | - |
| `claimed_by_user` | `uuid` | ✓ Yes | - |
| `claimed_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `print_count` | `integer` | ✓ Yes | `1` |
| `barcode_scanned` | `boolean` | ✓ Yes | `false` |
| `validity_date` | `date` | ✗ No | - |
| `status` | `character varying` | ✓ Yes | `'claimed'::character varying` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `max_claims_per_customer` | `integer` | ✓ Yes | `1` |

## coupon_eligible_customers

**Total Columns:** 8

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `campaign_id` | `uuid` | ✗ No | - |
| `mobile_number` | `character varying` | ✗ No | - |
| `customer_name` | `character varying` | ✓ Yes | - |
| `import_batch_id` | `uuid` | ✓ Yes | - |
| `imported_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `imported_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## coupon_products

**Total Columns:** 16

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `campaign_id` | `uuid` | ✗ No | - |
| `product_name_en` | `character varying` | ✗ No | - |
| `product_name_ar` | `character varying` | ✗ No | - |
| `product_image_url` | `text` | ✓ Yes | - |
| `original_price` | `numeric` | ✗ No | - |
| `offer_price` | `numeric` | ✗ No | - |
| `special_barcode` | `character varying` | ✗ No | - |
| `stock_limit` | `integer` | ✗ No | `0` |
| `stock_remaining` | `integer` | ✗ No | `0` |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `deleted_at` | `timestamp with time zone` | ✓ Yes | - |
| `flyer_product_id` | `uuid` | ✓ Yes | - |

## customer_access_code_history

**Total Columns:** 8

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `customer_id` | `uuid` | ✗ No | - |
| `old_access_code` | `character varying` | ✓ Yes | - |
| `new_access_code` | `character varying` | ✗ No | - |
| `generated_by` | `uuid` | ✗ No | - |
| `reason` | `text` | ✗ No | - |
| `notes` | `text` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## customer_app_media

**Total Columns:** 20

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `media_type` | `character varying` | ✗ No | - |
| `slot_number` | `integer` | ✗ No | - |
| `title_en` | `character varying` | ✗ No | - |
| `title_ar` | `character varying` | ✗ No | - |
| `description_en` | `text` | ✓ Yes | - |
| `description_ar` | `text` | ✓ Yes | - |
| `file_url` | `text` | ✗ No | - |
| `file_size` | `bigint` | ✓ Yes | - |
| `file_type` | `character varying` | ✓ Yes | - |
| `duration` | `integer` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `false` |
| `display_order` | `integer` | ✓ Yes | `0` |
| `is_infinite` | `boolean` | ✓ Yes | `false` |
| `expiry_date` | `timestamp with time zone` | ✓ Yes | - |
| `uploaded_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `activated_at` | `timestamp with time zone` | ✓ Yes | - |
| `deactivated_at` | `timestamp with time zone` | ✓ Yes | - |

## customer_recovery_requests

**Total Columns:** 11

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `customer_id` | `uuid` | ✓ Yes | - |
| `whatsapp_number` | `character varying` | ✗ No | - |
| `customer_name` | `text` | ✓ Yes | - |
| `request_type` | `text` | ✗ No | `'account_recovery'::text` |
| `verification_status` | `text` | ✗ No | `'pending'::text` |
| `verification_notes` | `text` | ✓ Yes | - |
| `processed_by` | `uuid` | ✓ Yes | - |
| `processed_at` | `timestamp with time zone` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## customers

**Total Columns:** 24

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `access_code` | `character varying` | ✓ Yes | - |
| `whatsapp_number` | `character varying` | ✓ Yes | - |
| `registration_status` | `text` | ✗ No | `'pending'::text` |
| `registration_notes` | `text` | ✓ Yes | - |
| `approved_by` | `uuid` | ✓ Yes | - |
| `approved_at` | `timestamp with time zone` | ✓ Yes | - |
| `access_code_generated_at` | `timestamp with time zone` | ✓ Yes | - |
| `last_login_at` | `timestamp with time zone` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `name` | `text` | ✓ Yes | - |
| `location1_name` | `text` | ✓ Yes | - |
| `location1_url` | `text` | ✓ Yes | - |
| `location2_name` | `text` | ✓ Yes | - |
| `location2_url` | `text` | ✓ Yes | - |
| `location3_name` | `text` | ✓ Yes | - |
| `location3_url` | `text` | ✓ Yes | - |
| `location1_lat` | `double precision` | ✓ Yes | - |
| `location1_lng` | `double precision` | ✓ Yes | - |
| `location2_lat` | `double precision` | ✓ Yes | - |
| `location2_lng` | `double precision` | ✓ Yes | - |
| `location3_lat` | `double precision` | ✓ Yes | - |
| `location3_lng` | `double precision` | ✓ Yes | - |

## deleted_bundle_offers

**Total Columns:** 7

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `original_offer_id` | `integer` | ✗ No | - |
| `offer_data` | `jsonb` | ✗ No | - |
| `bundles_data` | `jsonb` | ✗ No | - |
| `deleted_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `deleted_by` | `uuid` | ✓ Yes | - |
| `deletion_reason` | `text` | ✓ Yes | - |

## delivery_fee_tiers

**Total Columns:** 13

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `min_order_amount` | `numeric` | ✗ No | - |
| `max_order_amount` | `numeric` | ✓ Yes | - |
| `delivery_fee` | `numeric` | ✗ No | - |
| `tier_order` | `integer` | ✗ No | - |
| `is_active` | `boolean` | ✗ No | `true` |
| `description_en` | `text` | ✓ Yes | - |
| `description_ar` | `text` | ✓ Yes | - |
| `created_by` | `uuid` | ✓ Yes | - |
| `updated_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `branch_id` | `bigint` | ✓ Yes | - |

## delivery_service_settings

**Total Columns:** 11

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `minimum_order_amount` | `numeric` | ✗ No | `15.00` |
| `is_24_hours` | `boolean` | ✗ No | `true` |
| `operating_start_time` | `time without time zone` | ✓ Yes | - |
| `operating_end_time` | `time without time zone` | ✓ Yes | - |
| `is_active` | `boolean` | ✗ No | `true` |
| `display_message_ar` | `text` | ✓ Yes | `'التوصيل متاح على مدار الساعة (24/7)'::text` |
| `display_message_en` | `text` | ✓ Yes | `'Delivery available 24/7'::text` |
| `updated_by` | `uuid` | ✓ Yes | - |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## employee_fine_payments

**Total Columns:** 15

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `warning_id` | `uuid` | ✓ Yes | - |
| `payment_method` | `character varying` | ✓ Yes | - |
| `payment_amount` | `numeric` | ✗ No | - |
| `payment_currency` | `character varying` | ✓ Yes | `'USD'::character varying` |
| `payment_date` | `timestamp without time zone` | ✓ Yes | `CURRENT_TIMESTAMP` |
| `payment_reference` | `character varying` | ✓ Yes | - |
| `payment_notes` | `text` | ✓ Yes | - |
| `processed_by` | `uuid` | ✓ Yes | - |
| `processed_by_username` | `character varying` | ✓ Yes | - |
| `account_code` | `character varying` | ✓ Yes | - |
| `transaction_id` | `character varying` | ✓ Yes | - |
| `receipt_number` | `character varying` | ✓ Yes | - |
| `created_at` | `timestamp without time zone` | ✓ Yes | `CURRENT_TIMESTAMP` |
| `updated_at` | `timestamp without time zone` | ✓ Yes | `CURRENT_TIMESTAMP` |

## employee_warning_history

**Total Columns:** 11

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `warning_id` | `uuid` | ✗ No | - |
| `action_type` | `character varying` | ✗ No | - |
| `old_values` | `jsonb` | ✓ Yes | - |
| `new_values` | `jsonb` | ✓ Yes | - |
| `changed_by` | `uuid` | ✓ Yes | - |
| `changed_by_username` | `character varying` | ✓ Yes | - |
| `change_reason` | `text` | ✓ Yes | - |
| `created_at` | `timestamp without time zone` | ✗ No | `CURRENT_TIMESTAMP` |
| `ip_address` | `inet` | ✓ Yes | - |
| `user_agent` | `text` | ✓ Yes | - |

## employee_warnings

**Total Columns:** 48

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `user_id` | `uuid` | ✓ Yes | - |
| `employee_id` | `uuid` | ✓ Yes | - |
| `username` | `character varying` | ✓ Yes | - |
| `warning_type` | `character varying` | ✗ No | - |
| `has_fine` | `boolean` | ✓ Yes | `false` |
| `fine_amount` | `numeric` | ✓ Yes | `NULL::numeric` |
| `fine_currency` | `character varying` | ✓ Yes | `'USD'::character varying` |
| `fine_status` | `character varying` | ✓ Yes | `'pending'::character varying` |
| `fine_due_date` | `date` | ✓ Yes | - |
| `fine_paid_date` | `timestamp without time zone` | ✓ Yes | - |
| `fine_paid_amount` | `numeric` | ✓ Yes | `NULL::numeric` |
| `warning_text` | `text` | ✗ No | - |
| `language_code` | `character varying` | ✗ No | `'en'::character varying` |
| `task_id` | `uuid` | ✓ Yes | - |
| `task_title` | `character varying` | ✓ Yes | - |
| `task_description` | `text` | ✓ Yes | - |
| `assignment_id` | `uuid` | ✓ Yes | - |
| `total_tasks_assigned` | `integer` | ✓ Yes | `0` |
| `total_tasks_completed` | `integer` | ✓ Yes | `0` |
| `total_tasks_overdue` | `integer` | ✓ Yes | `0` |
| `completion_rate` | `numeric` | ✓ Yes | `0` |
| `issued_by` | `uuid` | ✓ Yes | - |
| `issued_by_username` | `character varying` | ✓ Yes | - |
| `issued_at` | `timestamp without time zone` | ✓ Yes | `CURRENT_TIMESTAMP` |
| `warning_status` | `character varying` | ✓ Yes | `'active'::character varying` |
| `acknowledged_at` | `timestamp without time zone` | ✓ Yes | - |
| `acknowledged_by` | `uuid` | ✓ Yes | - |
| `resolved_at` | `timestamp without time zone` | ✓ Yes | - |
| `resolved_by` | `uuid` | ✓ Yes | - |
| `resolution_notes` | `text` | ✓ Yes | - |
| `created_at` | `timestamp without time zone` | ✓ Yes | `CURRENT_TIMESTAMP` |
| `updated_at` | `timestamp without time zone` | ✓ Yes | `CURRENT_TIMESTAMP` |
| `branch_id` | `bigint` | ✓ Yes | - |
| `department_id` | `uuid` | ✓ Yes | - |
| `severity_level` | `character varying` | ✓ Yes | `'medium'::character varying` |
| `follow_up_required` | `boolean` | ✓ Yes | `false` |
| `follow_up_date` | `date` | ✓ Yes | - |
| `warning_reference` | `character varying` | ✓ Yes | - |
| `warning_document_url` | `text` | ✓ Yes | - |
| `is_deleted` | `boolean` | ✓ Yes | `false` |
| `deleted_at` | `timestamp without time zone` | ✓ Yes | - |
| `deleted_by` | `uuid` | ✓ Yes | - |
| `fine_paid_at` | `timestamp without time zone` | ✓ Yes | - |
| `frontend_save_id` | `character varying` | ✓ Yes | - |
| `fine_payment_note` | `text` | ✓ Yes | - |
| `fine_payment_method` | `character varying` | ✓ Yes | `'cash'::character varying` |
| `fine_payment_reference` | `character varying` | ✓ Yes | - |

## erp_connections

**Total Columns:** 13

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `branch_id` | `bigint` | ✗ No | - |
| `branch_name` | `text` | ✗ No | - |
| `server_ip` | `text` | ✗ No | - |
| `server_name` | `text` | ✓ Yes | - |
| `database_name` | `text` | ✗ No | - |
| `username` | `text` | ✗ No | - |
| `password` | `text` | ✗ No | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `device_id` | `text` | ✓ Yes | - |
| `erp_branch_id` | `integer` | ✓ Yes | - |

## erp_daily_sales

**Total Columns:** 16

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `branch_id` | `bigint` | ✗ No | - |
| `sale_date` | `date` | ✗ No | - |
| `total_bills` | `integer` | ✓ Yes | `0` |
| `gross_amount` | `numeric` | ✓ Yes | `0` |
| `tax_amount` | `numeric` | ✓ Yes | `0` |
| `discount_amount` | `numeric` | ✓ Yes | `0` |
| `total_returns` | `integer` | ✓ Yes | `0` |
| `return_amount` | `numeric` | ✓ Yes | `0` |
| `return_tax` | `numeric` | ✓ Yes | `0` |
| `net_bills` | `integer` | ✓ Yes | `0` |
| `net_amount` | `numeric` | ✓ Yes | `0` |
| `net_tax` | `numeric` | ✓ Yes | `0` |
| `last_sync_at` | `timestamp with time zone` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## expense_parent_categories

**Total Columns:** 6

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `bigint` | ✗ No | `nextval('expense_parent_categories_id_seq'::regclass)` |
| `name_en` | `text` | ✗ No | - |
| `name_ar` | `text` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `is_active` | `boolean` | ✓ Yes | `true` |

## expense_requisitions

**Total Columns:** 31

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `bigint` | ✗ No | `nextval('expense_requisitions_id_seq'::regclass)` |
| `requisition_number` | `text` | ✗ No | - |
| `branch_id` | `bigint` | ✗ No | - |
| `branch_name` | `text` | ✗ No | - |
| `approver_id` | `uuid` | ✓ Yes | - |
| `approver_name` | `text` | ✓ Yes | - |
| `expense_category_id` | `bigint` | ✓ Yes | - |
| `expense_category_name_en` | `text` | ✓ Yes | - |
| `expense_category_name_ar` | `text` | ✓ Yes | - |
| `requester_id` | `text` | ✗ No | - |
| `requester_name` | `text` | ✗ No | - |
| `requester_contact` | `text` | ✗ No | - |
| `vat_applicable` | `boolean` | ✓ Yes | `false` |
| `amount` | `numeric` | ✗ No | - |
| `payment_category` | `text` | ✗ No | - |
| `description` | `text` | ✓ Yes | - |
| `status` | `text` | ✓ Yes | `'pending'::text` |
| `image_url` | `text` | ✓ Yes | - |
| `created_by` | `uuid` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `credit_period` | `integer` | ✓ Yes | - |
| `bank_name` | `text` | ✓ Yes | - |
| `iban` | `text` | ✓ Yes | - |
| `used_amount` | `numeric` | ✓ Yes | `0` |
| `remaining_balance` | `numeric` | ✓ Yes | `0` |
| `requester_ref_id` | `uuid` | ✓ Yes | - |
| `is_active` | `boolean` | ✗ No | `true` |
| `due_date` | `date` | ✓ Yes | - |
| `internal_user_id` | `uuid` | ✓ Yes | - |
| `request_type` | `text` | ✓ Yes | `'external'::text` |

## expense_scheduler

**Total Columns:** 35

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `bigint` | ✗ No | `nextval('expense_scheduler_id_seq'::regclass)` |
| `branch_id` | `bigint` | ✗ No | - |
| `branch_name` | `text` | ✗ No | - |
| `expense_category_id` | `bigint` | ✓ Yes | - |
| `expense_category_name_en` | `text` | ✓ Yes | - |
| `expense_category_name_ar` | `text` | ✓ Yes | - |
| `requisition_id` | `bigint` | ✓ Yes | - |
| `requisition_number` | `text` | ✓ Yes | - |
| `co_user_id` | `uuid` | ✓ Yes | - |
| `co_user_name` | `text` | ✓ Yes | - |
| `bill_type` | `text` | ✗ No | - |
| `bill_number` | `text` | ✓ Yes | - |
| `bill_date` | `date` | ✓ Yes | - |
| `payment_method` | `text` | ✓ Yes | - |
| `due_date` | `date` | ✓ Yes | - |
| `credit_period` | `integer` | ✓ Yes | - |
| `amount` | `numeric` | ✗ No | - |
| `bill_file_url` | `text` | ✓ Yes | - |
| `description` | `text` | ✓ Yes | - |
| `notes` | `text` | ✓ Yes | - |
| `is_paid` | `boolean` | ✓ Yes | `false` |
| `paid_date` | `timestamp with time zone` | ✓ Yes | - |
| `status` | `text` | ✓ Yes | `'pending'::text` |
| `created_by` | `uuid` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_by` | `uuid` | ✓ Yes | - |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `bank_name` | `text` | ✓ Yes | - |
| `iban` | `text` | ✓ Yes | - |
| `payment_reference` | `character varying` | ✓ Yes | - |
| `schedule_type` | `text` | ✓ Yes | `'single_bill'::text` |
| `recurring_type` | `text` | ✓ Yes | - |
| `recurring_metadata` | `jsonb` | ✓ Yes | - |
| `approver_id` | `uuid` | ✓ Yes | - |
| `approver_name` | `text` | ✓ Yes | - |

## expense_sub_categories

**Total Columns:** 7

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `bigint` | ✗ No | `nextval('expense_sub_categories_id_seq'::regclass)` |
| `parent_category_id` | `bigint` | ✗ No | - |
| `name_en` | `text` | ✗ No | - |
| `name_ar` | `text` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `is_active` | `boolean` | ✓ Yes | `true` |

## flyer_offer_products

**Total Columns:** 14

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `offer_id` | `uuid` | ✗ No | - |
| `product_barcode` | `text` | ✗ No | - |
| `cost` | `numeric` | ✓ Yes | - |
| `sales_price` | `numeric` | ✓ Yes | - |
| `offer_price` | `numeric` | ✓ Yes | - |
| `profit_amount` | `numeric` | ✓ Yes | - |
| `profit_percent` | `numeric` | ✓ Yes | - |
| `profit_after_offer` | `numeric` | ✓ Yes | - |
| `decrease_amount` | `numeric` | ✓ Yes | - |
| `offer_qty` | `integer` | ✗ No | `1` |
| `limit_qty` | `integer` | ✓ Yes | - |
| `free_qty` | `integer` | ✗ No | `0` |
| `created_at` | `timestamp with time zone` | ✗ No | `timezone('utc'::text, now())` |

## flyer_offers

**Total Columns:** 8

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `template_id` | `text` | ✗ No | `(gen_random_uuid())::text` |
| `template_name` | `text` | ✗ No | - |
| `start_date` | `date` | ✗ No | - |
| `end_date` | `date` | ✗ No | - |
| `is_active` | `boolean` | ✗ No | `true` |
| `created_at` | `timestamp with time zone` | ✗ No | `timezone('utc'::text, now())` |
| `updated_at` | `timestamp with time zone` | ✗ No | `timezone('utc'::text, now())` |

## flyer_products

**Total Columns:** 20

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `barcode` | `text` | ✗ No | - |
| `product_name_en` | `text` | ✓ Yes | - |
| `product_name_ar` | `text` | ✓ Yes | - |
| `unit_name` | `text` | ✓ Yes | - |
| `image_url` | `text` | ✓ Yes | - |
| `parent_category` | `text` | ✗ No | - |
| `parent_sub_category` | `text` | ✗ No | - |
| `sub_category` | `text` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `is_variation` | `boolean` | ✗ No | `false` |
| `parent_product_barcode` | `text` | ✓ Yes | - |
| `variation_group_name_en` | `text` | ✓ Yes | - |
| `variation_group_name_ar` | `text` | ✓ Yes | - |
| `variation_order` | `integer` | ✓ Yes | `0` |
| `variation_image_override` | `text` | ✓ Yes | - |
| `created_by` | `uuid` | ✓ Yes | - |
| `modified_by` | `uuid` | ✓ Yes | - |
| `modified_at` | `timestamp with time zone` | ✓ Yes | - |

## flyer_templates

**Total Columns:** 19

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `name` | `character varying` | ✗ No | - |
| `description` | `text` | ✓ Yes | - |
| `first_page_image_url` | `text` | ✗ No | - |
| `sub_page_image_urls` | `ARRAY` | ✗ No | `'{}'::text[]` |
| `first_page_configuration` | `jsonb` | ✗ No | `'[]'::jsonb` |
| `sub_page_configurations` | `jsonb` | ✗ No | `'[]'::jsonb` |
| `metadata` | `jsonb` | ✓ Yes | `'{"sub_page_width": 794, "sub_page_height": 1123, "first_page_width": 794, "first_page_height": 1123}'::jsonb` |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `is_default` | `boolean` | ✓ Yes | `false` |
| `category` | `character varying` | ✓ Yes | - |
| `tags` | `ARRAY` | ✓ Yes | `'{}'::text[]` |
| `usage_count` | `integer` | ✓ Yes | `0` |
| `last_used_at` | `timestamp with time zone` | ✓ Yes | - |
| `created_by` | `uuid` | ✓ Yes | - |
| `updated_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `deleted_at` | `timestamp with time zone` | ✓ Yes | - |

## hr_departments

**Total Columns:** 5

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `department_name_en` | `character varying` | ✗ No | - |
| `department_name_ar` | `character varying` | ✗ No | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## hr_employee_contacts

**Total Columns:** 7

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `employee_id` | `uuid` | ✗ No | - |
| `email` | `character varying` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `whatsapp_number` | `character varying` | ✓ Yes | - |
| `contact_number` | `character varying` | ✓ Yes | - |

## hr_employee_documents

**Total Columns:** 30

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `employee_id` | `uuid` | ✗ No | - |
| `document_type` | `character varying` | ✗ No | - |
| `document_name` | `character varying` | ✗ No | - |
| `file_path` | `text` | ✗ No | - |
| `file_type` | `character varying` | ✓ Yes | - |
| `expiry_date` | `date` | ✓ Yes | - |
| `upload_date` | `date` | ✗ No | `CURRENT_DATE` |
| `is_active` | `boolean` | ✗ No | `true` |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `document_number` | `character varying` | ✓ Yes | - |
| `document_description` | `text` | ✓ Yes | - |
| `health_card_number` | `character varying` | ✓ Yes | - |
| `health_card_expiry` | `date` | ✓ Yes | - |
| `resident_id_number` | `character varying` | ✓ Yes | - |
| `resident_id_expiry` | `date` | ✓ Yes | - |
| `passport_number` | `character varying` | ✓ Yes | - |
| `passport_expiry` | `date` | ✓ Yes | - |
| `driving_license_number` | `character varying` | ✓ Yes | - |
| `driving_license_expiry` | `date` | ✓ Yes | - |
| `resume_uploaded` | `boolean` | ✓ Yes | `false` |
| `document_category` | `USER-DEFINED` | ✓ Yes | `'other'::document_category_enum` |
| `category_start_date` | `date` | ✓ Yes | - |
| `category_end_date` | `date` | ✓ Yes | - |
| `category_days` | `integer` | ✓ Yes | - |
| `category_last_working_day` | `date` | ✓ Yes | - |
| `category_reason` | `text` | ✓ Yes | - |
| `category_details` | `text` | ✓ Yes | - |
| `category_content` | `text` | ✓ Yes | - |

## hr_employees

**Total Columns:** 7

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `employee_id` | `character varying` | ✗ No | - |
| `branch_id` | `bigint` | ✗ No | - |
| `hire_date` | `date` | ✓ Yes | - |
| `status` | `character varying` | ✓ Yes | `'active'::character varying` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `name` | `character varying` | ✗ No | - |

## hr_fingerprint_transactions

**Total Columns:** 10

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `employee_id` | `character varying` | ✗ No | - |
| `name` | `character varying` | ✓ Yes | - |
| `branch_id` | `bigint` | ✗ No | - |
| `date` | `date` | ✗ No | - |
| `time` | `time without time zone` | ✗ No | - |
| `status` | `character varying` | ✗ No | - |
| `device_id` | `character varying` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `location` | `text` | ✓ Yes | - |

## hr_levels

**Total Columns:** 6

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `level_name_en` | `character varying` | ✗ No | - |
| `level_name_ar` | `character varying` | ✗ No | - |
| `level_order` | `integer` | ✗ No | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## hr_position_assignments

**Total Columns:** 9

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `employee_id` | `uuid` | ✗ No | - |
| `position_id` | `uuid` | ✗ No | - |
| `department_id` | `uuid` | ✗ No | - |
| `level_id` | `uuid` | ✗ No | - |
| `branch_id` | `bigint` | ✗ No | - |
| `effective_date` | `date` | ✗ No | `CURRENT_DATE` |
| `is_current` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## hr_position_reporting_template

**Total Columns:** 9

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `subordinate_position_id` | `uuid` | ✗ No | - |
| `manager_position_1` | `uuid` | ✓ Yes | - |
| `manager_position_2` | `uuid` | ✓ Yes | - |
| `manager_position_3` | `uuid` | ✓ Yes | - |
| `manager_position_4` | `uuid` | ✓ Yes | - |
| `manager_position_5` | `uuid` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## hr_positions

**Total Columns:** 7

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `position_title_en` | `character varying` | ✗ No | - |
| `position_title_ar` | `character varying` | ✗ No | - |
| `department_id` | `uuid` | ✗ No | - |
| `level_id` | `uuid` | ✗ No | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## hr_salary_components

**Total Columns:** 12

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `salary_id` | `uuid` | ✗ No | - |
| `employee_id` | `uuid` | ✗ No | - |
| `component_type` | `character varying` | ✗ No | - |
| `component_name` | `character varying` | ✗ No | - |
| `amount` | `numeric` | ✗ No | - |
| `is_enabled` | `boolean` | ✓ Yes | `true` |
| `application_type` | `character varying` | ✓ Yes | - |
| `single_month` | `character varying` | ✓ Yes | - |
| `start_month` | `character varying` | ✓ Yes | - |
| `end_month` | `character varying` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## hr_salary_wages

**Total Columns:** 7

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `employee_id` | `uuid` | ✗ No | - |
| `branch_id` | `uuid` | ✗ No | - |
| `basic_salary` | `numeric` | ✗ No | - |
| `effective_from` | `date` | ✗ No | - |
| `is_current` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## interface_permissions

**Total Columns:** 10

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `user_id` | `uuid` | ✗ No | - |
| `desktop_enabled` | `boolean` | ✗ No | `true` |
| `mobile_enabled` | `boolean` | ✗ No | `true` |
| `customer_enabled` | `boolean` | ✗ No | `false` |
| `updated_by` | `uuid` | ✗ No | - |
| `notes` | `text` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `cashier_enabled` | `boolean` | ✓ Yes | `false` |

## non_approved_payment_scheduler

**Total Columns:** 34

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `bigint` | ✗ No | `nextval('non_approved_payment_scheduler_id_seq'::regclass)` |
| `schedule_type` | `text` | ✗ No | - |
| `branch_id` | `bigint` | ✗ No | - |
| `branch_name` | `text` | ✗ No | - |
| `expense_category_id` | `bigint` | ✗ No | - |
| `expense_category_name_en` | `text` | ✓ Yes | - |
| `expense_category_name_ar` | `text` | ✓ Yes | - |
| `co_user_id` | `uuid` | ✓ Yes | - |
| `co_user_name` | `text` | ✓ Yes | - |
| `bill_type` | `text` | ✓ Yes | - |
| `bill_number` | `text` | ✓ Yes | - |
| `bill_date` | `date` | ✓ Yes | - |
| `payment_method` | `text` | ✓ Yes | - |
| `due_date` | `date` | ✓ Yes | - |
| `credit_period` | `integer` | ✓ Yes | - |
| `amount` | `numeric` | ✗ No | - |
| `bill_file_url` | `text` | ✓ Yes | - |
| `bank_name` | `text` | ✓ Yes | - |
| `iban` | `text` | ✓ Yes | - |
| `description` | `text` | ✓ Yes | - |
| `notes` | `text` | ✓ Yes | - |
| `recurring_type` | `text` | ✓ Yes | - |
| `recurring_metadata` | `jsonb` | ✓ Yes | - |
| `approver_id` | `uuid` | ✗ No | - |
| `approver_name` | `text` | ✗ No | - |
| `approval_status` | `text` | ✓ Yes | `'pending'::text` |
| `approved_at` | `timestamp with time zone` | ✓ Yes | - |
| `approved_by` | `uuid` | ✓ Yes | - |
| `rejection_reason` | `text` | ✓ Yes | - |
| `expense_scheduler_id` | `bigint` | ✓ Yes | - |
| `created_by` | `uuid` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_by` | `uuid` | ✓ Yes | - |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## notification_attachments

**Total Columns:** 8

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `notification_id` | `uuid` | ✗ No | - |
| `file_name` | `character varying` | ✗ No | - |
| `file_path` | `text` | ✗ No | - |
| `file_size` | `bigint` | ✗ No | - |
| `file_type` | `character varying` | ✗ No | - |
| `uploaded_by` | `character varying` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |

## notification_queue

**Total Columns:** 19

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `notification_id` | `uuid` | ✗ No | - |
| `user_id` | `uuid` | ✗ No | - |
| `device_id` | `character varying` | ✓ Yes | - |
| `push_subscription_id` | `uuid` | ✓ Yes | - |
| `status` | `character varying` | ✓ Yes | `'pending'::character varying` |
| `payload` | `jsonb` | ✗ No | - |
| `scheduled_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `sent_at` | `timestamp with time zone` | ✓ Yes | - |
| `delivered_at` | `timestamp with time zone` | ✓ Yes | - |
| `error_message` | `text` | ✓ Yes | - |
| `retry_count` | `integer` | ✓ Yes | `0` |
| `max_retries` | `integer` | ✓ Yes | `3` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `next_retry_at` | `timestamp with time zone` | ✓ Yes | - |
| `last_attempt_at` | `timestamp with time zone` | ✓ Yes | - |
| `renotification_at` | `timestamp with time zone` | ✓ Yes | - |
| `notification_priority` | `text` | ✓ Yes | `'normal'::text` |

## notification_read_states

**Total Columns:** 6

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `notification_id` | `uuid` | ✗ No | - |
| `user_id` | `text` | ✗ No | - |
| `read_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `is_read` | `boolean` | ✗ No | `false` |

## notification_recipients

**Total Columns:** 14

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `notification_id` | `uuid` | ✗ No | - |
| `role` | `character varying` | ✓ Yes | - |
| `branch_id` | `character varying` | ✓ Yes | - |
| `is_read` | `boolean` | ✗ No | `false` |
| `read_at` | `timestamp with time zone` | ✓ Yes | - |
| `is_dismissed` | `boolean` | ✗ No | `false` |
| `dismissed_at` | `timestamp with time zone` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `updated_at` | `timestamp with time zone` | ✗ No | `now()` |
| `delivery_status` | `character varying` | ✓ Yes | `'pending'::character varying` |
| `delivery_attempted_at` | `timestamp with time zone` | ✓ Yes | - |
| `error_message` | `text` | ✓ Yes | - |
| `user_id` | `uuid` | ✓ Yes | - |

## notifications

**Total Columns:** 25

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `title` | `character varying` | ✗ No | - |
| `message` | `text` | ✗ No | - |
| `created_by` | `character varying` | ✗ No | `'system'::character varying` |
| `created_by_name` | `character varying` | ✗ No | `'System'::character varying` |
| `created_by_role` | `character varying` | ✗ No | `'Admin'::character varying` |
| `target_users` | `jsonb` | ✓ Yes | - |
| `target_roles` | `jsonb` | ✓ Yes | - |
| `target_branches` | `jsonb` | ✓ Yes | - |
| `scheduled_for` | `timestamp with time zone` | ✓ Yes | - |
| `sent_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `expires_at` | `timestamp with time zone` | ✓ Yes | - |
| `has_attachments` | `boolean` | ✗ No | `false` |
| `read_count` | `integer` | ✗ No | `0` |
| `total_recipients` | `integer` | ✗ No | `0` |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `updated_at` | `timestamp with time zone` | ✗ No | `now()` |
| `deleted_at` | `timestamp with time zone` | ✓ Yes | - |
| `metadata` | `jsonb` | ✓ Yes | - |
| `task_id` | `uuid` | ✓ Yes | - |
| `task_assignment_id` | `uuid` | ✓ Yes | - |
| `priority` | `character varying` | ✗ No | `'medium'::character varying` |
| `status` | `character varying` | ✗ No | `'published'::character varying` |
| `target_type` | `character varying` | ✗ No | `'all_users'::character varying` |
| `type` | `character varying` | ✗ No | `'info'::character varying` |

## offer_bundles

**Total Columns:** 9

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `integer` | ✗ No | `nextval('offer_bundles_id_seq'::regclass)` |
| `offer_id` | `integer` | ✗ No | - |
| `bundle_name_ar` | `character varying` | ✗ No | - |
| `bundle_name_en` | `character varying` | ✗ No | - |
| `required_products` | `jsonb` | ✗ No | - |
| `discount_value` | `numeric` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `discount_type` | `character varying` | ✓ Yes | `'amount'::character varying` |

## offer_cart_tiers

**Total Columns:** 9

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `integer` | ✗ No | `nextval('offer_cart_tiers_id_seq'::regclass)` |
| `offer_id` | `integer` | ✗ No | - |
| `tier_number` | `integer` | ✗ No | - |
| `min_amount` | `numeric` | ✗ No | - |
| `max_amount` | `numeric` | ✓ Yes | - |
| `discount_type` | `character varying` | ✗ No | - |
| `discount_value` | `numeric` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## offer_products

**Total Columns:** 14

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `offer_id` | `integer` | ✗ No | - |
| `product_id` | `uuid` | ✗ No | - |
| `offer_qty` | `integer` | ✗ No | `1` |
| `offer_percentage` | `numeric` | ✓ Yes | - |
| `offer_price` | `numeric` | ✓ Yes | - |
| `max_uses` | `integer` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `is_part_of_variation_group` | `boolean` | ✗ No | `false` |
| `variation_group_id` | `uuid` | ✓ Yes | - |
| `variation_parent_barcode` | `text` | ✓ Yes | - |
| `added_by` | `uuid` | ✓ Yes | - |
| `added_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## offer_usage_logs

**Total Columns:** 11

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `integer` | ✗ No | `nextval('offer_usage_logs_id_seq'::regclass)` |
| `offer_id` | `integer` | ✗ No | - |
| `customer_id` | `uuid` | ✓ Yes | - |
| `order_id` | `integer` | ✓ Yes | - |
| `discount_applied` | `numeric` | ✗ No | - |
| `original_amount` | `numeric` | ✗ No | - |
| `final_amount` | `numeric` | ✗ No | - |
| `cart_items` | `jsonb` | ✓ Yes | - |
| `used_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `session_id` | `character varying` | ✓ Yes | `NULL::character varying` |
| `device_type` | `character varying` | ✓ Yes | `NULL::character varying` |

## offers

**Total Columns:** 20

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `integer` | ✗ No | `nextval('offers_id_seq'::regclass)` |
| `type` | `character varying` | ✗ No | - |
| `name_ar` | `character varying` | ✗ No | - |
| `name_en` | `character varying` | ✗ No | - |
| `description_ar` | `text` | ✓ Yes | - |
| `description_en` | `text` | ✓ Yes | - |
| `start_date` | `timestamp with time zone` | ✗ No | `now()` |
| `end_date` | `timestamp with time zone` | ✗ No | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `max_uses_per_customer` | `integer` | ✓ Yes | - |
| `max_total_uses` | `integer` | ✓ Yes | - |
| `current_total_uses` | `integer` | ✓ Yes | `0` |
| `branch_id` | `integer` | ✓ Yes | - |
| `service_type` | `character varying` | ✓ Yes | `'both'::character varying` |
| `show_on_product_page` | `boolean` | ✓ Yes | `true` |
| `show_in_carousel` | `boolean` | ✓ Yes | `false` |
| `send_push_notification` | `boolean` | ✓ Yes | `false` |
| `created_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## order_audit_logs

**Total Columns:** 18

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `order_id` | `uuid` | ✗ No | - |
| `action_type` | `character varying` | ✗ No | - |
| `from_status` | `character varying` | ✓ Yes | - |
| `to_status` | `character varying` | ✓ Yes | - |
| `performed_by` | `uuid` | ✓ Yes | - |
| `performed_by_name` | `character varying` | ✓ Yes | - |
| `performed_by_role` | `character varying` | ✓ Yes | - |
| `assigned_user_id` | `uuid` | ✓ Yes | - |
| `assigned_user_name` | `character varying` | ✓ Yes | - |
| `assignment_type` | `character varying` | ✓ Yes | - |
| `field_name` | `character varying` | ✓ Yes | - |
| `old_value` | `text` | ✓ Yes | - |
| `new_value` | `text` | ✓ Yes | - |
| `notes` | `text` | ✓ Yes | - |
| `ip_address` | `inet` | ✓ Yes | - |
| `user_agent` | `text` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |

## order_items

**Total Columns:** 34

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `order_id` | `uuid` | ✗ No | - |
| `product_id` | `uuid` | ✗ No | - |
| `product_name_ar` | `character varying` | ✗ No | - |
| `product_name_en` | `character varying` | ✗ No | - |
| `product_sku` | `character varying` | ✓ Yes | - |
| `unit_id` | `uuid` | ✓ Yes | - |
| `unit_name_ar` | `character varying` | ✓ Yes | - |
| `unit_name_en` | `character varying` | ✓ Yes | - |
| `unit_size` | `character varying` | ✓ Yes | - |
| `quantity` | `integer` | ✗ No | - |
| `unit_price` | `numeric` | ✗ No | - |
| `original_price` | `numeric` | ✗ No | - |
| `discount_amount` | `numeric` | ✗ No | `0` |
| `final_price` | `numeric` | ✗ No | - |
| `line_total` | `numeric` | ✗ No | - |
| `has_offer` | `boolean` | ✗ No | `false` |
| `offer_id` | `integer` | ✓ Yes | - |
| `offer_name_ar` | `character varying` | ✓ Yes | - |
| `offer_name_en` | `character varying` | ✓ Yes | - |
| `offer_type` | `character varying` | ✓ Yes | - |
| `offer_discount_percentage` | `numeric` | ✓ Yes | - |
| `offer_special_price` | `numeric` | ✓ Yes | - |
| `item_type` | `character varying` | ✗ No | `'regular'::character varying` |
| `bundle_id` | `uuid` | ✓ Yes | - |
| `bundle_name_ar` | `character varying` | ✓ Yes | - |
| `bundle_name_en` | `character varying` | ✓ Yes | - |
| `is_bundle_item` | `boolean` | ✗ No | `false` |
| `is_bogo_free` | `boolean` | ✗ No | `false` |
| `bogo_group_id` | `uuid` | ✓ Yes | - |
| `tax_rate` | `numeric` | ✗ No | `0` |
| `tax_amount` | `numeric` | ✗ No | `0` |
| `item_notes` | `text` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |

## orders

**Total Columns:** 40

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `order_number` | `character varying` | ✗ No | - |
| `customer_id` | `uuid` | ✗ No | - |
| `customer_name` | `character varying` | ✗ No | - |
| `customer_phone` | `character varying` | ✗ No | - |
| `customer_whatsapp` | `character varying` | ✓ Yes | - |
| `branch_id` | `bigint` | ✗ No | - |
| `selected_location` | `jsonb` | ✗ No | - |
| `order_status` | `character varying` | ✗ No | `'new'::character varying` |
| `fulfillment_method` | `character varying` | ✗ No | `'delivery'::character varying` |
| `subtotal_amount` | `numeric` | ✗ No | `0` |
| `delivery_fee` | `numeric` | ✗ No | `0` |
| `discount_amount` | `numeric` | ✗ No | `0` |
| `tax_amount` | `numeric` | ✗ No | `0` |
| `total_amount` | `numeric` | ✗ No | - |
| `payment_method` | `character varying` | ✗ No | - |
| `payment_status` | `character varying` | ✗ No | `'pending'::character varying` |
| `payment_reference` | `character varying` | ✓ Yes | - |
| `total_items` | `integer` | ✗ No | `0` |
| `total_quantity` | `integer` | ✗ No | `0` |
| `picker_id` | `uuid` | ✓ Yes | - |
| `picker_assigned_at` | `timestamp with time zone` | ✓ Yes | - |
| `delivery_person_id` | `uuid` | ✓ Yes | - |
| `delivery_assigned_at` | `timestamp with time zone` | ✓ Yes | - |
| `accepted_at` | `timestamp with time zone` | ✓ Yes | - |
| `ready_at` | `timestamp with time zone` | ✓ Yes | - |
| `delivered_at` | `timestamp with time zone` | ✓ Yes | - |
| `cancelled_at` | `timestamp with time zone` | ✓ Yes | - |
| `cancelled_by` | `uuid` | ✓ Yes | - |
| `cancellation_reason` | `text` | ✓ Yes | - |
| `customer_notes` | `text` | ✓ Yes | - |
| `admin_notes` | `text` | ✓ Yes | - |
| `estimated_pickup_time` | `timestamp with time zone` | ✓ Yes | - |
| `estimated_delivery_time` | `timestamp with time zone` | ✓ Yes | - |
| `actual_pickup_time` | `timestamp with time zone` | ✓ Yes | - |
| `actual_delivery_time` | `timestamp with time zone` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `updated_at` | `timestamp with time zone` | ✗ No | `now()` |
| `created_by` | `uuid` | ✓ Yes | - |
| `updated_by` | `uuid` | ✓ Yes | - |

## product_categories

**Total Columns:** 9

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `name_en` | `text` | ✗ No | - |
| `name_ar` | `text` | ✗ No | - |
| `image_url` | `text` | ✓ Yes | - |
| `display_order` | `integer` | ✓ Yes | `0` |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `uuid` | ✓ Yes | - |

## product_units

**Total Columns:** 7

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `name_en` | `text` | ✗ No | - |
| `name_ar` | `text` | ✗ No | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `uuid` | ✓ Yes | - |

## products

**Total Columns:** 29

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `product_serial` | `text` | ✗ No | - |
| `product_name_en` | `text` | ✗ No | - |
| `product_name_ar` | `text` | ✗ No | - |
| `category_id` | `uuid` | ✓ Yes | - |
| `category_name_en` | `text` | ✗ No | - |
| `category_name_ar` | `text` | ✗ No | - |
| `tax_category_id` | `uuid` | ✓ Yes | - |
| `tax_category_name_en` | `text` | ✗ No | - |
| `tax_category_name_ar` | `text` | ✗ No | - |
| `tax_percentage` | `numeric` | ✗ No | - |
| `unit_id` | `uuid` | ✓ Yes | - |
| `unit_name_en` | `text` | ✗ No | - |
| `unit_name_ar` | `text` | ✗ No | - |
| `unit_qty` | `numeric` | ✗ No | `1` |
| `barcode` | `text` | ✓ Yes | - |
| `sale_price` | `numeric` | ✗ No | - |
| `cost` | `numeric` | ✗ No | - |
| `profit` | `numeric` | ✗ No | - |
| `profit_percentage` | `numeric` | ✗ No | - |
| `current_stock` | `integer` | ✗ No | `0` |
| `minim_qty` | `integer` | ✗ No | `0` |
| `minimum_qty_alert` | `integer` | ✗ No | `0` |
| `maximum_qty` | `integer` | ✗ No | `0` |
| `image_url` | `text` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `uuid` | ✓ Yes | - |

## push_subscriptions

**Total Columns:** 14

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `user_id` | `uuid` | ✗ No | - |
| `device_id` | `character varying` | ✗ No | - |
| `endpoint` | `text` | ✗ No | - |
| `p256dh` | `text` | ✗ No | - |
| `auth` | `text` | ✗ No | - |
| `device_type` | `character varying` | ✗ No | - |
| `browser_name` | `character varying` | ✓ Yes | - |
| `user_agent` | `text` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `last_seen` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `session_id` | `text` | ✓ Yes | - |

## quick_task_assignments

**Total Columns:** 12

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `quick_task_id` | `uuid` | ✗ No | - |
| `assigned_to_user_id` | `uuid` | ✗ No | - |
| `status` | `character varying` | ✓ Yes | `'pending'::character varying` |
| `accepted_at` | `timestamp with time zone` | ✓ Yes | - |
| `started_at` | `timestamp with time zone` | ✓ Yes | - |
| `completed_at` | `timestamp with time zone` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `require_task_finished` | `boolean` | ✓ Yes | `true` |
| `require_photo_upload` | `boolean` | ✓ Yes | `false` |
| `require_erp_reference` | `boolean` | ✓ Yes | `false` |

## quick_task_comments

**Total Columns:** 6

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `quick_task_id` | `uuid` | ✗ No | - |
| `comment` | `text` | ✗ No | - |
| `comment_type` | `character varying` | ✓ Yes | `'comment'::character varying` |
| `created_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## quick_task_completions

**Total Columns:** 13

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `quick_task_id` | `uuid` | ✗ No | - |
| `assignment_id` | `uuid` | ✗ No | - |
| `completed_by_user_id` | `uuid` | ✗ No | - |
| `completion_notes` | `text` | ✓ Yes | - |
| `photo_path` | `text` | ✓ Yes | - |
| `erp_reference` | `character varying` | ✓ Yes | - |
| `completion_status` | `character varying` | ✗ No | `'submitted'::character varying` |
| `verified_by_user_id` | `uuid` | ✓ Yes | - |
| `verified_at` | `timestamp with time zone` | ✓ Yes | - |
| `verification_notes` | `text` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `updated_at` | `timestamp with time zone` | ✗ No | `now()` |

## quick_task_files

**Total Columns:** 10

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `quick_task_id` | `uuid` | ✗ No | - |
| `file_name` | `character varying` | ✗ No | - |
| `file_type` | `character varying` | ✓ Yes | - |
| `file_size` | `integer` | ✓ Yes | - |
| `mime_type` | `character varying` | ✓ Yes | - |
| `storage_path` | `text` | ✗ No | - |
| `storage_bucket` | `character varying` | ✓ Yes | `'quick-task-files'::character varying` |
| `uploaded_by` | `uuid` | ✓ Yes | - |
| `uploaded_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## quick_task_user_preferences

**Total Columns:** 9

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `user_id` | `uuid` | ✗ No | - |
| `default_branch_id` | `bigint` | ✓ Yes | - |
| `default_price_tag` | `character varying` | ✓ Yes | - |
| `default_issue_type` | `character varying` | ✓ Yes | - |
| `default_priority` | `character varying` | ✓ Yes | - |
| `selected_user_ids` | `ARRAY` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## quick_tasks

**Total Columns:** 17

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `title` | `character varying` | ✗ No | - |
| `description` | `text` | ✓ Yes | - |
| `price_tag` | `character varying` | ✓ Yes | - |
| `issue_type` | `character varying` | ✗ No | - |
| `priority` | `character varying` | ✗ No | - |
| `assigned_by` | `uuid` | ✗ No | - |
| `assigned_to_branch_id` | `bigint` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `deadline_datetime` | `timestamp with time zone` | ✓ Yes | `(now() + '24:00:00'::interval)` |
| `completed_at` | `timestamp with time zone` | ✓ Yes | - |
| `status` | `character varying` | ✓ Yes | `'pending'::character varying` |
| `created_from` | `character varying` | ✓ Yes | `'quick_task'::character varying` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `require_task_finished` | `boolean` | ✓ Yes | `true` |
| `require_photo_upload` | `boolean` | ✓ Yes | `false` |
| `require_erp_reference` | `boolean` | ✓ Yes | `false` |

## receiving_records

**Total Columns:** 56

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `user_id` | `uuid` | ✗ No | - |
| `branch_id` | `integer` | ✗ No | - |
| `vendor_id` | `integer` | ✗ No | - |
| `bill_date` | `date` | ✗ No | - |
| `bill_amount` | `numeric` | ✗ No | - |
| `bill_number` | `character varying` | ✓ Yes | - |
| `payment_method` | `character varying` | ✓ Yes | - |
| `credit_period` | `integer` | ✓ Yes | - |
| `due_date` | `date` | ✓ Yes | - |
| `bank_name` | `character varying` | ✓ Yes | - |
| `iban` | `character varying` | ✓ Yes | - |
| `vendor_vat_number` | `character varying` | ✓ Yes | - |
| `bill_vat_number` | `character varying` | ✓ Yes | - |
| `vat_numbers_match` | `boolean` | ✓ Yes | - |
| `vat_mismatch_reason` | `text` | ✓ Yes | - |
| `branch_manager_user_id` | `uuid` | ✓ Yes | - |
| `shelf_stocker_user_ids` | `ARRAY` | ✓ Yes | `'{}'::uuid[]` |
| `accountant_user_id` | `uuid` | ✓ Yes | - |
| `purchasing_manager_user_id` | `uuid` | ✓ Yes | - |
| `expired_return_amount` | `numeric` | ✓ Yes | `0` |
| `near_expiry_return_amount` | `numeric` | ✓ Yes | `0` |
| `over_stock_return_amount` | `numeric` | ✓ Yes | `0` |
| `damage_return_amount` | `numeric` | ✓ Yes | `0` |
| `total_return_amount` | `numeric` | ✓ Yes | `0` |
| `final_bill_amount` | `numeric` | ✓ Yes | `0` |
| `expired_erp_document_type` | `character varying` | ✓ Yes | - |
| `expired_erp_document_number` | `character varying` | ✓ Yes | - |
| `expired_vendor_document_number` | `character varying` | ✓ Yes | - |
| `near_expiry_erp_document_type` | `character varying` | ✓ Yes | - |
| `near_expiry_erp_document_number` | `character varying` | ✓ Yes | - |
| `near_expiry_vendor_document_number` | `character varying` | ✓ Yes | - |
| `over_stock_erp_document_type` | `character varying` | ✓ Yes | - |
| `over_stock_erp_document_number` | `character varying` | ✓ Yes | - |
| `over_stock_vendor_document_number` | `character varying` | ✓ Yes | - |
| `damage_erp_document_type` | `character varying` | ✓ Yes | - |
| `damage_erp_document_number` | `character varying` | ✓ Yes | - |
| `damage_vendor_document_number` | `character varying` | ✓ Yes | - |
| `has_expired_returns` | `boolean` | ✓ Yes | `false` |
| `has_near_expiry_returns` | `boolean` | ✓ Yes | `false` |
| `has_over_stock_returns` | `boolean` | ✓ Yes | `false` |
| `has_damage_returns` | `boolean` | ✓ Yes | `false` |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `inventory_manager_user_id` | `uuid` | ✓ Yes | - |
| `night_supervisor_user_ids` | `ARRAY` | ✓ Yes | `'{}'::uuid[]` |
| `warehouse_handler_user_ids` | `ARRAY` | ✓ Yes | `'{}'::uuid[]` |
| `certificate_url` | `text` | ✓ Yes | - |
| `certificate_generated_at` | `timestamp with time zone` | ✓ Yes | - |
| `certificate_file_name` | `text` | ✓ Yes | - |
| `original_bill_url` | `text` | ✓ Yes | - |
| `erp_purchase_invoice_reference` | `character varying` | ✓ Yes | - |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `pr_excel_file_url` | `text` | ✓ Yes | - |
| `erp_purchase_invoice_uploaded` | `boolean` | ✓ Yes | `false` |
| `pr_excel_file_uploaded` | `boolean` | ✓ Yes | `false` |
| `original_bill_uploaded` | `boolean` | ✓ Yes | `false` |

## receiving_task_templates

**Total Columns:** 13

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `role_type` | `character varying` | ✗ No | - |
| `title_template` | `text` | ✗ No | - |
| `description_template` | `text` | ✗ No | - |
| `require_erp_reference` | `boolean` | ✗ No | `false` |
| `require_original_bill_upload` | `boolean` | ✗ No | `false` |
| `require_task_finished_mark` | `boolean` | ✗ No | `true` |
| `priority` | `character varying` | ✗ No | `'high'::character varying` |
| `deadline_hours` | `integer` | ✗ No | `24` |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `updated_at` | `timestamp with time zone` | ✗ No | `now()` |
| `depends_on_role_types` | `ARRAY` | ✓ Yes | `'{}'::text[]` |
| `require_photo_upload` | `boolean` | ✓ Yes | `false` |

## receiving_tasks

**Total Columns:** 26

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `receiving_record_id` | `uuid` | ✗ No | - |
| `role_type` | `character varying` | ✗ No | - |
| `assigned_user_id` | `uuid` | ✓ Yes | - |
| `requires_erp_reference` | `boolean` | ✓ Yes | `false` |
| `requires_original_bill_upload` | `boolean` | ✓ Yes | `false` |
| `requires_reassignment` | `boolean` | ✓ Yes | `false` |
| `requires_task_finished_mark` | `boolean` | ✓ Yes | `true` |
| `erp_reference_number` | `character varying` | ✓ Yes | - |
| `original_bill_uploaded` | `boolean` | ✓ Yes | `false` |
| `original_bill_file_path` | `text` | ✓ Yes | - |
| `task_completed` | `boolean` | ✓ Yes | `false` |
| `completed_at` | `timestamp with time zone` | ✓ Yes | - |
| `clearance_certificate_url` | `text` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `updated_at` | `timestamp with time zone` | ✗ No | `now()` |
| `template_id` | `uuid` | ✓ Yes | - |
| `task_status` | `character varying` | ✗ No | `'pending'::character varying` |
| `title` | `text` | ✓ Yes | - |
| `description` | `text` | ✓ Yes | - |
| `priority` | `character varying` | ✓ Yes | `'high'::character varying` |
| `due_date` | `timestamp with time zone` | ✓ Yes | - |
| `completed_by_user_id` | `uuid` | ✓ Yes | - |
| `completion_photo_url` | `text` | ✓ Yes | - |
| `completion_notes` | `text` | ✓ Yes | - |
| `rule_effective_date` | `timestamp with time zone` | ✓ Yes | - |

## recurring_assignment_schedules

**Total Columns:** 19

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `assignment_id` | `uuid` | ✗ No | - |
| `repeat_type` | `text` | ✗ No | - |
| `repeat_interval` | `integer` | ✗ No | `1` |
| `repeat_on_days` | `ARRAY` | ✓ Yes | - |
| `repeat_on_date` | `integer` | ✓ Yes | - |
| `repeat_on_month` | `integer` | ✓ Yes | - |
| `execute_time` | `time without time zone` | ✗ No | `'09:00:00'::time without time zone` |
| `timezone` | `text` | ✓ Yes | `'UTC'::text` |
| `start_date` | `date` | ✗ No | - |
| `end_date` | `date` | ✓ Yes | - |
| `max_occurrences` | `integer` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `last_executed_at` | `timestamp with time zone` | ✓ Yes | - |
| `next_execution_at` | `timestamp with time zone` | ✗ No | - |
| `executions_count` | `integer` | ✓ Yes | `0` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `text` | ✗ No | - |

## recurring_schedule_check_log

**Total Columns:** 5

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `integer` | ✗ No | `nextval('recurring_schedule_check_log_id_seq'::regclass)` |
| `check_date` | `date` | ✗ No | `CURRENT_DATE` |
| `schedules_checked` | `integer` | ✓ Yes | `0` |
| `notifications_sent` | `integer` | ✓ Yes | `0` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## requesters

**Total Columns:** 8

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `requester_id` | `character varying` | ✗ No | - |
| `requester_name` | `character varying` | ✗ No | - |
| `contact_number` | `character varying` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `timezone('utc'::text, now())` |
| `updated_at` | `timestamp with time zone` | ✗ No | `timezone('utc'::text, now())` |
| `created_by` | `uuid` | ✓ Yes | - |
| `updated_by` | `uuid` | ✓ Yes | - |

## role_permissions

**Total Columns:** 10

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `role_id` | `uuid` | ✗ No | - |
| `function_id` | `uuid` | ✗ No | - |
| `can_view` | `boolean` | ✓ Yes | `false` |
| `can_add` | `boolean` | ✓ Yes | `false` |
| `can_edit` | `boolean` | ✓ Yes | `false` |
| `can_delete` | `boolean` | ✓ Yes | `false` |
| `can_export` | `boolean` | ✓ Yes | `false` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## shelf_paper_templates

**Total Columns:** 10

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `name` | `text` | ✗ No | - |
| `description` | `text` | ✓ Yes | - |
| `template_image_url` | `text` | ✗ No | - |
| `field_configuration` | `jsonb` | ✗ No | `'[]'::jsonb` |
| `created_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |
| `updated_at` | `timestamp with time zone` | ✗ No | `now()` |
| `is_active` | `boolean` | ✗ No | `true` |
| `metadata` | `jsonb` | ✓ Yes | - |

## task_assignments

**Total Columns:** 27

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `task_id` | `uuid` | ✗ No | - |
| `assignment_type` | `text` | ✗ No | - |
| `assigned_to_user_id` | `uuid` | ✓ Yes | - |
| `assigned_to_branch_id` | `bigint` | ✓ Yes | - |
| `assigned_by` | `uuid` | ✗ No | - |
| `assigned_by_name` | `text` | ✓ Yes | - |
| `assigned_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `status` | `text` | ✓ Yes | `'assigned'::text` |
| `started_at` | `timestamp with time zone` | ✓ Yes | - |
| `completed_at` | `timestamp with time zone` | ✓ Yes | - |
| `schedule_date` | `date` | ✓ Yes | - |
| `schedule_time` | `time without time zone` | ✓ Yes | - |
| `deadline_date` | `date` | ✓ Yes | - |
| `deadline_time` | `time without time zone` | ✓ Yes | - |
| `deadline_datetime` | `timestamp with time zone` | ✓ Yes | - |
| `is_reassignable` | `boolean` | ✓ Yes | `true` |
| `is_recurring` | `boolean` | ✓ Yes | `false` |
| `recurring_pattern` | `jsonb` | ✓ Yes | - |
| `notes` | `text` | ✓ Yes | - |
| `priority_override` | `text` | ✓ Yes | - |
| `require_task_finished` | `boolean` | ✓ Yes | `true` |
| `require_photo_upload` | `boolean` | ✓ Yes | `false` |
| `require_erp_reference` | `boolean` | ✓ Yes | `false` |
| `reassigned_from` | `uuid` | ✓ Yes | - |
| `reassignment_reason` | `text` | ✓ Yes | - |
| `reassigned_at` | `timestamp with time zone` | ✓ Yes | - |

## task_completions

**Total Columns:** 17

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `task_id` | `uuid` | ✗ No | - |
| `assignment_id` | `uuid` | ✗ No | - |
| `completed_by` | `text` | ✗ No | - |
| `completed_by_name` | `text` | ✓ Yes | - |
| `completed_by_branch_id` | `uuid` | ✓ Yes | - |
| `task_finished_completed` | `boolean` | ✓ Yes | `false` |
| `photo_uploaded_completed` | `boolean` | ✓ Yes | `false` |
| `erp_reference_completed` | `boolean` | ✓ Yes | `false` |
| `erp_reference_number` | `text` | ✓ Yes | - |
| `completion_notes` | `text` | ✓ Yes | - |
| `verified_by` | `text` | ✓ Yes | - |
| `verified_at` | `timestamp with time zone` | ✓ Yes | - |
| `verification_notes` | `text` | ✓ Yes | - |
| `completed_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `completion_photo_url` | `text` | ✓ Yes | - |

## task_images

**Total Columns:** 14

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `task_id` | `uuid` | ✗ No | - |
| `file_name` | `text` | ✗ No | - |
| `file_size` | `bigint` | ✗ No | - |
| `file_type` | `text` | ✗ No | - |
| `file_url` | `text` | ✗ No | - |
| `image_type` | `text` | ✗ No | - |
| `uploaded_by` | `text` | ✗ No | - |
| `uploaded_by_name` | `text` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `image_width` | `integer` | ✓ Yes | - |
| `image_height` | `integer` | ✓ Yes | - |
| `file_path` | `text` | ✓ Yes | - |
| `attachment_type` | `text` | ✓ Yes | `'task_creation'::text` |

## task_reminder_logs

**Total Columns:** 11

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `task_assignment_id` | `uuid` | ✓ Yes | - |
| `quick_task_assignment_id` | `uuid` | ✓ Yes | - |
| `task_title` | `text` | ✗ No | - |
| `assigned_to_user_id` | `uuid` | ✓ Yes | - |
| `deadline` | `timestamp with time zone` | ✗ No | - |
| `hours_overdue` | `numeric` | ✓ Yes | - |
| `reminder_sent_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `notification_id` | `uuid` | ✓ Yes | - |
| `status` | `text` | ✓ Yes | `'sent'::text` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## tasks

**Total Columns:** 21

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `title` | `text` | ✗ No | - |
| `description` | `text` | ✓ Yes | - |
| `require_task_finished` | `boolean` | ✓ Yes | `false` |
| `require_photo_upload` | `boolean` | ✓ Yes | `false` |
| `require_erp_reference` | `boolean` | ✓ Yes | `false` |
| `can_escalate` | `boolean` | ✓ Yes | `false` |
| `can_reassign` | `boolean` | ✓ Yes | `false` |
| `created_by` | `text` | ✗ No | - |
| `created_by_name` | `text` | ✓ Yes | - |
| `created_by_role` | `text` | ✓ Yes | - |
| `status` | `text` | ✓ Yes | `'draft'::text` |
| `priority` | `text` | ✓ Yes | `'medium'::text` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `deleted_at` | `timestamp with time zone` | ✓ Yes | - |
| `due_date` | `date` | ✓ Yes | - |
| `due_time` | `time without time zone` | ✓ Yes | - |
| `due_datetime` | `timestamp with time zone` | ✓ Yes | - |
| `search_vector` | `tsvector` | ✓ Yes | - |
| `metadata` | `jsonb` | ✓ Yes | - |

## tax_categories

**Total Columns:** 8

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `name_en` | `text` | ✗ No | - |
| `name_ar` | `text` | ✗ No | - |
| `percentage` | `numeric` | ✗ No | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `uuid` | ✓ Yes | - |

## user_audit_logs

**Total Columns:** 12

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `user_id` | `uuid` | ✓ Yes | - |
| `target_user_id` | `uuid` | ✓ Yes | - |
| `action` | `character varying` | ✗ No | - |
| `table_name` | `character varying` | ✓ Yes | - |
| `record_id` | `uuid` | ✓ Yes | - |
| `old_values` | `jsonb` | ✓ Yes | - |
| `new_values` | `jsonb` | ✓ Yes | - |
| `ip_address` | `inet` | ✓ Yes | - |
| `user_agent` | `text` | ✓ Yes | - |
| `performed_by` | `uuid` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## user_device_sessions

**Total Columns:** 14

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `user_id` | `uuid` | ✗ No | - |
| `device_id` | `character varying` | ✗ No | - |
| `session_token` | `character varying` | ✗ No | - |
| `device_type` | `character varying` | ✗ No | - |
| `browser_name` | `character varying` | ✓ Yes | - |
| `user_agent` | `text` | ✓ Yes | - |
| `ip_address` | `inet` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `login_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `last_activity` | `timestamp with time zone` | ✓ Yes | `now()` |
| `expires_at` | `timestamp with time zone` | ✓ Yes | `(now() + '24:00:00'::interval)` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## user_password_history

**Total Columns:** 5

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `user_id` | `uuid` | ✗ No | - |
| `password_hash` | `character varying` | ✗ No | - |
| `salt` | `character varying` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |

## user_roles

**Total Columns:** 10

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `role_name` | `character varying` | ✗ No | - |
| `role_code` | `character varying` | ✗ No | - |
| `description` | `text` | ✓ Yes | - |
| `is_system_role` | `boolean` | ✓ Yes | `false` |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `uuid` | ✓ Yes | - |
| `updated_by` | `uuid` | ✓ Yes | - |

## user_sessions

**Total Columns:** 10

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `user_id` | `uuid` | ✗ No | - |
| `session_token` | `character varying` | ✗ No | - |
| `login_method` | `character varying` | ✗ No | - |
| `ip_address` | `inet` | ✓ Yes | - |
| `user_agent` | `text` | ✓ Yes | - |
| `is_active` | `boolean` | ✓ Yes | `true` |
| `expires_at` | `timestamp with time zone` | ✗ No | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `ended_at` | `timestamp with time zone` | ✓ Yes | - |

## users

**Total Columns:** 28

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `uuid_generate_v4()` |
| `username` | `character varying` | ✗ No | - |
| `password_hash` | `character varying` | ✗ No | - |
| `salt` | `character varying` | ✗ No | - |
| `quick_access_code` | `character varying` | ✗ No | - |
| `quick_access_salt` | `character varying` | ✗ No | - |
| `user_type` | `USER-DEFINED` | ✗ No | `'branch_specific'::user_type_enum` |
| `employee_id` | `uuid` | ✓ Yes | - |
| `branch_id` | `bigint` | ✓ Yes | - |
| `role_type` | `USER-DEFINED` | ✓ Yes | `'Position-based'::role_type_enum` |
| `position_id` | `uuid` | ✓ Yes | - |
| `avatar` | `text` | ✓ Yes | - |
| `avatar_small_url` | `text` | ✓ Yes | - |
| `avatar_medium_url` | `text` | ✓ Yes | - |
| `avatar_large_url` | `text` | ✓ Yes | - |
| `is_first_login` | `boolean` | ✓ Yes | `true` |
| `failed_login_attempts` | `integer` | ✓ Yes | `0` |
| `locked_at` | `timestamp with time zone` | ✓ Yes | - |
| `locked_by` | `uuid` | ✓ Yes | - |
| `last_login_at` | `timestamp with time zone` | ✓ Yes | - |
| `password_expires_at` | `timestamp with time zone` | ✓ Yes | - |
| `last_password_change` | `timestamp with time zone` | ✓ Yes | `now()` |
| `created_by` | `bigint` | ✓ Yes | - |
| `updated_by` | `bigint` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp with time zone` | ✓ Yes | `now()` |
| `status` | `character varying` | ✗ No | `'active'::character varying` |
| `ai_translation_enabled` | `boolean` | ✗ No | `false` |

## variation_audit_log

**Total Columns:** 11

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `action_type` | `text` | ✗ No | - |
| `variation_group_id` | `uuid` | ✓ Yes | - |
| `affected_barcodes` | `ARRAY` | ✓ Yes | - |
| `parent_barcode` | `text` | ✓ Yes | - |
| `group_name_en` | `text` | ✓ Yes | - |
| `group_name_ar` | `text` | ✓ Yes | - |
| `user_id` | `uuid` | ✓ Yes | - |
| `timestamp` | `timestamp with time zone` | ✗ No | `now()` |
| `details` | `jsonb` | ✓ Yes | - |
| `created_at` | `timestamp with time zone` | ✗ No | `now()` |

## vendor_payment_schedule

**Total Columns:** 56

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `id` | `uuid` | ✗ No | `gen_random_uuid()` |
| `receiving_record_id` | `uuid` | ✓ Yes | - |
| `bill_number` | `character varying` | ✓ Yes | - |
| `vendor_id` | `character varying` | ✓ Yes | - |
| `vendor_name` | `character varying` | ✓ Yes | - |
| `branch_id` | `integer` | ✓ Yes | - |
| `branch_name` | `character varying` | ✓ Yes | - |
| `bill_date` | `date` | ✓ Yes | - |
| `bill_amount` | `numeric` | ✓ Yes | - |
| `final_bill_amount` | `numeric` | ✓ Yes | - |
| `payment_method` | `character varying` | ✓ Yes | - |
| `bank_name` | `character varying` | ✓ Yes | - |
| `iban` | `character varying` | ✓ Yes | - |
| `due_date` | `date` | ✓ Yes | - |
| `credit_period` | `integer` | ✓ Yes | - |
| `vat_number` | `character varying` | ✓ Yes | - |
| `scheduled_date` | `timestamp without time zone` | ✓ Yes | `now()` |
| `paid_date` | `timestamp without time zone` | ✓ Yes | - |
| `notes` | `text` | ✓ Yes | - |
| `created_at` | `timestamp without time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp without time zone` | ✓ Yes | `now()` |
| `original_due_date` | `date` | ✓ Yes | - |
| `original_bill_amount` | `numeric` | ✓ Yes | - |
| `original_final_amount` | `numeric` | ✓ Yes | - |
| `is_paid` | `boolean` | ✓ Yes | `false` |
| `payment_reference` | `character varying` | ✓ Yes | - |
| `task_id` | `uuid` | ✓ Yes | - |
| `task_assignment_id` | `uuid` | ✓ Yes | - |
| `receiver_user_id` | `uuid` | ✓ Yes | - |
| `accountant_user_id` | `uuid` | ✓ Yes | - |
| `verification_status` | `text` | ✓ Yes | `'pending'::text` |
| `verified_by` | `uuid` | ✓ Yes | - |
| `verified_date` | `timestamp with time zone` | ✓ Yes | - |
| `transaction_date` | `timestamp with time zone` | ✓ Yes | - |
| `original_bill_url` | `text` | ✓ Yes | - |
| `created_by` | `uuid` | ✓ Yes | - |
| `pr_excel_verified` | `boolean` | ✓ Yes | `false` |
| `pr_excel_verified_by` | `uuid` | ✓ Yes | - |
| `pr_excel_verified_date` | `timestamp with time zone` | ✓ Yes | - |
| `discount_amount` | `numeric` | ✓ Yes | `0` |
| `discount_notes` | `text` | ✓ Yes | - |
| `grr_amount` | `numeric` | ✓ Yes | `0` |
| `grr_reference_number` | `text` | ✓ Yes | - |
| `grr_notes` | `text` | ✓ Yes | - |
| `pri_amount` | `numeric` | ✓ Yes | `0` |
| `pri_reference_number` | `text` | ✓ Yes | - |
| `pri_notes` | `text` | ✓ Yes | - |
| `last_adjustment_date` | `timestamp with time zone` | ✓ Yes | - |
| `last_adjusted_by` | `uuid` | ✓ Yes | - |
| `adjustment_history` | `jsonb` | ✓ Yes | `'[]'::jsonb` |
| `approval_status` | `text` | ✗ No | `'pending'::text` |
| `approval_requested_by` | `uuid` | ✓ Yes | - |
| `approval_requested_at` | `timestamp with time zone` | ✓ Yes | - |
| `approved_by` | `uuid` | ✓ Yes | - |
| `approved_at` | `timestamp with time zone` | ✓ Yes | - |
| `approval_notes` | `text` | ✓ Yes | - |

## vendors

**Total Columns:** 34

| Column Name | Data Type | Nullable | Default |
|---|---|---|---|
| `erp_vendor_id` | `integer` | ✗ No | - |
| `vendor_name` | `text` | ✗ No | - |
| `salesman_name` | `text` | ✓ Yes | - |
| `salesman_contact` | `text` | ✓ Yes | - |
| `supervisor_name` | `text` | ✓ Yes | - |
| `supervisor_contact` | `text` | ✓ Yes | - |
| `vendor_contact_number` | `text` | ✓ Yes | - |
| `payment_method` | `text` | ✓ Yes | - |
| `credit_period` | `integer` | ✓ Yes | - |
| `bank_name` | `text` | ✓ Yes | - |
| `iban` | `text` | ✓ Yes | - |
| `status` | `text` | ✓ Yes | `'Active'::text` |
| `last_visit` | `timestamp without time zone` | ✓ Yes | - |
| `categories` | `ARRAY` | ✓ Yes | - |
| `delivery_modes` | `ARRAY` | ✓ Yes | - |
| `place` | `text` | ✓ Yes | - |
| `location_link` | `text` | ✓ Yes | - |
| `return_expired_products` | `text` | ✓ Yes | - |
| `return_expired_products_note` | `text` | ✓ Yes | - |
| `return_near_expiry_products` | `text` | ✓ Yes | - |
| `return_near_expiry_products_note` | `text` | ✓ Yes | - |
| `return_over_stock` | `text` | ✓ Yes | - |
| `return_over_stock_note` | `text` | ✓ Yes | - |
| `return_damage_products` | `text` | ✓ Yes | - |
| `return_damage_products_note` | `text` | ✓ Yes | - |
| `no_return` | `boolean` | ✓ Yes | `false` |
| `no_return_note` | `text` | ✓ Yes | - |
| `vat_applicable` | `text` | ✓ Yes | `'VAT Applicable'::text` |
| `vat_number` | `text` | ✓ Yes | - |
| `no_vat_note` | `text` | ✓ Yes | - |
| `created_at` | `timestamp without time zone` | ✓ Yes | `now()` |
| `updated_at` | `timestamp without time zone` | ✓ Yes | `now()` |
| `branch_id` | `bigint` | ✗ No | - |
| `payment_priority` | `text` | ✓ Yes | `'Normal'::text` |

