# Aqura Database Migrations

Generated on: 2025-10-30T21:55:45.344Z

## Overview

This directory contains PostgreSQL migration files for the complete Aqura database structure.

## Directory Structure

```
migrations/
├── master_migration.sql       # Main migration script (run this)
├── README.md                  # This file
├── tables/                    # Individual table creation scripts
│   ├── users.sql
│   ├── hr_employees.sql
│   └── ... (64 total tables)
├── functions/                 # Database functions
│   └── common_functions.sql
├── triggers/                  # Database triggers
├── storage/                   # Storage bucket setup
│   └── storage_buckets.sql
├── policies/                  # Row Level Security policies
│   └── basic_policies.sql
└── views/                     # Database views
    ├── user_management_view.sql
    └── ...
```

## Quick Start

### Option 1: Run Complete Migration
```bash
psql -d your_database_name -f migrations/master_migration.sql
```

### Option 2: Run Individual Components
```bash
# 1. Functions first
psql -d your_database_name -f migrations/functions/common_functions.sql

# 2. Core tables
psql -d your_database_name -f migrations/tables/users.sql
psql -d your_database_name -f migrations/tables/branches.sql
# ... continue with other tables

# 3. Views
psql -d your_database_name -f migrations/views/user_management_view.sql

# 4. Storage
psql -d your_database_name -f migrations/storage/storage_buckets.sql

# 5. Policies
psql -d your_database_name -f migrations/policies/basic_policies.sql
```

## Generated Tables (64 total)

### HR Management Tables
- hr_employees, hr_departments, hr_positions, hr_levels
- hr_employee_contacts, hr_employee_documents, hr_employee_main_documents
- hr_position_assignments, hr_position_reporting_template
- hr_salary_components, hr_salary_wages
- hr_fingerprint_transactions, hr_document_categories_summary

### Task Management Tables
- tasks, task_assignments, task_completions, task_attachments, task_images
- quick_tasks, quick_task_assignments, quick_task_completions
- quick_task_comments, quick_task_files, quick_task_user_preferences
- quick_tasks_with_details, quick_task_files_with_details, quick_task_completion_details

### User Management Tables
- users, user_roles, user_sessions, user_device_sessions
- user_audit_logs, user_password_history, user_permissions_view, user_management_view

### Warning & Fine System
- employee_warnings, employee_warning_history, employee_fine_payments
- active_warnings_view, active_fines_view

### Notification System
- notifications, notification_queue, notification_recipients
- notification_read_states, notification_attachments, push_subscriptions

### Financial Management
- expense_parent_categories, expense_sub_categories, expense_requisitions, expense_scheduler
- vendors, vendor_payment_schedule, non_approved_payment_scheduler

### Receiving & Vendor Management
- receiving_records, receiving_tasks, receiving_records_pr_excel_status
- requesters

### System Configuration
- branches, app_functions, role_permissions
- recurring_assignment_schedules, recurring_schedule_check_log

## Storage Buckets

The following storage buckets will be created:
- employee-documents, user-avatars, documents
- original-bills, vendor-contracts, pr-excel-files
- requisition-images, expense-scheduler-bills
- notification-images, task-images, warning-documents
- quick-task-files, completion-photos, clearance-certificates

## Key Features

### Automatic Timestamps
- All tables include `created_at` and `updated_at` with automatic triggers

### UUID Primary Keys
- All tables use UUID primary keys with `gen_random_uuid()` default

### Row Level Security
- All tables have RLS enabled with basic policies

### Indexing
- Automatic indexes on foreign keys, status fields, and timestamps

### Reference Generation
- Functions for generating warning, task, and notification references

## Prerequisites

1. PostgreSQL 12+ with uuid-ossp extension
2. Supabase setup (if using Supabase features)
3. Proper database permissions

## Notes

- Generated from actual Aqura database schema analysis
- Includes sample data structures and inferred types
- RLS policies may need customization for your security requirements
- Some advanced triggers and functions may require manual implementation

## Support

This migration was auto-generated from the Aqura database schema.
Review and test in a development environment before running in production.
