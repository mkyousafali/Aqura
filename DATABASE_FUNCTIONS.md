# Supabase Database Functions

**Generated:** December 1, 2025 at 04:09:55 AM  
**Total Functions:** 305  
**Categories:** 10

---

## Summary

| Category | Function Count |
|---|---|
| Customer | 17 |
| Employee/HR | 11 |
| Financial | 14 |
| Notification | 16 |
| Offer Management | 19 |
| Other | 92 |
| Receiving & Vendor | 29 |
| System/ERP | 26 |
| Task Management | 60 |
| User Management | 21 |
| **TOTAL** | **305** |

---

## Table of Contents

1. [Customer](#customer) - 17 functions
2. [Employee/HR](#employee/hr) - 11 functions
3. [Financial](#financial) - 14 functions
4. [Notification](#notification) - 16 functions
5. [Offer Management](#offer-management) - 19 functions
6. [Other](#other) - 92 functions
7. [Receiving & Vendor](#receiving-&-vendor) - 29 functions
8. [System/ERP](#system/erp) - 26 functions
9. [Task Management](#task-management) - 60 functions
10. [User Management](#user-management) - 21 functions

---

## Customer

**Total Functions:** 17

| Function Name | Return Type |
|---|---|
| `approve_customer_account` | `record` |
| `approve_customer_registration` | `json` |
| `create_customer_order` | `record` |
| `create_customer_registration` | `json` |
| `generate_new_customer_access_code` | `json` |
| `generate_unique_customer_access_code` | `text` |
| `generate_unique_quick_access_code` | `character varying` |
| `get_active_customer_media` | `record` |
| `get_active_offers_for_customer` | `record` |
| `get_customers_list` | `record` |
| `is_quick_access_code_available` | `boolean` |
| `is_quick_access_code_available` | `boolean` |
| `process_customer_recovery` | `json` |
| `request_new_access_code` | `json` |
| `update_customer_app_media_timestamp` | `trigger` |
| `update_customer_recovery_requests_updated_at` | `trigger` |
| `update_customers_updated_at` | `trigger` |

## Employee/HR

**Total Functions:** 11

| Function Name | Return Type |
|---|---|
| `get_active_employees_by_branch` | `record` |
| `get_employee_basic_hours` | `numeric` |
| `get_employee_basic_hours` | `numeric` |
| `get_employee_document_category_stats` | `record` |
| `get_employee_schedules` | `record` |
| `get_employee_schedules` | `record` |
| `link_finger_transaction_to_employee` | `uuid` |
| `sync_employee_with_hr` | `boolean` |
| `update_departments_updated_at` | `trigger` |
| `update_employee_positions_updated_at` | `trigger` |
| `update_positions_updated_at` | `trigger` |

## Financial

**Total Functions:** 14

| Function Name | Return Type |
|---|---|
| `acknowledge_warning` | `boolean` |
| `create_warning_history` | `trigger` |
| `generate_warning_reference` | `trigger` |
| `get_expense_category_stats` | `record` |
| `record_fine_payment` | `uuid` |
| `sync_requisition_balance` | `trigger` |
| `update_expense_categories_updated_at` | `trigger` |
| `update_expense_parent_categories_updated_at` | `trigger` |
| `update_expense_scheduler_updated_at` | `trigger` |
| `update_payment_transactions_updated_at` | `trigger` |
| `update_requisition_balance` | `trigger` |
| `update_requisition_balance_old` | `trigger` |
| `update_warning_updated_at` | `trigger` |
| `validate_payment_methods` | `boolean` |

## Notification

**Total Functions:** 16

| Function Name | Return Type |
|---|---|
| `cleanup_old_push_subscriptions` | `void` |
| `cleanup_orphaned_notifications` | `void` |
| `create_notification_recipients` | `trigger` |
| `create_notification_simple` | `uuid` |
| `process_push_notification_queue` | `void` |
| `queue_push_notification` | `void` |
| `queue_push_notification` | `void` |
| `queue_push_notification_trigger` | `trigger` |
| `register_push_subscription` | `uuid` |
| `schedule_renotification` | `trigger` |
| `trigger_queue_push_notifications` | `trigger` |
| `update_notification_attachments_flag` | `trigger` |
| `update_notification_delivery_status` | `trigger` |
| `update_notification_queue_updated_at` | `trigger` |
| `update_notification_read_count` | `trigger` |
| `update_push_subscriptions_updated_at` | `trigger` |

## Offer Management

**Total Functions:** 19

| Function Name | Return Type |
|---|---|
| `check_offer_eligibility` | `boolean` |
| `claim_coupon` | `jsonb` |
| `get_cart_tier_discount` | `record` |
| `get_offer_variation_summary` | `record` |
| `get_product_offers` | `record` |
| `get_products_in_active_offers` | `record` |
| `increment_flyer_template_usage` | `trigger` |
| `is_product_in_active_bundle` | `boolean` |
| `log_offer_usage` | `integer` |
| `prevent_coupon_claim_modification` | `trigger` |
| `trigger_log_order_offer_usage` | `trigger` |
| `update_bogo_offer_rules_updated_at` | `trigger` |
| `update_coupon_campaigns_updated_at` | `trigger` |
| `update_coupon_products_updated_at` | `trigger` |
| `update_offer_cart_tiers_updated_at` | `trigger` |
| `update_offers_updated_at` | `trigger` |
| `validate_bundle_offer_type` | `trigger` |
| `validate_coupon_eligibility` | `jsonb` |
| `validate_product_offer` | `boolean` |

## Other

**Total Functions:** 92

| Function Name | Return Type |
|---|---|
| `accept_order` | `record` |
| `assign_order_delivery` | `record` |
| `assign_order_picker` | `record` |
| `bytea_to_text` | `text` |
| `calculate_category_days` | `trigger` |
| `calculate_return_totals` | `trigger` |
| `calculate_schedule_details` | `trigger` |
| `calculate_working_hours` | `numeric` |
| `calculate_working_hours` | `numeric` |
| `cancel_order` | `record` |
| `check_accountant_dependency` | `jsonb` |
| `check_and_notify_recurring_schedules` | `record` |
| `check_and_notify_recurring_schedules_with_logging` | `record` |
| `check_orphaned_variations` | `record` |
| `clear_main_document_columns` | `trigger` |
| `count_bills_without_original` | `integer` |
| `count_bills_without_original_by_branch` | `integer` |
| `count_bills_without_pr_excel` | `integer` |
| `count_bills_without_pr_excel_by_branch` | `integer` |
| `create_default_auto_schedule_config` | `void` |
| `create_default_auto_schedule_config` | `void` |
| `create_schedule_template` | `uuid` |
| `create_schedule_template` | `bigint` |
| `create_system_admin` | `uuid` |
| `create_variation_group` | `record` |
| `deactivate_expired_media` | `void` |
| `debug_get_dependency_photos` | `json` |
| `duplicate_flyer_template` | `uuid` |
| `ensure_single_default_flyer_template` | `trigger` |
| `format_file_size` | `text` |
| `generate_branch_id` | `trigger` |
| `generate_campaign_code` | `character varying` |
| `generate_order_number` | `character varying` |
| `generate_recurring_occurrences` | `record` |
| `generate_salt` | `text` |
| `get_active_flyer_templates` | `record` |
| `get_all_branches_delivery_settings` | `record` |
| `get_all_delivery_tiers` | `record` |
| `get_branch_delivery_settings` | `record` |
| `get_branch_promissory_notes_summary` | `record` |
| `get_branch_service_availability` | `record` |
| `get_campaign_statistics` | `jsonb` |
| `get_default_flyer_template` | `record` |
| `get_delivery_fee_for_amount` | `numeric` |
| `get_delivery_fee_for_amount_by_branch` | `numeric` |
| `get_delivery_service_settings` | `record` |
| `get_delivery_tiers_by_branch` | `record` |
| `get_file_extension` | `text` |
| `get_next_delivery_tier` | `record` |
| `get_next_delivery_tier_by_branch` | `record` |
| `get_next_product_serial` | `text` |
| `get_or_create_app_function` | `uuid` |
| `get_product_variations` | `record` |
| `get_quick_access_stats` | `record` |
| `get_variation_group_info` | `record` |
| `handle_document_deactivation` | `trigger` |
| `has_order_management_access` | `boolean` |
| `http` | `USER-DEFINED` |
| `is_delivery_staff` | `boolean` |
| `is_overnight_shift` | `boolean` |
| `process_clearance_certificate_generation` | `json` |
| `process_finger_transaction_linking` | `trigger` |
| `register_app_function` | `uuid` |
| `select_random_product` | `record` |
| `soft_delete_flyer_template` | `boolean` |
| `text_to_bytea` | `bytea` |
| `track_media_activation` | `trigger` |
| `trigger_notify_new_order` | `trigger` |
| `trigger_order_status_audit` | `trigger` |
| `trigger_update_order_totals` | `trigger` |
| `update_attendance_hours` | `trigger` |
| `update_branches_updated_at` | `trigger` |
| `update_deadline_datetime` | `trigger` |
| `update_delivery_tiers_timestamp` | `trigger` |
| `update_duty_schedule_timestamp` | `trigger` |
| `update_final_bill_amount_on_adjustment` | `trigger` |
| `update_flyer_templates_updated_at` | `trigger` |
| `update_levels_updated_at` | `trigger` |
| `update_main_document_columns` | `trigger` |
| `update_non_approved_scheduler_updated_at` | `trigger` |
| `update_order_status` | `record` |
| `update_product_categories_updated_at` | `trigger` |
| `update_product_units_updated_at` | `trigger` |
| `update_products_updated_at` | `trigger` |
| `update_tax_categories_updated_at` | `trigger` |
| `update_updated_at` | `trigger` |
| `update_updated_at_column` | `trigger` |
| `urlencode` | `text` |
| `urlencode` | `text` |
| `urlencode` | `text` |
| `validate_flyer_template_configuration` | `boolean` |
| `validate_variation_prices` | `record` |

## Receiving & Vendor

**Total Functions:** 29

| Function Name | Return Type |
|---|---|
| `auto_create_payment_schedule` | `trigger` |
| `calculate_next_visit_date` | `date` |
| `calculate_receiving_amounts` | `trigger` |
| `check_visit_conflicts` | `record` |
| `complete_visit_and_update_next` | `date` |
| `get_branch_visits_summary` | `record` |
| `get_todays_scheduled_visits` | `record` |
| `get_todays_scheduled_visits` | `record` |
| `get_todays_vendor_visits` | `record` |
| `get_todays_visits` | `record` |
| `get_upcoming_visits` | `record` |
| `get_vendor_count_by_branch` | `record` |
| `get_vendor_for_receiving_record` | `record` |
| `get_vendor_promissory_notes_summary` | `record` |
| `get_vendor_visits_summary` | `record` |
| `get_vendors_by_branch` | `record` |
| `get_visit_history` | `record` |
| `get_visits_by_date_range` | `record` |
| `get_visits_by_date_range` | `record` |
| `insert_vendor_from_excel` | `uuid` |
| `insert_vendor_from_excel` | `uuid` |
| `reschedule_visit` | `date` |
| `skip_visit` | `boolean` |
| `sync_erp_reference_for_receiving_record` | `jsonb` |
| `update_next_visit_date` | `date` |
| `update_receiving_records_pr_excel_timestamp` | `trigger` |
| `update_receiving_records_updated_at` | `trigger` |
| `update_vendor_payment_with_exact_calculation` | `void` |
| `validate_vendor_branch_match` | `trigger` |

## System/ERP

**Total Functions:** 26

| Function Name | Return Type |
|---|---|
| `check_erp_sync_status` | `record` |
| `check_erp_sync_status_for_record` | `jsonb` |
| `count_bills_without_erp_reference` | `integer` |
| `count_bills_without_erp_reference_by_branch` | `integer` |
| `daily_erp_sync_maintenance` | `text` |
| `get_database_functions` | `record` |
| `get_database_schema` | `jsonb` |
| `get_database_triggers` | `record` |
| `http_delete` | `USER-DEFINED` |
| `http_delete` | `USER-DEFINED` |
| `http_get` | `USER-DEFINED` |
| `http_get` | `USER-DEFINED` |
| `http_head` | `USER-DEFINED` |
| `http_header` | `USER-DEFINED` |
| `http_list_curlopt` | `record` |
| `http_patch` | `USER-DEFINED` |
| `http_post` | `USER-DEFINED` |
| `http_post` | `USER-DEFINED` |
| `http_put` | `USER-DEFINED` |
| `http_reset_curlopt` | `boolean` |
| `http_set_curlopt` | `boolean` |
| `sync_all_missing_erp_references` | `record` |
| `sync_all_pending_erp_references` | `jsonb` |
| `sync_app_functions_from_components` | `text` |
| `update_erp_connections_updated_at` | `trigger` |
| `update_erp_daily_sales_updated_at` | `trigger` |

## Task Management

**Total Functions:** 60

| Function Name | Return Type |
|---|---|
| `assign_task_simple` | `uuid` |
| `check_overdue_tasks_and_send_reminders` | `record` |
| `check_receiving_task_dependencies` | `json` |
| `check_task_completion_criteria` | `boolean` |
| `complete_receiving_task` | `jsonb` |
| `complete_receiving_task_fixed` | `json` |
| `complete_receiving_task_simple` | `json` |
| `copy_completion_requirements_to_assignment` | `trigger` |
| `count_completed_receiving_tasks` | `integer` |
| `count_finished_receiving_tasks` | `integer` |
| `count_incomplete_receiving_tasks` | `integer` |
| `count_incomplete_receiving_tasks_detailed` | `integer` |
| `create_quick_task_notification` | `trigger` |
| `create_quick_task_with_assignments` | `uuid` |
| `create_recurring_assignment` | `uuid` |
| `create_recurring_assignment` | `uuid` |
| `create_scheduled_assignment` | `uuid` |
| `create_scheduled_assignment` | `uuid` |
| `create_task` | `uuid` |
| `debug_receiving_tasks_data` | `record` |
| `generate_clearance_certificate_tasks` | `record` |
| `get_all_receiving_tasks` | `record` |
| `get_assignments_with_deadlines` | `record` |
| `get_assignments_with_deadlines` | `record` |
| `get_completed_receiving_tasks` | `record` |
| `get_dependency_completion_photos` | `json` |
| `get_incomplete_receiving_tasks` | `record` |
| `get_incomplete_receiving_tasks_breakdown` | `record` |
| `get_overdue_tasks_without_reminders` | `record` |
| `get_quick_task_completion_stats` | `record` |
| `get_receiving_task_statistics` | `record` |
| `get_receiving_task_statistics` | `record` |
| `get_receiving_tasks_for_user` | `record` |
| `get_receiving_tasks_for_user` | `record` |
| `get_reminder_statistics` | `record` |
| `get_task_dashboard` | `record` |
| `get_task_statistics` | `record` |
| `get_task_statistics` | `record` |
| `get_tasks_for_receiving_record` | `record` |
| `get_user_assigned_tasks` | `record` |
| `get_user_receiving_tasks_dashboard` | `json` |
| `mark_overdue_quick_tasks` | `void` |
| `queue_quick_task_push_notifications` | `trigger` |
| `reassign_receiving_task` | `jsonb` |
| `reassign_task` | `uuid` |
| `reassign_task` | `boolean` |
| `search_tasks` | `record` |
| `search_tasks` | `record` |
| `submit_quick_task_completion` | `uuid` |
| `sync_erp_references_from_task_completions` | `record` |
| `trigger_cleanup_assignment_notifications` | `trigger` |
| `trigger_cleanup_task_notifications` | `trigger` |
| `trigger_sync_erp_reference_on_task_completion` | `trigger` |
| `update_quick_task_completions_updated_at` | `trigger` |
| `update_quick_task_status` | `trigger` |
| `update_receiving_task_completion` | `boolean` |
| `update_receiving_task_templates_updated_at` | `trigger` |
| `update_receiving_tasks_updated_at` | `trigger` |
| `validate_task_completion_requirements` | `jsonb` |
| `verify_quick_task_completion` | `boolean` |

## User Management

**Total Functions:** 21

| Function Name | Return Type |
|---|---|
| `authenticate_customer_access_code` | `json` |
| `cleanup_expired_sessions` | `void` |
| `create_default_interface_permissions` | `trigger` |
| `create_user` | `jsonb` |
| `create_user` | `uuid` |
| `create_user_profile` | `trigger` |
| `debug_users` | `record` |
| `get_all_users` | `record` |
| `get_user_interface_permissions` | `json` |
| `get_users_with_employee_details` | `record` |
| `hash_password` | `text` |
| `log_user_action` | `trigger` |
| `refresh_user_roles_from_positions` | `integer` |
| `register_system_role` | `uuid` |
| `setup_role_permissions` | `integer` |
| `sync_user_roles_from_positions` | `trigger` |
| `update_approval_permissions_updated_at` | `trigger` |
| `update_interface_permissions_updated_at` | `trigger` |
| `update_user_device_sessions_updated_at` | `trigger` |
| `verify_password` | `record` |
| `verify_password` | `boolean` |

