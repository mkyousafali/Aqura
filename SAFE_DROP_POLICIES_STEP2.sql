-- STEP 2: DROP ALL EXISTING POLICIES AND CREATE UNIVERSAL POLICIES
-- Run this AFTER Step 1 completes

-- Drop all existing policies first
DROP POLICY IF EXISTS "allow_select" ON app_functions;
DROP POLICY IF EXISTS "allow_insert" ON app_functions;
DROP POLICY IF EXISTS "allow_update" ON app_functions;
DROP POLICY IF EXISTS "allow_delete" ON app_functions;

DROP POLICY IF EXISTS "allow_select" ON approval_permissions;
DROP POLICY IF EXISTS "allow_insert" ON approval_permissions;
DROP POLICY IF EXISTS "allow_update" ON approval_permissions;
DROP POLICY IF EXISTS "allow_delete" ON approval_permissions;

DROP POLICY IF EXISTS "allow_select" ON biometric_connections;
DROP POLICY IF EXISTS "allow_insert" ON biometric_connections;
DROP POLICY IF EXISTS "allow_update" ON biometric_connections;
DROP POLICY IF EXISTS "allow_delete" ON biometric_connections;

DROP POLICY IF EXISTS "allow_select" ON bogo_offer_rules;
DROP POLICY IF EXISTS "allow_insert" ON bogo_offer_rules;
DROP POLICY IF EXISTS "allow_update" ON bogo_offer_rules;
DROP POLICY IF EXISTS "allow_delete" ON bogo_offer_rules;

DROP POLICY IF EXISTS "allow_select" ON branches;
DROP POLICY IF EXISTS "allow_insert" ON branches;
DROP POLICY IF EXISTS "allow_update" ON branches;
DROP POLICY IF EXISTS "allow_delete" ON branches;

DROP POLICY IF EXISTS "allow_select" ON coupon_campaigns;
DROP POLICY IF EXISTS "allow_insert" ON coupon_campaigns;
DROP POLICY IF EXISTS "allow_update" ON coupon_campaigns;
DROP POLICY IF EXISTS "allow_delete" ON coupon_campaigns;

DROP POLICY IF EXISTS "allow_select" ON coupon_claims;
DROP POLICY IF EXISTS "allow_insert" ON coupon_claims;
DROP POLICY IF EXISTS "allow_update" ON coupon_claims;
DROP POLICY IF EXISTS "allow_delete" ON coupon_claims;

DROP POLICY IF EXISTS "allow_select" ON coupon_eligible_customers;
DROP POLICY IF EXISTS "allow_insert" ON coupon_eligible_customers;
DROP POLICY IF EXISTS "allow_update" ON coupon_eligible_customers;
DROP POLICY IF EXISTS "allow_delete" ON coupon_eligible_customers;

DROP POLICY IF EXISTS "allow_select" ON coupon_products;
DROP POLICY IF EXISTS "allow_insert" ON coupon_products;
DROP POLICY IF EXISTS "allow_update" ON coupon_products;
DROP POLICY IF EXISTS "allow_delete" ON coupon_products;

DROP POLICY IF EXISTS "allow_select" ON customer_access_code_history;
DROP POLICY IF EXISTS "allow_insert" ON customer_access_code_history;
DROP POLICY IF EXISTS "allow_update" ON customer_access_code_history;
DROP POLICY IF EXISTS "allow_delete" ON customer_access_code_history;

DROP POLICY IF EXISTS "allow_select" ON customer_app_media;
DROP POLICY IF EXISTS "allow_insert" ON customer_app_media;
DROP POLICY IF EXISTS "allow_update" ON customer_app_media;
DROP POLICY IF EXISTS "allow_delete" ON customer_app_media;

DROP POLICY IF EXISTS "allow_select" ON customer_recovery_requests;
DROP POLICY IF EXISTS "allow_insert" ON customer_recovery_requests;
DROP POLICY IF EXISTS "allow_update" ON customer_recovery_requests;
DROP POLICY IF EXISTS "allow_delete" ON customer_recovery_requests;

