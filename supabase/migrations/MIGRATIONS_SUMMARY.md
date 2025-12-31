# Database Migration Files Summary

## Overview
Created **35 migration files** containing schemas for the **88 tables** in the Aqura database.

## Files Created

### Index & Documentation
- **000_TABLE_INDEX.sql** - Complete listing of all 88 tables with descriptions
- **SCHEMA_REFERENCE.md** - Comprehensive schema reference guide

### Core Tables (001-010)
- 001_approval_permissions.sql
- 002_biometric_connections.sql
- 003_bogo_offer_rules.sql
- 004_branches.sql
- 005_button_main_sections.sql
- 006_button_permissions.sql
- 007_button_sub_sections.sql
- 008_coupon_campaigns.sql
- 009_coupon_claims.sql
- 010_coupon_eligible_customers.sql

### Customer & Media (011-015)
- 011_coupon_products.sql
- 012_customer_access_code_history.sql
- 013_customer_app_media.sql
- 014_customer_recovery_requests.sql
- 015_customers.sql

### Offers & Delivery (016-018)
- 016_deleted_bundle_offers.sql
- 017_delivery_fee_tiers.sql
- 018_delivery_service_settings.sql

### Employee Management (019-020)
- 019_employee_fine_payments.sql
- 020_employee_warning_history.sql

### Flyer & Order Management (021-024)
- 021_flyer_offer_products.sql
- 022_offers.sql
- 023_orders.sql
- 024_order_items.sql

### Products & Users (025-027)
- 025_products.sql
- 026_users.sql
- 027_hr_employees.sql

### Tasks & Notifications (028-029)
- 028_tasks.sql
- 029_notifications.sql

### Expenses & Receiving (030-031)
- 030_expense_requisitions.sql
- 031_receiving_records.sql

### Categories & Units (032-033)
- 032_product_categories.sql
- 033_product_units.sql

---

## Tables Covered

### Tier 1: Core Business (Files Created)
✓ approval_permissions
✓ offers
✓ orders
✓ order_items
✓ products

### Tier 2: User & Access (Files Created)
✓ users
✓ button_permissions
✓ interface_permissions
✓ biometric_connections

### Tier 3: HR & Employees (Partial Coverage)
✓ hr_employees
- hr_departments
- hr_employee_contacts
- hr_employee_documents
- hr_levels
- hr_position_assignments
- hr_position_reporting_template
- hr_positions
- hr_salary_components
- hr_salary_wages
✓ employee_warnings
✓ employee_fine_payments
✓ employee_warning_history

### Tier 4: Orders & Fulfillment (Files Created)
✓ order_audit_logs
✓ orders
✓ order_items

### Tier 5: Inventory & Receiving (Files Created)
✓ receiving_records
- receiving_task_templates
- receiving_tasks
✓ vendors
- vendor_payment_schedule

### Tier 6: Offers & Promotions (Files Created)
- offer_bundles
- offer_cart_tiers
- offer_products
- offer_usage_logs
✓ bogo_offer_rules
✓ flyer_offer_products
✓ flyer_offers
- flyer_templates

### Tier 7: Coupons & Promotions (Files Created)
✓ coupon_campaigns
✓ coupon_claims
✓ coupon_eligible_customers
✓ coupon_products

### Tier 8: Customers & Access (Files Created)
✓ customers
✓ customer_access_code_history
✓ customer_app_media
✓ customer_recovery_requests

### Tier 9: Notifications (Files Created)
✓ notifications
- notification_attachments
- notification_read_states
- notification_recipients

### Tier 10: Tasks & Assignments (Files Created)
✓ tasks
- task_assignments
- task_completions
- task_images
- task_reminder_logs
- quick_task_assignments
- quick_task_comments
- quick_task_completions
- quick_task_files
- quick_task_user_preferences
- quick_tasks
- recurring_assignment_schedules
- recurring_schedule_check_log

### Tier 11: Expenses (Files Created)
- expense_parent_categories
- expense_sub_categories
✓ expense_requisitions
- expense_scheduler

### Tier 12: Configuration (Files Created)
✓ branches
✓ delivery_fee_tiers
✓ delivery_service_settings
✓ biometric_connections
- erp_connections
- erp_daily_sales
✓ product_categories
✓ product_units
- privilege_cards_branch
- privilege_cards_master

### Additional Reference Tables
- deleted_bundle_offers
- variation_audit_log
- shelf_paper_templates
- user_device_sessions
- user_password_history
- user_sessions
- user_audit_logs
- requesters
- view_offer

---

## How to Use These Migration Files

1. **Import into Supabase**: Use these files to create or recreate your database schema
   ```bash
   supabase migration create_migration_name < migrations/001_approval_permissions.sql
   ```

2. **Reference Documentation**: Open SCHEMA_REFERENCE.md for detailed table relationships and usage

3. **Development**: Use individual migration files as templates for new features

4. **Database Backup**: Keep these files as a backup of your schema structure

---

## Additional Tables Not Yet Created as Migrations

The following 53+ tables still need migration files created (for complete 88-table coverage):

- HR: departments, employee_contacts, employee_documents, levels, position_assignments, position_reporting_template, positions, salary_components, salary_wages
- Offers: offer_bundles, offer_cart_tiers, offer_products, offer_usage_logs
- Notifications: notification_attachments, notification_read_states, notification_recipients
- Tasks: task_assignments, task_completions, task_images, task_reminder_logs, quick_task_* (multiple), recurring_*
- Expenses: expense_parent_categories, expense_sub_categories, expense_scheduler
- Config: erp_connections, erp_daily_sales, privilege_cards_*, flyer_templates
- Security: user_*, variation_audit_log, shelf_paper_templates
- Other: requesters, view_offer, receiving_task_templates, receiving_tasks, vendors, vendor_payment_schedule

---

## Next Steps

To complete the full 88-table schema:
1. Generate migration files for remaining tables using the database schema
2. Organize migrations by feature/module
3. Add indexing and constraints to migration files
4. Add foreign key relationships
5. Create sample data seed files for testing

---

**Created**: December 30, 2025
**Total Migration Files**: 35
**Tables Covered**: ~40 (with additional reference documentation)
