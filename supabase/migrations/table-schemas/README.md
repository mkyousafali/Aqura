# Database Table Schema Files

## 📁 Location
`D:\Aqura\supabase\migrations\table-schemas\`

## 📊 Summary
Generated **54 complete SQL schema files** for all database tables on **November 6, 2025**.

## 🏗️ What Each File Contains

Each SQL file includes:

1. **📋 Complete Table Definition**
   - CREATE TABLE statement with all columns
   - Data types, constraints, and default values
   - Table and column comments

2. **🔍 Indexes**
   - Primary key indexes
   - Foreign key indexes  
   - Date/timestamp indexes
   - Performance optimization indexes

3. **🔧 Triggers**
   - Table-specific triggers (if any)
   - Trigger definitions and functions

4. **🔒 Row Level Security (RLS)**
   - RLS policies for SELECT, INSERT, UPDATE, DELETE
   - Security configurations

5. **⚙️ Related Functions**
   - Functions that operate on the table
   - References to database functions

6. **📖 Usage Examples**
   - INSERT, SELECT, UPDATE examples
   - Common query patterns

## 📋 Complete File List (54 files)

### 🖥️ System & Admin Tables (7 files)
- `app_functions.sql` - Application function registry
- `approval_permissions.sql` - Approval workflow permissions
- `branches.sql` - Branch/location management
- `role_permissions.sql` - Role-based permissions
- `recurring_assignment_schedules.sql` - Recurring task schedules
- `recurring_schedule_check_log.sql` - Schedule check logs
- `requesters.sql` - Request originators

### 👥 HR & Employee Management (11 files)
- `hr_departments.sql` - Department structure
- `hr_employees.sql` - Employee master data
- `hr_employee_contacts.sql` - Employee contact information
- `hr_employee_documents.sql` - Employee document management
- `hr_fingerprint_transactions.sql` - Biometric attendance
- `hr_levels.sql` - Employee levels/grades
- `hr_positions.sql` - Job positions
- `hr_position_assignments.sql` - Position assignments
- `hr_position_reporting_template.sql` - Reporting templates
- `hr_salary_components.sql` - Salary structure
- `hr_salary_wages.sql` - Wage calculations

### 👤 User Management (6 files)
- `users.sql` - User accounts
- `user_roles.sql` - User role assignments
- `user_audit_logs.sql` - User activity tracking
- `user_device_sessions.sql` - Device session management
- `user_password_history.sql` - Password change history
- `user_sessions.sql` - Active user sessions

### 📋 Task Management (10 files)
- `tasks.sql` - Main task definitions
- `task_assignments.sql` - Task assignments to users
- `task_completions.sql` - Task completion records
- `task_images.sql` - Task-related images
- `task_reminder_logs.sql` - Reminder notifications
- `quick_tasks.sql` - Quick task system
- `quick_task_assignments.sql` - Quick task assignments
- `quick_task_comments.sql` - Task comments
- `quick_task_completions.sql` - Quick task completions
- `quick_task_files.sql` - Task file attachments
- `quick_task_user_preferences.sql` - User task preferences

### 📦 Receiving & Inventory (3 files)
- `receiving_records.sql` - Goods receiving records
- `receiving_tasks.sql` - Receiving-related tasks
- `receiving_task_templates.sql` - Task templates

### 🏪 Vendor Management (2 files)
- `vendors.sql` - Vendor master data
- `vendor_payment_schedule.sql` - Vendor payment scheduling

### 💰 Financial Management (6 files)
- `expense_parent_categories.sql` - Expense main categories
- `expense_sub_categories.sql` - Expense subcategories
- `expense_requisitions.sql` - Expense requests
- `expense_scheduler.sql` - Expense scheduling
- `non_approved_payment_scheduler.sql` - Non-approved payments
- `employee_fine_payments.sql` - Employee fine payments

### 🔔 Notification System (6 files)
- `notifications.sql` - Main notification system
- `notification_attachments.sql` - Notification attachments
- `notification_queue.sql` - Notification queue
- `notification_read_states.sql` - Read status tracking
- `notification_recipients.sql` - Notification recipients
- `push_subscriptions.sql` - Push notification subscriptions

### ⚠️ Warning System (2 files)
- `employee_warnings.sql` - Employee warning system
- `employee_warning_history.sql` - Warning history tracking

## 🚀 How to Use These Files

### 1. **Database Recreation**
```sql
-- Run any table schema file to recreate the table
\i D:\Aqura\supabase\migrations\table-schemas\users.sql
```

### 2. **Development Reference**
- Use as documentation for table structure
- Reference for writing queries
- Understanding relationships between tables

### 3. **Migration Scripts**
- Modify and use for database migrations
- Ensure data integrity during updates
- Version control for schema changes

### 4. **Backup & Recovery**
- Complete schema backup in SQL format
- Restore table structure if needed
- Disaster recovery preparation

## 🔗 Key Relationships

### **Core Entity Relationships:**
- `users` ↔ `user_roles` ↔ `role_permissions`
- `hr_employees` ↔ `hr_positions` ↔ `hr_departments`
- `tasks` ↔ `task_assignments` ↔ `users`
- `receiving_records` ↔ `vendor_payment_schedule` ↔ `vendors`
- `notifications` ↔ `notification_recipients` ↔ `users`

### **Workflow Integration:**
- Task Management → Receiving → Payment → Approval
- Employee → Roles → Permissions → Functions
- Notifications → Push Subscriptions → User Devices

## 📈 Database Statistics
- **Total Tables:** 54
- **Total Columns:** ~1,400+ (estimated)
- **Key Data Types:** UUID, TEXT, NUMERIC, TIMESTAMP, JSONB, BOOLEAN
- **Generated:** November 6, 2025

## 🎯 Next Steps
1. Review individual table schemas for your specific needs
2. Customize RLS policies as per security requirements
3. Add additional indexes for performance optimization
4. Update triggers and functions as business logic evolves

---
*Generated automatically from live database schema using service role access*