DROP POLICY IF EXISTS "allow_select" ON customers;
DROP POLICY IF EXISTS "allow_insert" ON customers;
DROP POLICY IF EXISTS "allow_update" ON customers;
DROP POLICY IF EXISTS "allow_delete" ON customers;

DROP POLICY IF EXISTS "allow_select" ON deleted_bundle_offers;
DROP POLICY IF EXISTS "allow_insert" ON deleted_bundle_offers;
DROP POLICY IF EXISTS "allow_update" ON deleted_bundle_offers;
DROP POLICY IF EXISTS "allow_delete" ON deleted_bundle_offers;

DROP POLICY IF EXISTS "allow_select" ON delivery_fee_tiers;
DROP POLICY IF EXISTS "allow_insert" ON delivery_fee_tiers;
DROP POLICY IF EXISTS "allow_update" ON delivery_fee_tiers;
DROP POLICY IF EXISTS "allow_delete" ON delivery_fee_tiers;

DROP POLICY IF EXISTS "allow_select" ON delivery_service_settings;
DROP POLICY IF EXISTS "allow_insert" ON delivery_service_settings;
DROP POLICY IF EXISTS "allow_update" ON delivery_service_settings;
DROP POLICY IF EXISTS "allow_delete" ON delivery_service_settings;

DROP POLICY IF EXISTS "allow_select" ON employee_fine_payments;
DROP POLICY IF EXISTS "allow_insert" ON employee_fine_payments;
DROP POLICY IF EXISTS "allow_update" ON employee_fine_payments;
DROP POLICY IF EXISTS "allow_delete" ON employee_fine_payments;

DROP POLICY IF EXISTS "allow_select" ON employee_warning_history;
DROP POLICY IF EXISTS "allow_insert" ON employee_warning_history;
DROP POLICY IF EXISTS "allow_update" ON employee_warning_history;
DROP POLICY IF EXISTS "allow_delete" ON employee_warning_history;

DROP POLICY IF EXISTS "allow_select" ON employee_warnings;
DROP POLICY IF EXISTS "allow_insert" ON employee_warnings;
DROP POLICY IF EXISTS "allow_update" ON employee_warnings;
DROP POLICY IF EXISTS "allow_delete" ON employee_warnings;

DROP POLICY IF EXISTS "allow_select" ON erp_connections;
DROP POLICY IF EXISTS "allow_insert" ON erp_connections;
DROP POLICY IF EXISTS "allow_update" ON erp_connections;
DROP POLICY IF EXISTS "allow_delete" ON erp_connections;

DROP POLICY IF EXISTS "allow_select" ON erp_daily_sales;
DROP POLICY IF EXISTS "allow_insert" ON erp_daily_sales;
DROP POLICY IF EXISTS "allow_update" ON erp_daily_sales;
DROP POLICY IF EXISTS "allow_delete" ON erp_daily_sales;

DROP POLICY IF EXISTS "allow_select" ON expense_parent_categories;
DROP POLICY IF EXISTS "allow_insert" ON expense_parent_categories;
DROP POLICY IF EXISTS "allow_update" ON expense_parent_categories;
DROP POLICY IF EXISTS "allow_delete" ON expense_parent_categories;

DROP POLICY IF EXISTS "allow_select" ON expense_requisitions;
DROP POLICY IF EXISTS "allow_insert" ON expense_requisitions;
DROP POLICY IF EXISTS "allow_update" ON expense_requisitions;
DROP POLICY IF EXISTS "allow_delete" ON expense_requisitions;

DROP POLICY IF EXISTS "allow_select" ON expense_scheduler;
DROP POLICY IF EXISTS "allow_insert" ON expense_scheduler;
DROP POLICY IF EXISTS "allow_update" ON expense_scheduler;
DROP POLICY IF EXISTS "allow_delete" ON expense_scheduler;

