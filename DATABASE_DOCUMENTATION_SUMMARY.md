# Aqura Database Documentation Summary

## 📋 Generated Files

1. **DATABASE_SCHEMA_REFERENCE.json** - Complete raw schema data
2. **DATABASE_SCHEMA_REFERENCE.md** - Basic schema markdown reference
3. **DATABASE_SCHEMA_REFERENCE_ENHANCED.json** - Enhanced schema with sample data
4. **DATABASE_SCHEMA_REFERENCE_ENHANCED.md** - Comprehensive markdown documentation

## 🏗️ Database Overview

### System Architecture
- **Database**: PostgreSQL via Supabase
- **Total Tables**: 64
- **Storage Buckets**: 14 
- **Edge Functions**: 3
- **Database Functions**: 0 (limited access)
- **RLS Policies**: 0 (limited access)

### Table Categories

| Category | Count | Description |
|----------|-------|-------------|
| **HR Tables** | 13 | Employee management, departments, positions, documents |
| **QUICK Tasks** | 9 | Quick task management system |
| **USER Tables** | 8 | User management, roles, permissions, sessions |
| **TASK Tables** | 6 | Task assignments, completions, attachments |
| **EXPENSE Tables** | 4 | Expense management and categories |
| **NOTIFICATION Tables** | 5 | Notification system and recipients |
| **RECEIVING Tables** | 3 | Receiving records and tasks |
| **EMPLOYEE Tables** | 3 | Warning system and fine payments |
| **VENDOR Tables** | 2 | Vendor management and payments |
| **RECURRING Tables** | 2 | Recurring schedules and assignments |
| **Other Categories** | 9 | Branches, requesters, app functions, etc. |

### Key Functional Areas

#### 1. **Human Resources Management**
- Employee records (`hr_employees`)
- Department structure (`hr_departments`)
- Position management (`hr_positions`, `hr_position_assignments`)
- Document management (`hr_employee_documents`, `hr_employee_main_documents`)
- Salary components (`hr_salary_components`, `hr_salary_wages`)
- Fingerprint tracking (`hr_fingerprint_transactions`)

#### 2. **Task Management System**
- Core tasks (`tasks`, `task_assignments`, `task_completions`)
- Quick tasks (`quick_tasks`, `quick_task_assignments`, `quick_task_completions`)
- Task attachments and images (`task_attachments`, `task_images`)
- Recurring schedules (`recurring_assignment_schedules`)

#### 3. **Employee Warning System**
- Warning records (`employee_warnings`, `employee_warning_history`)
- Active warnings view (`active_warnings_view`)
- Fine management (`employee_fine_payments`, `active_fines_view`)

#### 4. **Notification System**
- Core notifications (`notifications`, `notification_queue`)
- Recipients and read states (`notification_recipients`, `notification_read_states`)
- Push notifications (`push_subscriptions`)
- Notification attachments (`notification_attachments`)

#### 5. **Expense Management**
- Expense categories (`expense_parent_categories`, `expense_sub_categories`)
- Requisitions (`expense_requisitions`)
- Scheduled expenses (`expense_scheduler`)
- Payment schedules (`vendor_payment_schedule`, `non_approved_payment_scheduler`)

#### 6. **User Management**
- User accounts (`users`, `user_roles`, `user_sessions`)
- Permission system (`role_permissions`, `user_permissions_view`)
- Audit logging (`user_audit_logs`, `user_password_history`)
- Device sessions (`user_device_sessions`)

#### 7. **Receiving & Vendor Management**
- Receiving records (`receiving_records`, `receiving_tasks`)
- Vendor management (`vendors`)
- Purchase requisition processing (`receiving_records_pr_excel_status`)

## 💾 Storage Architecture

### Storage Buckets Structure

