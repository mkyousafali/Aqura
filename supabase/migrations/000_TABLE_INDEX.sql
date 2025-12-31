-- Database Schema Reference - All 88 Tables
-- This file lists all tables in the Aqura database

/*
TABLE LISTING (88 Total):

1. approval_permissions - User approval permissions for requisitions and bills
2. biometric_connections - Biometric device connections
3. bogo_offer_rules - Buy One Get One offer rules
4. branches - Business branch locations
5. button_main_sections - Main sidebar button sections
6. button_permissions - User permissions for buttons
7. button_sub_sections - Sub-sections under main button sections
8. coupon_campaigns - Coupon campaign definitions
9. coupon_claims - Customer coupon claims
10. coupon_eligible_customers - Customers eligible for coupons
11. coupon_products - Products in coupon campaigns
12. customer_access_code_history - History of customer access code changes
13. customer_app_media - Media content for customer app
14. customer_recovery_requests - Customer account recovery requests
15. customers - Customer profiles
16. deleted_bundle_offers - Archive of deleted bundle offers
17. delivery_fee_tiers - Delivery cost tiers based on order amount
18. delivery_service_settings - Global delivery service configuration
19. employee_fine_payments - Records of paid employee fines
20. employee_warning_history - Audit trail of warning changes
21. employee_warnings - Employee disciplinary warnings
22. erp_connections - ERP system connection details
23. erp_daily_sales - Daily sales summaries from ERP
24. expense_parent_categories - Top-level expense categories
25. expense_requisitions - Employee expense requests
26. expense_scheduler - Scheduled expense payments
27. expense_sub_categories - Sub-categories under parent expense categories
28. flyer_offer_products - Products in promotional flyers
29. flyer_offers - Flyer/promotion definitions
30. flyer_templates - Email flyer templates
31. hr_departments - HR department definitions
32. hr_employee_contacts - Employee contact information
33. hr_employee_documents - Employee documents (passports, IDs, etc.)
34. hr_employees - Employee records
35. hr_fingerprint_transactions - Biometric fingerprint check-in/out
36. hr_levels - Employee position levels
37. hr_position_assignments - Current position assignments
38. hr_position_reporting_template - Reporting structure templates
39. hr_positions - Job position definitions
40. hr_salary_components - Salary component definitions
41. hr_salary_wages - Employee wage records
42. interface_permissions - User access to application interfaces
43. non_approved_payment_scheduler - Payments awaiting approval
44. notification_attachments - Files attached to notifications
45. notification_read_states - Read status of notifications
46. notification_recipients - Recipients of notifications
47. notifications - System notification messages
48. offer_bundles - Bundle discounts for products
49. offer_cart_tiers - Cart-based tiered discounts
50. offer_products - Products participating in offers
51. offer_usage_logs - Log of offer usage
52. offers - Promotional offers
53. order_audit_logs - Audit trail of order changes
54. order_items - Individual items in orders
55. orders - Customer orders
56. privilege_cards_branch - Branch-specific privilege cards
57. privilege_cards_master - Master privilege card records
58. product_categories - Product category classifications
59. product_units - Product measurement units
60. products - Product catalog
61. quick_task_assignments - Quick task assignments to users
62. quick_task_comments - Comments on quick tasks
63. quick_task_completions - Completion records for quick tasks
64. quick_task_files - Files uploaded for quick tasks
65. quick_task_user_preferences - User preferences for quick tasks
66. quick_tasks - Quick task definitions
67. receiving_records - Purchase order receiving records
68. receiving_task_templates - Templates for receiving tasks
69. receiving_tasks - Individual receiving task assignments
70. recurring_assignment_schedules - Recurring task schedules
71. recurring_schedule_check_log - Log of schedule checks
72. requesters - External requester profiles
73. shelf_paper_templates - Shelf label print templates
74. sidebar_buttons - Sidebar navigation buttons
75. task_assignments - Task assignments to users
76. task_completions - Task completion records
77. task_images - Images attached to tasks
78. task_reminder_logs - Reminder notification logs
79. tasks - Task definitions
80. user_audit_logs - User action audit logs
81. user_device_sessions - Device session tracking
82. user_password_history - Password change history
83. user_sessions - User login sessions
84. users - System users
85. variation_audit_log - Product variation changes
86. vendor_payment_schedule - Vendor payment schedule
87. vendors - Vendor/supplier information
88. view_offer - Visual offer displays

Each table has an individual migration file for reference.
*/