DROP POLICY IF EXISTS "allow_select" ON expense_sub_categories;
DROP POLICY IF EXISTS "allow_insert" ON expense_sub_categories;
DROP POLICY IF EXISTS "allow_update" ON expense_sub_categories;
DROP POLICY IF EXISTS "allow_delete" ON expense_sub_categories;

DROP POLICY IF EXISTS "allow_select" ON flyer_offer_products;
DROP POLICY IF EXISTS "allow_insert" ON flyer_offer_products;
DROP POLICY IF EXISTS "allow_update" ON flyer_offer_products;
DROP POLICY IF EXISTS "allow_delete" ON flyer_offer_products;

DROP POLICY IF EXISTS "allow_select" ON flyer_offers;
DROP POLICY IF EXISTS "allow_insert" ON flyer_offers;
DROP POLICY IF EXISTS "allow_update" ON flyer_offers;
DROP POLICY IF EXISTS "allow_delete" ON flyer_offers;

DROP POLICY IF EXISTS "allow_select" ON flyer_products;
DROP POLICY IF EXISTS "allow_insert" ON flyer_products;
DROP POLICY IF EXISTS "allow_update" ON flyer_products;
DROP POLICY IF EXISTS "allow_delete" ON flyer_products;

DROP POLICY IF EXISTS "allow_select" ON flyer_templates;
DROP POLICY IF EXISTS "allow_insert" ON flyer_templates;
DROP POLICY IF EXISTS "allow_update" ON flyer_templates;
DROP POLICY IF EXISTS "allow_delete" ON flyer_templates;

DROP POLICY IF EXISTS "allow_select" ON hr_departments;
DROP POLICY IF EXISTS "allow_insert" ON hr_departments;
DROP POLICY IF EXISTS "allow_update" ON hr_departments;
DROP POLICY IF EXISTS "allow_delete" ON hr_departments;

DROP POLICY IF EXISTS "allow_select" ON hr_employee_contacts;
DROP POLICY IF EXISTS "allow_insert" ON hr_employee_contacts;
DROP POLICY IF EXISTS "allow_update" ON hr_employee_contacts;
DROP POLICY IF EXISTS "allow_delete" ON hr_employee_contacts;

DROP POLICY IF EXISTS "allow_select" ON hr_employee_documents;
DROP POLICY IF EXISTS "allow_insert" ON hr_employee_documents;
DROP POLICY IF EXISTS "allow_update" ON hr_employee_documents;
DROP POLICY IF EXISTS "allow_delete" ON hr_employee_documents;

DROP POLICY IF EXISTS "allow_select" ON hr_employees;
DROP POLICY IF EXISTS "allow_insert" ON hr_employees;
DROP POLICY IF EXISTS "allow_update" ON hr_employees;
DROP POLICY IF EXISTS "allow_delete" ON hr_employees;

DROP POLICY IF EXISTS "allow_select" ON hr_fingerprint_transactions;
DROP POLICY IF EXISTS "allow_insert" ON hr_fingerprint_transactions;
DROP POLICY IF EXISTS "allow_update" ON hr_fingerprint_transactions;
DROP POLICY IF EXISTS "allow_delete" ON hr_fingerprint_transactions;

DROP POLICY IF EXISTS "allow_select" ON hr_levels;
DROP POLICY IF EXISTS "allow_insert" ON hr_levels;
DROP POLICY IF EXISTS "allow_update" ON hr_levels;
DROP POLICY IF EXISTS "allow_delete" ON hr_levels;

DROP POLICY IF EXISTS "allow_select" ON hr_position_assignments;
DROP POLICY IF EXISTS "allow_insert" ON hr_position_assignments;
DROP POLICY IF EXISTS "allow_update" ON hr_position_assignments;
DROP POLICY IF EXISTS "allow_delete" ON hr_position_assignments;