| Bucket | Purpose | Public | Sample Files |
|--------|---------|--------|--------------|
| `employee-documents` | HR documents | Yes | Empty |
| `user-avatars` | Profile pictures | Yes | Empty |
| `original-bills` | Bill documents | Yes | PDF files |
| `vendor-contracts` | Vendor agreements | Yes | Empty |
| `pr-excel-files` | Purchase requisition Excel files | Yes | XLSX files |
| `requisition-images` | Requisition attachments | Yes | Various |
| `expense-scheduler-bills` | Scheduled expense documents | Yes | Various |
| `notification-images` | Notification attachments | Yes | Various |
| `task-images` | Task-related images | Yes | Various |
| `warning-documents` | Warning document templates | Yes | PNG files |
| `quick-task-files` | Quick task attachments | Yes | Various |
| `completion-photos` | Task completion photos | Yes | Various |
| `clearance-certificates` | Clearance documentation | Yes | Various |
| `documents` | General documents | Yes | Empty |

## ⚡ Edge Functions

### 1. `process-push-queue`
- **Purpose**: Process queued push notifications
- **Technology**: Deno, web-push library
- **Features**: VAPID key management, queue processing

### 2. `send-push-notification`
- **Purpose**: Send individual push notifications
- **Technology**: Deno, web-push library
- **Features**: Direct notification sending

### 3. `test-queue`
- **Purpose**: Test queue functionality
- **Technology**: Deno, Supabase client
- **Features**: Queue testing and debugging

## 🔍 Key Schema Insights

### Warning System Example
The `active_warnings_view` shows the comprehensive warning system:
- **Warning Types**: task_delay_no_fine, task_delay_with_fine, etc.
- **Fine Management**: Optional fine amounts, due dates, payment tracking
- **Document Storage**: Warning documents stored in warning-documents bucket
- **Multi-language Support**: Language codes for internationalization
- **Audit Trail**: Creation, acknowledgment, resolution tracking

### Task Management Structure
- **Dual Task Systems**: Regular tasks and quick tasks
- **Assignment Tracking**: Full assignment lifecycle
- **Completion Monitoring**: Completion rates and performance metrics
- **File Attachments**: Support for task-related documents and images
- **Recurring Schedules**: Automated task assignment

### User & Permission Model
- **Role-based Access**: Role and permission system
- **Session Management**: Device and user session tracking
- **Audit Logging**: Comprehensive user activity logging
- **Password Security**: Password history tracking

## 🚀 Development Notes

### Generated Schema Files
1. **JSON Files**: Complete data structures for programmatic access
2. **Markdown Files**: Human-readable documentation with sample data
3. **Sample Data**: Real column structures with example values
4. **File Organization**: Tables grouped by functional area

### Schema Enhancement Features
- **Sample Data Analysis**: Actual column values for understanding data types
- **Null Value Detection**: Understanding optional vs required fields
- **Type Inference**: JavaScript type detection from sample data
- **Relationship Mapping**: Foreign key relationships identified

### Access Patterns
- **Row Level Security**: Present but details require elevated access
- **Public Tables**: Most tables accessible with service role
- **Views**: Several materialized views for complex queries
- **Functions**: Database functions present but access limited

## 📚 Usage Guide

### For Developers
1. Use `DATABASE_SCHEMA_REFERENCE_ENHANCED.md` for comprehensive table documentation
2. Reference `DATABASE_SCHEMA_REFERENCE_ENHANCED.json` for programmatic schema access
3. Check sample data structures for proper data formatting
4. Review storage bucket structure for file upload implementations

### For Database Administrators
1. Review table relationships and constraints
2. Monitor storage bucket usage and policies
3. Analyze edge function implementations
4. Plan for RLS policy documentation enhancement

### For Business Analysts
1. Understand functional area organization
2. Review warning and task management workflows
3. Analyze notification and user management systems
4. Plan feature enhancements based on existing structure

---

*This documentation was automatically generated on 2025-10-30 and provides a complete reference for the Aqura Management System database architecture.*