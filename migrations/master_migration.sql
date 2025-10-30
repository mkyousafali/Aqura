-- Master Migration Script for Aqura Database
-- Generated on: 2025-10-30T21:55:45.343Z
-- This script creates the complete database structure

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_crypt";

-- Run in sequence:
-- 1. Common functions
\i functions/common_functions.sql

-- 2. Create tables (in dependency order)
\i tables/users.sql
\i tables/branches.sql
\i tables/hr_departments.sql
\i tables/hr_positions.sql
\i tables/hr_levels.sql
\i tables/hr_employees.sql
\i tables/push_subscriptions.sql
\i tables/expense_scheduler.sql
\i tables/hr_document_categories_summary.sql
\i tables/hr_salary_components.sql
\i tables/quick_task_assignments.sql
\i tables/task_assignments.sql
\i tables/vendors.sql
\i tables/task_attachments.sql
\i tables/expense_parent_categories.sql
\i tables/quick_task_comments.sql
\i tables/role_permissions.sql
\i tables/user_password_history.sql
\i tables/employee_fine_payments.sql
\i tables/quick_task_files_with_details.sql
\i tables/recurring_assignment_schedules.sql
\i tables/user_device_sessions.sql
\i tables/receiving_records.sql
\i tables/vendor_payment_schedule.sql
\i tables/employee_warnings.sql
\i tables/notification_queue.sql
\i tables/requesters.sql
\i tables/quick_task_completion_details.sql
\i tables/app_functions.sql
\i tables/task_completion_summary.sql
\i tables/tasks.sql
\i tables/active_warnings_view.sql
\i tables/non_approved_payment_scheduler.sql
\i tables/quick_tasks.sql
\i tables/expense_sub_categories.sql
\i tables/hr_fingerprint_transactions.sql
\i tables/expense_requisitions.sql
\i tables/position_roles_view.sql
\i tables/notification_recipients.sql
\i tables/notification_attachments.sql
\i tables/hr_employee_contacts.sql
\i tables/user_management_view.sql
\i tables/task_completions.sql
\i tables/user_audit_logs.sql
\i tables/employee_warning_history.sql
\i tables/notification_read_states.sql
\i tables/quick_task_completions.sql
\i tables/user_roles.sql
\i tables/quick_tasks_with_details.sql
\i tables/quick_task_files.sql
\i tables/quick_task_user_preferences.sql
\i tables/recurring_schedule_check_log.sql
\i tables/hr_employee_main_documents.sql
\i tables/hr_position_assignments.sql
\i tables/user_sessions.sql
\i tables/hr_salary_wages.sql
\i tables/receiving_tasks.sql
\i tables/receiving_records_pr_excel_status.sql
\i tables/hr_employee_documents.sql
\i tables/task_images.sql
\i tables/hr_position_reporting_template.sql
\i tables/notifications.sql
\i tables/user_permissions_view.sql
\i tables/active_fines_view.sql

-- 3. Create views
\i views/user_management_view.sql
\i views/active_warnings_view.sql
\i views/active_fines_view.sql
\i views/position_roles_view.sql
\i views/user_permissions_view.sql

-- 4. Setup storage buckets
\i storage/storage_buckets.sql

-- 5. Apply RLS policies
\i policies/basic_policies.sql

-- 6. Create triggers (if any specific ones needed)

-- Final steps
-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Update table statistics
ANALYZE;

-- Success message
SELECT 'Aqura database migration completed successfully!' as status;