DROP POLICY IF EXISTS "allow_select" ON hr_position_reporting_template;
DROP POLICY IF EXISTS "allow_insert" ON hr_position_reporting_template;
DROP POLICY IF EXISTS "allow_update" ON hr_position_reporting_template;
DROP POLICY IF EXISTS "allow_delete" ON hr_position_reporting_template;

DROP POLICY IF EXISTS "allow_select" ON hr_positions;
DROP POLICY IF EXISTS "allow_insert" ON hr_positions;
DROP POLICY IF EXISTS "allow_update" ON hr_positions;
DROP POLICY IF EXISTS "allow_delete" ON hr_positions;

DROP POLICY IF EXISTS "allow_select" ON hr_salary_components;
DROP POLICY IF EXISTS "allow_insert" ON hr_salary_components;
DROP POLICY IF EXISTS "allow_update" ON hr_salary_components;
DROP POLICY IF EXISTS "allow_delete" ON hr_salary_components;

DROP POLICY IF EXISTS "allow_select" ON hr_salary_wages;
DROP POLICY IF EXISTS "allow_insert" ON hr_salary_wages;
DROP POLICY IF EXISTS "allow_update" ON hr_salary_wages;
DROP POLICY IF EXISTS "allow_delete" ON hr_salary_wages;

DROP POLICY IF EXISTS "allow_select" ON interface_permissions;
DROP POLICY IF EXISTS "allow_insert" ON interface_permissions;
DROP POLICY IF EXISTS "allow_update" ON interface_permissions;
DROP POLICY IF EXISTS "allow_delete" ON interface_permissions;

DROP POLICY IF EXISTS "allow_select" ON non_approved_payment_scheduler;
DROP POLICY IF EXISTS "allow_insert" ON non_approved_payment_scheduler;
DROP POLICY IF EXISTS "allow_update" ON non_approved_payment_scheduler;
DROP POLICY IF EXISTS "allow_delete" ON non_approved_payment_scheduler;

DROP POLICY IF EXISTS "allow_select" ON notification_attachments;
DROP POLICY IF EXISTS "allow_insert" ON notification_attachments;
DROP POLICY IF EXISTS "allow_update" ON notification_attachments;
DROP POLICY IF EXISTS "allow_delete" ON notification_attachments;

DROP POLICY IF EXISTS "allow_select" ON notification_queue;
DROP POLICY IF EXISTS "allow_insert" ON notification_queue;
DROP POLICY IF EXISTS "allow_update" ON notification_queue;
DROP POLICY IF EXISTS "allow_delete" ON notification_queue;

DROP POLICY IF EXISTS "allow_select" ON notification_read_states;
DROP POLICY IF EXISTS "allow_insert" ON notification_read_states;
DROP POLICY IF EXISTS "allow_update" ON notification_read_states;
DROP POLICY IF EXISTS "allow_delete" ON notification_read_states;

DROP POLICY IF EXISTS "allow_select" ON notification_recipients;
DROP POLICY IF EXISTS "allow_insert" ON notification_recipients;
DROP POLICY IF EXISTS "allow_update" ON notification_recipients;
DROP POLICY IF EXISTS "allow_delete" ON notification_recipients;

DROP POLICY IF EXISTS "allow_select" ON notifications;
DROP POLICY IF EXISTS "allow_insert" ON notifications;
DROP POLICY IF EXISTS "allow_update" ON notifications;
DROP POLICY IF EXISTS "allow_delete" ON notifications;

DROP POLICY IF EXISTS "allow_select" ON offer_bundles;
DROP POLICY IF EXISTS "allow_insert" ON offer_bundles;
DROP POLICY IF EXISTS "allow_update" ON offer_bundles;
DROP POLICY IF EXISTS "allow_delete" ON offer_bundles;

DROP POLICY IF EXISTS "allow_select" ON offer_cart_tiers;
DROP POLICY IF EXISTS "allow_insert" ON offer_cart_tiers;
DROP POLICY IF EXISTS "allow_update" ON offer_cart_tiers;
DROP POLICY IF EXISTS "allow_delete" ON offer_cart_tiers;

