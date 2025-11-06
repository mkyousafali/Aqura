# Database Functions Index
Generated: 2025-11-06T10:38:50.826Z
Total Functions: 138

## Categories:
- **employee**: 6 functions
- **financial**: 9 functions
- **misc**: 21 functions
- **notification**: 7 functions
- **receiving**: 2 functions
- **stats**: 3 functions
- **system**: 23 functions
- **task**: 40 functions
- **user**: 8 functions
- **vendor**: 19 functions

## Function List by Category:

### EMPLOYEE (6 functions)
- `get_employee_document_category_stats`
- `get_employee_basic_hours`
- `sync_employee_with_hr`
- `get_active_employees_by_branch`
- `link_finger_transaction_to_employee`
- `get_employee_schedules`

### FINANCIAL (9 functions)
- `record_fine_payment`
- `count_bills_without_erp_reference_by_branch`
- `count_bills_without_original_by_branch`
- `get_branch_promissory_notes_summary`
- `count_bills_without_pr_excel_by_branch`
- `count_bills_without_original`
- `validate_payment_methods`
- `count_bills_without_erp_reference`
- `count_bills_without_pr_excel`

### MISC (21 functions)
- `is_overnight_shift`
- `create_default_auto_schedule_config`
- `create_schedule_template`
- `urlencode`
- `text_to_bytea`
- `format_file_size`
- `process_clearance_certificate_generation`
- `debug_get_dependency_photos`
- `get_dependency_completion_photos`
- `check_and_notify_recurring_schedules_with_logging`
- `is_quick_access_code_available`
- `calculate_working_hours`
- `generate_unique_quick_access_code`
- `check_and_notify_recurring_schedules`
- `create_system_admin`
- `get_file_extension`
- `bytea_to_text`
- `acknowledge_warning`
- `get_or_create_app_function`
- `generate_recurring_occurrences`
- `setup_role_permissions`

### NOTIFICATION (7 functions)
- `create_notification_simple`
- `process_push_notification_queue`
- `get_reminder_statistics`
- `cleanup_orphaned_notifications`
- `cleanup_old_push_subscriptions`
- `queue_push_notification`
- `register_push_subscription`

### RECEIVING (2 functions)
- `get_vendor_for_receiving_record`
- `sync_erp_reference_for_receiving_record`

### STATS (3 functions)
- `check_accountant_dependency`
- `get_quick_access_stats`
- `get_expense_category_stats`

### SYSTEM (23 functions)
- `http_delete`
- `http_header`
- `http_head`
- `sync_all_missing_erp_references`
- `http_list_curlopt`
- `http_get`
- `get_database_triggers`
- `daily_erp_sync_maintenance`
- `sync_app_functions_from_components`
- `http_patch`
- `http_set_curlopt`
- `http_reset_curlopt`
- `register_system_role`
- `http`
- `register_app_function`
- `cleanup_expired_sessions`
- `check_erp_sync_status_for_record`
- `get_database_schema`
- `get_database_functions`
- `sync_all_pending_erp_references`
- `http_put`
- `check_erp_sync_status`
- `http_post`

### TASK (40 functions)
- `get_user_receiving_tasks_dashboard`
- `complete_receiving_task_fixed`
- `complete_receiving_task`
- `get_task_statistics`
- `check_receiving_task_dependencies`
- `sync_erp_references_from_task_completions`
- `check_overdue_tasks_and_send_reminders`
- `get_user_assigned_tasks`
- `count_finished_receiving_tasks`
- `reassign_receiving_task`
- `mark_overdue_quick_tasks`
- `get_all_receiving_tasks`
- `validate_task_completion_requirements`
- `get_overdue_tasks_without_reminders`
- `search_tasks`
- `count_incomplete_receiving_tasks_detailed`
- `get_quick_task_completion_stats`
- `generate_clearance_certificate_tasks`
- `submit_quick_task_completion`
- `count_completed_receiving_tasks`
- `create_quick_task_with_assignments`
- `get_task_dashboard`
- `reassign_task`
- `get_incomplete_receiving_tasks`
- `get_tasks_for_receiving_record`
- `get_receiving_task_statistics`
- `count_incomplete_receiving_tasks`
- `assign_task_simple`
- `check_task_completion_criteria`
- `create_task`
- `create_scheduled_assignment`
- `get_receiving_tasks_for_user`
- `verify_quick_task_completion`
- `get_incomplete_receiving_tasks_breakdown`
- `create_recurring_assignment`
- `update_receiving_task_completion`
- `complete_receiving_task_simple`
- `get_completed_receiving_tasks`
- `debug_receiving_tasks_data`
- `get_assignments_with_deadlines`

### USER (8 functions)
- `debug_users`
- `create_user`
- `generate_salt`
- `hash_password`
- `refresh_user_roles_from_positions`
- `get_users_with_employee_details`
- `verify_password`
- `get_all_users`

### VENDOR (19 functions)
- `get_todays_scheduled_visits`
- `update_next_visit_date`
- `skip_visit`
- `get_vendor_count_by_branch`
- `check_visit_conflicts`
- `reschedule_visit`
- `get_visits_by_date_range`
- `insert_vendor_from_excel`
- `get_todays_vendor_visits`
- `get_visit_history`
- `get_vendors_by_branch`
- `get_upcoming_visits`
- `update_vendor_payment_with_exact_calculation`
- `get_branch_visits_summary`
- `calculate_next_visit_date`
- `complete_visit_and_update_next`
- `get_vendor_promissory_notes_summary`
- `get_vendor_visits_summary`
- `get_todays_visits`

## Usage
Each function is saved as a separate SQL file in its respective category folder.
You can run these functions via Supabase RPC calls or direct SQL execution.

## Service Role Key Required
These functions require service role access and are used throughout the application
for administrative operations, bypassing Row Level Security (RLS).