DROP POLICY IF EXISTS "allow_select" ON offer_products;
DROP POLICY IF EXISTS "allow_insert" ON offer_products;
DROP POLICY IF EXISTS "allow_update" ON offer_products;
DROP POLICY IF EXISTS "allow_delete" ON offer_products;

DROP POLICY IF EXISTS "allow_select" ON offer_usage_logs;
DROP POLICY IF EXISTS "allow_insert" ON offer_usage_logs;
DROP POLICY IF EXISTS "allow_update" ON offer_usage_logs;
DROP POLICY IF EXISTS "allow_delete" ON offer_usage_logs;

DROP POLICY IF EXISTS "allow_select" ON offers;
DROP POLICY IF EXISTS "allow_insert" ON offers;
DROP POLICY IF EXISTS "allow_update" ON offers;
DROP POLICY IF EXISTS "allow_delete" ON offers;

DROP POLICY IF EXISTS "allow_select" ON order_audit_logs;
DROP POLICY IF EXISTS "allow_insert" ON order_audit_logs;
DROP POLICY IF EXISTS "allow_update" ON order_audit_logs;
DROP POLICY IF EXISTS "allow_delete" ON order_audit_logs;

DROP POLICY IF EXISTS "allow_select" ON order_items;
DROP POLICY IF EXISTS "allow_insert" ON order_items;
DROP POLICY IF EXISTS "allow_update" ON order_items;
DROP POLICY IF EXISTS "allow_delete" ON order_items;

DROP POLICY IF EXISTS "allow_select" ON orders;
DROP POLICY IF EXISTS "allow_insert" ON orders;
DROP POLICY IF EXISTS "allow_update" ON orders;
DROP POLICY IF EXISTS "allow_delete" ON orders;

DROP POLICY IF EXISTS "allow_select" ON product_categories;
DROP POLICY IF EXISTS "allow_insert" ON product_categories;
DROP POLICY IF EXISTS "allow_update" ON product_categories;
DROP POLICY IF EXISTS "allow_delete" ON product_categories;

DROP POLICY IF EXISTS "allow_select" ON product_units;
DROP POLICY IF EXISTS "allow_insert" ON product_units;
DROP POLICY IF EXISTS "allow_update" ON product_units;
DROP POLICY IF EXISTS "allow_delete" ON product_units;

DROP POLICY IF EXISTS "allow_select" ON products;
DROP POLICY IF EXISTS "allow_insert" ON products;
DROP POLICY IF EXISTS "allow_update" ON products;
DROP POLICY IF EXISTS "allow_delete" ON products;

DROP POLICY IF EXISTS "allow_select" ON push_subscriptions;
DROP POLICY IF EXISTS "allow_insert" ON push_subscriptions;
DROP POLICY IF EXISTS "allow_update" ON push_subscriptions;
DROP POLICY IF EXISTS "allow_delete" ON push_subscriptions;

DROP POLICY IF EXISTS "allow_select" ON quick_task_assignments;
DROP POLICY IF EXISTS "allow_insert" ON quick_task_assignments;
DROP POLICY IF EXISTS "allow_update" ON quick_task_assignments;
DROP POLICY IF EXISTS "allow_delete" ON quick_task_assignments;

DROP POLICY IF EXISTS "allow_select" ON quick_task_comments;
DROP POLICY IF EXISTS "allow_insert" ON quick_task_comments;
DROP POLICY IF EXISTS "allow_update" ON quick_task_comments;
DROP POLICY IF EXISTS "allow_delete" ON quick_task_comments;

DROP POLICY IF EXISTS "allow_select" ON quick_task_completions;
DROP POLICY IF EXISTS "allow_insert" ON quick_task_completions;
DROP POLICY IF EXISTS "allow_update" ON quick_task_completions;
DROP POLICY IF EXISTS "allow_delete" ON quick_task_completions;

DROP POLICY IF EXISTS "allow_select" ON quick_task_files;
DROP POLICY IF EXISTS "allow_insert" ON quick_task_files;
DROP POLICY IF EXISTS "allow_update" ON quick_task_files;
DROP POLICY IF EXISTS "allow_delete" ON quick_task_files;

DROP POLICY IF EXISTS "allow_select" ON quick_task_user_preferences;
DROP POLICY IF EXISTS "allow_insert" ON quick_task_user_preferences;
DROP POLICY IF EXISTS "allow_update" ON quick_task_user_preferences;
DROP POLICY IF EXISTS "allow_delete" ON quick_task_user_preferences;

DROP POLICY IF EXISTS "allow_select" ON quick_tasks;
DROP POLICY IF EXISTS "allow_insert" ON quick_tasks;
DROP POLICY IF EXISTS "allow_update" ON quick_tasks;
DROP POLICY IF EXISTS "allow_delete" ON quick_tasks;

DROP POLICY IF EXISTS "allow_select" ON receiving_records;
DROP POLICY IF EXISTS "allow_insert" ON receiving_records;
DROP POLICY IF EXISTS "allow_update" ON receiving_records;
DROP POLICY IF EXISTS "allow_delete" ON receiving_records;

DROP POLICY IF EXISTS "allow_select" ON receiving_task_templates;
DROP POLICY IF EXISTS "allow_insert" ON receiving_task_templates;
DROP POLICY IF EXISTS "allow_update" ON receiving_task_templates;
DROP POLICY IF EXISTS "allow_delete" ON receiving_task_templates;

DROP POLICY IF EXISTS "allow_select" ON receiving_tasks;
DROP POLICY IF EXISTS "allow_insert" ON receiving_tasks;
DROP POLICY IF EXISTS "allow_update" ON receiving_tasks;
DROP POLICY IF EXISTS "allow_delete" ON receiving_tasks;

DROP POLICY IF EXISTS "allow_select" ON recurring_assignment_schedules;
DROP POLICY IF EXISTS "allow_insert" ON recurring_assignment_schedules;
DROP POLICY IF EXISTS "allow_update" ON recurring_assignment_schedules;
DROP POLICY IF EXISTS "allow_delete" ON recurring_assignment_schedules;

DROP POLICY IF EXISTS "allow_select" ON recurring_schedule_check_log;
DROP POLICY IF EXISTS "allow_insert" ON recurring_schedule_check_log;
DROP POLICY IF EXISTS "allow_update" ON recurring_schedule_check_log;
DROP POLICY IF EXISTS "allow_delete" ON recurring_schedule_check_log;

DROP POLICY IF EXISTS "allow_select" ON requesters;
DROP POLICY IF EXISTS "allow_insert" ON requesters;
DROP POLICY IF EXISTS "allow_update" ON requesters;
DROP POLICY IF EXISTS "allow_delete" ON requesters;

DROP POLICY IF EXISTS "allow_select" ON role_permissions;
DROP POLICY IF EXISTS "allow_insert" ON role_permissions;
DROP POLICY IF EXISTS "allow_update" ON role_permissions;
DROP POLICY IF EXISTS "allow_delete" ON role_permissions;

DROP POLICY IF EXISTS "allow_select" ON shelf_paper_templates;
DROP POLICY IF EXISTS "allow_insert" ON shelf_paper_templates;
DROP POLICY IF EXISTS "allow_update" ON shelf_paper_templates;
DROP POLICY IF EXISTS "allow_delete" ON shelf_paper_templates;

DROP POLICY IF EXISTS "allow_select" ON task_assignments;
DROP POLICY IF EXISTS "allow_insert" ON task_assignments;
DROP POLICY IF EXISTS "allow_update" ON task_assignments;
DROP POLICY IF EXISTS "allow_delete" ON task_assignments;

DROP POLICY IF EXISTS "allow_select" ON task_completions;
DROP POLICY IF EXISTS "allow_insert" ON task_completions;
DROP POLICY IF EXISTS "allow_update" ON task_completions;
DROP POLICY IF EXISTS "allow_delete" ON task_completions;

DROP POLICY IF EXISTS "allow_select" ON task_images;
DROP POLICY IF EXISTS "allow_insert" ON task_images;
DROP POLICY IF EXISTS "allow_update" ON task_images;
DROP POLICY IF EXISTS "allow_delete" ON task_images;

DROP POLICY IF EXISTS "allow_select" ON task_reminder_logs;
DROP POLICY IF EXISTS "allow_insert" ON task_reminder_logs;
DROP POLICY IF EXISTS "allow_update" ON task_reminder_logs;
DROP POLICY IF EXISTS "allow_delete" ON task_reminder_logs;

DROP POLICY IF EXISTS "allow_select" ON tasks;
DROP POLICY IF EXISTS "allow_insert" ON tasks;
DROP POLICY IF EXISTS "allow_update" ON tasks;
DROP POLICY IF EXISTS "allow_delete" ON tasks;

DROP POLICY IF EXISTS "allow_select" ON tax_categories;
DROP POLICY IF EXISTS "allow_insert" ON tax_categories;
DROP POLICY IF EXISTS "allow_update" ON tax_categories;
DROP POLICY IF EXISTS "allow_delete" ON tax_categories;

DROP POLICY IF EXISTS "allow_select" ON user_audit_logs;
DROP POLICY IF EXISTS "allow_insert" ON user_audit_logs;
DROP POLICY IF EXISTS "allow_update" ON user_audit_logs;
DROP POLICY IF EXISTS "allow_delete" ON user_audit_logs;

DROP POLICY IF EXISTS "allow_select" ON user_device_sessions;
DROP POLICY IF EXISTS "allow_insert" ON user_device_sessions;
DROP POLICY IF EXISTS "allow_update" ON user_device_sessions;
DROP POLICY IF EXISTS "allow_delete" ON user_device_sessions;

DROP POLICY IF EXISTS "allow_select" ON user_password_history;
DROP POLICY IF EXISTS "allow_insert" ON user_password_history;
DROP POLICY IF EXISTS "allow_update" ON user_password_history;
DROP POLICY IF EXISTS "allow_delete" ON user_password_history;

DROP POLICY IF EXISTS "allow_select" ON user_roles;
DROP POLICY IF EXISTS "allow_insert" ON user_roles;
DROP POLICY IF EXISTS "allow_update" ON user_roles;
DROP POLICY IF EXISTS "allow_delete" ON user_roles;

DROP POLICY IF EXISTS "allow_select" ON user_sessions;
DROP POLICY IF EXISTS "allow_insert" ON user_sessions;
DROP POLICY IF EXISTS "allow_update" ON user_sessions;
DROP POLICY IF EXISTS "allow_delete" ON user_sessions;

DROP POLICY IF EXISTS "allow_select" ON users;
DROP POLICY IF EXISTS "allow_insert" ON users;
DROP POLICY IF EXISTS "allow_update" ON users;
DROP POLICY IF EXISTS "allow_delete" ON users;

DROP POLICY IF EXISTS "allow_select" ON variation_audit_log;
DROP POLICY IF EXISTS "allow_insert" ON variation_audit_log;
DROP POLICY IF EXISTS "allow_update" ON variation_audit_log;
DROP POLICY IF EXISTS "allow_delete" ON variation_audit_log;

DROP POLICY IF EXISTS "allow_select" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "allow_insert" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "allow_update" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "allow_delete" ON vendor_payment_schedule;

DROP POLICY IF EXISTS "allow_select" ON vendors;
DROP POLICY IF EXISTS "allow_insert" ON vendors;
DROP POLICY IF EXISTS "allow_update" ON vendors;
DROP POLICY IF EXISTS "allow_delete" ON vendors;
