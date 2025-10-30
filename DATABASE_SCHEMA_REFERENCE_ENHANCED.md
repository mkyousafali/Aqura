# Aqura Database Schema Reference (Enhanced)

*Generated on 2025-10-30T21:47:43.113Z*
*Enhanced on 2025-10-30T21:49:42.479Z*

## Overview

- **Database URL**: https://vmypotfsyrvuublyddyt.supabase.co
- **Total Tables**: 64
- **Storage Buckets**: 14
- **Database Functions**: 0
- **Edge Functions**: 3
- **RLS Policies**: 0
- **Database Triggers**: 0

## Table Categories

### Quick Navigation

- [ACTIVE Tables](#active-tables) (2 tables)
- [APP Tables](#app-tables) (1 tables)
- [BRANCHES Tables](#branches-tables) (1 tables)
- [EMPLOYEE Tables](#employee-tables) (3 tables)
- [EXPENSE Tables](#expense-tables) (4 tables)
- [HR Tables](#hr-tables) (13 tables)
- [NON Tables](#non-tables) (1 tables)
- [NOTIFICATION Tables](#notification-tables) (4 tables)
- [NOTIFICATIONS Tables](#notifications-tables) (1 tables)
- [POSITION Tables](#position-tables) (1 tables)
- [PUSH Tables](#push-tables) (1 tables)
- [QUICK Tables](#quick-tables) (9 tables)
- [RECEIVING Tables](#receiving-tables) (3 tables)
- [RECURRING Tables](#recurring-tables) (2 tables)
- [REQUESTERS Tables](#requesters-tables) (1 tables)
- [ROLE Tables](#role-tables) (1 tables)
- [TASK Tables](#task-tables) (5 tables)
- [TASKS Tables](#tasks-tables) (1 tables)
- [USER Tables](#user-tables) (7 tables)
- [USERS Tables](#users-tables) (1 tables)
- [VENDOR Tables](#vendor-tables) (1 tables)
- [VENDORS Tables](#vendors-tables) (1 tables)

## ACTIVE Tables

### `active_fines_view`

*📋 Table exists but is currently empty*

### `active_warnings_view`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "3f344550-81fa-46a3-bacc-0647cc2fccbf" | string | has value |
| user_id | "807af948-0f5f-4f36-8925-747b152513c1" | string | has value |
| employee_id | "86cd4137-aecd-43c7-bd85-c200944f0e52" | string | has value |
| username | "Abdhusathar" | string | has value |
| warning_type | "task_delay_no_fine" | string | has value |
| has_fine | false | boolean | has value |
| fine_amount | null | object | nullable |
| fine_currency | "USD" | string | has value |
| fine_status | null | object | nullable |
| fine_due_date | null | object | nullable |
| fine_paid_date | null | object | nullable |
| fine_paid_amount | null | object | nullable |
| warning_text | "This serves as a formal warning regarding the task "New Delivery Arrived – Price Check" assigned at Urban Market (Abu Arish) with a deadline of 2/11/2025. Timely completion is crucial to avoid any delays in the process. Failure to meet the deadline may result in further consequences." | string | has value |
| language_code | "en" | string | has value |
| task_id | null | object | nullable |
| task_title | "New Delivery Arrived – Price Check" | string | has value |
| task_description | "🧾 Task for Purchasing Manager

Perform price verification for this receiving record.

Branch: Urban Market (Araidah)
Vendor: -EMDAD مؤسسة امداد الجنوبيه للتجارة (قهوة الدلة) (ID: 1187)
Bill Amount: 500.00
Bill Number: 12345
Received Date: 2025-10-30
Received By: shamsu
Deadline: 2025-11-02 15:40:53 (72 hours from assignment)

Verify pricing accuracy and update any discrepancies in the system." | string | has value |
| assignment_id | "30b042f9-eb1f-46ab-bbe1-499cc52174fc" | string | has value |
| total_tasks_assigned | 0 | number | has value |
| total_tasks_completed | 0 | number | has value |
| total_tasks_overdue | 0 | number | has value |
| completion_rate | 0 | number | has value |
| issued_by | "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b" | string | has value |
| issued_by_username | "madmin" | string | has value |
| issued_at | "2025-10-30T18:07:36.746362" | string | has value |
| warning_status | "active" | string | has value |
| acknowledged_at | null | object | nullable |
| acknowledged_by | null | object | nullable |
| resolved_at | null | object | nullable |
| resolved_by | null | object | nullable |
| resolution_notes | null | object | nullable |
| created_at | "2025-10-30T18:07:36.746362" | string | has value |
| updated_at | "2025-10-30T18:07:38.901593" | string | has value |
| branch_id | null | object | nullable |
| department_id | null | object | nullable |
| severity_level | "high" | string | has value |
| follow_up_required | true | boolean | has value |
| follow_up_date | null | object | nullable |
| warning_reference | "WRN-20251030-0044" | string | has value |
| warning_document_url | "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/warning-documents/2025/10/abdhusathar_WRN-20251030-0044_86cd4137_1761847658359.png" | string | has value |
| is_deleted | false | boolean | has value |
| deleted_at | null | object | nullable |
| deleted_by | null | object | nullable |
| employee_name | "ABDHUSATHAR" | string | has value |
| employee_code | "63" | string | has value |
| issued_by_user | "madmin" | string | has value |
| branch_name | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "3f344550-81fa-46a3-bacc-0647cc2fccbf",
  "user_id": "807af948-0f5f-4f36-8925-747b152513c1",
  "employee_id": "86cd4137-aecd-43c7-bd85-c200944f0e52",
  "username": "Abdhusathar",
  "warning_type": "task_delay_no_fine",
  "has_fine": false,
  "fine_amount": null,
  "fine_currency": "USD",
  "fine_status": null,
  "fine_due_date": null,
  "fine_paid_date": null,
  "fine_paid_amount": null,
  "warning_text": "This serves as a formal warning regarding the task \"New Delivery Arrived – Price Check\" assigned at Urban Market (Abu Arish) with a deadline of 2/11/2025. Timely completion is crucial to avoid any delays in the process. Failure to meet the deadline may result in further consequences.",
  "language_code": "en",
  "task_id": null,
  "task_title": "New Delivery Arrived – Price Check",
  "task_description": "🧾 Task for Purchasing Manager\r\n\r\nPerform price verification for this receiving record.\r\n\r\nBranch: Urban Market (Araidah)\r\nVendor: -EMDAD مؤسسة امداد الجنوبيه للتجارة (قهوة الدلة) (ID: 1187)\r\nBill Amount: 500.00\r\nBill Number: 12345\r\nReceived Date: 2025-10-30\r\nReceived By: shamsu\r\nDeadline: 2025-11-02 15:40:53 (72 hours from assignment)\r\n\r\nVerify pricing accuracy and update any discrepancies in the system.",
  "assignment_id": "30b042f9-eb1f-46ab-bbe1-499cc52174fc",
  "total_tasks_assigned": 0,
  "total_tasks_completed": 0,
  "total_tasks_overdue": 0,
  "completion_rate": 0,
  "issued_by": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
  "issued_by_username": "madmin",
  "issued_at": "2025-10-30T18:07:36.746362",
  "warning_status": "active",
  "acknowledged_at": null,
  "acknowledged_by": null,
  "resolved_at": null,
  "resolved_by": null,
  "resolution_notes": null,
  "created_at": "2025-10-30T18:07:36.746362",
  "updated_at": "2025-10-30T18:07:38.901593",
  "branch_id": null,
  "department_id": null,
  "severity_level": "high",
  "follow_up_required": true,
  "follow_up_date": null,
  "warning_reference": "WRN-20251030-0044",
  "warning_document_url": "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/warning-documents/2025/10/abdhusathar_WRN-20251030-0044_86cd4137_1761847658359.png",
  "is_deleted": false,
  "deleted_at": null,
  "deleted_by": null,
  "employee_name": "ABDHUSATHAR",
  "employee_code": "63",
  "issued_by_user": "madmin",
  "branch_name": null
}
```

## APP Tables

### `app_functions`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "50baa859-a220-4749-8e93-b49649896de1" | string | has value |
| function_name | "Dashboard Access" | string | has value |
| function_code | "DASHBOARD" | string | has value |
| description | "Main dashboard and navigation access" | string | has value |
| category | "System" | string | has value |
| is_active | true | boolean | has value |
| created_at | "2025-09-27T09:58:52.545712+00:00" | string | has value |
| updated_at | "2025-09-27T09:58:52.545712+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "50baa859-a220-4749-8e93-b49649896de1",
  "function_name": "Dashboard Access",
  "function_code": "DASHBOARD",
  "description": "Main dashboard and navigation access",
  "category": "System",
  "is_active": true,
  "created_at": "2025-09-27T09:58:52.545712+00:00",
  "updated_at": "2025-09-27T09:58:52.545712+00:00"
}
```

## BRANCHES Tables

### `branches`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | 3 | number | has value |
| name_en | "Urban Market (Araidah)" | string | has value |
| name_ar | "ايربن ماركت (العارضة)" | string | has value |
| location_en | "Al-Aridhah" | string | has value |
| location_ar | "العارضة" | string | has value |
| is_active | true | boolean | has value |
| is_main_branch | false | boolean | has value |
| created_at | "2025-09-24T13:52:36.726278+00:00" | string | has value |
| updated_at | "2025-10-11T12:48:38.60713+00:00" | string | has value |
| created_by | null | object | nullable |
| updated_by | null | object | nullable |
| vat_number | "310338463100003" | string | has value |

**Sample Data Structure:**
```json
{
  "id": 3,
  "name_en": "Urban Market (Araidah)",
  "name_ar": "ايربن ماركت (العارضة)",
  "location_en": "Al-Aridhah",
  "location_ar": "العارضة",
  "is_active": true,
  "is_main_branch": false,
  "created_at": "2025-09-24T13:52:36.726278+00:00",
  "updated_at": "2025-10-11T12:48:38.60713+00:00",
  "created_by": null,
  "updated_by": null,
  "vat_number": "310338463100003"
}
```

## EMPLOYEE Tables

### `employee_fine_payments`

*📋 Table exists but is currently empty*

### `employee_warning_history`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "bf4e8489-f1b1-414b-9f91-a00dcde7852b" | string | has value |
| warning_id | "3f344550-81fa-46a3-bacc-0647cc2fccbf" | string | has value |
| action_type | "created" | string | has value |
| old_values | null | object | nullable |
| new_values | [object Object] | object | has value |
| changed_by | "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b" | string | has value |
| changed_by_username | "madmin" | string | has value |
| change_reason | "Warning created" | string | has value |
| created_at | "2025-10-30T18:07:36.746362" | string | has value |
| ip_address | null | object | nullable |
| user_agent | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "bf4e8489-f1b1-414b-9f91-a00dcde7852b",
  "warning_id": "3f344550-81fa-46a3-bacc-0647cc2fccbf",
  "action_type": "created",
  "old_values": null,
  "new_values": {
    "id": "3f344550-81fa-46a3-bacc-0647cc2fccbf",
    "task_id": null,
    "user_id": "807af948-0f5f-4f36-8925-747b152513c1",
    "has_fine": false,
    "username": "Abdhusathar",
    "branch_id": null,
    "issued_at": "2025-10-30T18:07:36.746362",
    "issued_by": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
    "created_at": "2025-10-30T18:07:36.746362",
    "deleted_at": null,
    "deleted_by": null,
    "is_deleted": false,
    "task_title": "New Delivery Arrived – Price Check",
    "updated_at": "2025-10-30T18:07:36.746362",
    "employee_id": "86cd4137-aecd-43c7-bd85-c200944f0e52",
    "fine_amount": null,
    "fine_status": null,
    "resolved_at": null,
    "resolved_by": null,
    "fine_paid_at": null,
    "warning_text": "This serves as a formal warning regarding the task \"New Delivery Arrived – Price Check\" assigned at Urban Market (Abu Arish) with a deadline of 2/11/2025. Timely completion is crucial to avoid any delays in the process. Failure to meet the deadline may result in further consequences.",
    "warning_type": "task_delay_no_fine",
    "assignment_id": "30b042f9-eb1f-46ab-bbe1-499cc52174fc",
    "department_id": null,
    "fine_currency": "USD",
    "fine_due_date": null,
    "language_code": "en",
    "fine_paid_date": null,
    "follow_up_date": null,
    "severity_level": "high",
    "warning_status": "active",
    "acknowledged_at": null,
    "acknowledged_by": null,
    "completion_rate": 0,
    "fine_paid_amount": null,
    "frontend_save_id": null,
    "resolution_notes": null,
    "task_description": "🧾 Task for Purchasing Manager\r\n\r\nPerform price verification for this receiving record.\r\n\r\nBranch: Urban Market (Araidah)\r\nVendor: -EMDAD مؤسسة امداد الجنوبيه للتجارة (قهوة الدلة) (ID: 1187)\r\nBill Amount: 500.00\r\nBill Number: 12345\r\nReceived Date: 2025-10-30\r\nReceived By: shamsu\r\nDeadline: 2025-11-02 15:40:53 (72 hours from assignment)\r\n\r\nVerify pricing accuracy and update any discrepancies in the system.",
    "fine_payment_note": null,
    "warning_reference": "WRN-20251030-0044",
    "follow_up_required": true,
    "issued_by_username": "madmin",
    "fine_payment_method": "cash",
    "total_tasks_overdue": 0,
    "total_tasks_assigned": 0,
    "warning_document_url": null,
    "total_tasks_completed": 0,
    "fine_payment_reference": null
  },
  "changed_by": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
  "changed_by_username": "madmin",
  "change_reason": "Warning created",
  "created_at": "2025-10-30T18:07:36.746362",
  "ip_address": null,
  "user_agent": null
}
```

### `employee_warnings`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "3f344550-81fa-46a3-bacc-0647cc2fccbf" | string | has value |
| user_id | "807af948-0f5f-4f36-8925-747b152513c1" | string | has value |
| employee_id | "86cd4137-aecd-43c7-bd85-c200944f0e52" | string | has value |
| username | "Abdhusathar" | string | has value |
| warning_type | "task_delay_no_fine" | string | has value |
| has_fine | false | boolean | has value |
| fine_amount | null | object | nullable |
| fine_currency | "USD" | string | has value |
| fine_status | null | object | nullable |
| fine_due_date | null | object | nullable |
| fine_paid_date | null | object | nullable |
| fine_paid_amount | null | object | nullable |
| warning_text | "This serves as a formal warning regarding the task "New Delivery Arrived – Price Check" assigned at Urban Market (Abu Arish) with a deadline of 2/11/2025. Timely completion is crucial to avoid any delays in the process. Failure to meet the deadline may result in further consequences." | string | has value |
| language_code | "en" | string | has value |
| task_id | null | object | nullable |
| task_title | "New Delivery Arrived – Price Check" | string | has value |
| task_description | "🧾 Task for Purchasing Manager

Perform price verification for this receiving record.

Branch: Urban Market (Araidah)
Vendor: -EMDAD مؤسسة امداد الجنوبيه للتجارة (قهوة الدلة) (ID: 1187)
Bill Amount: 500.00
Bill Number: 12345
Received Date: 2025-10-30
Received By: shamsu
Deadline: 2025-11-02 15:40:53 (72 hours from assignment)

Verify pricing accuracy and update any discrepancies in the system." | string | has value |
| assignment_id | "30b042f9-eb1f-46ab-bbe1-499cc52174fc" | string | has value |
| total_tasks_assigned | 0 | number | has value |
| total_tasks_completed | 0 | number | has value |
| total_tasks_overdue | 0 | number | has value |
| completion_rate | 0 | number | has value |
| issued_by | "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b" | string | has value |
| issued_by_username | "madmin" | string | has value |
| issued_at | "2025-10-30T18:07:36.746362" | string | has value |
| warning_status | "active" | string | has value |
| acknowledged_at | null | object | nullable |
| acknowledged_by | null | object | nullable |
| resolved_at | null | object | nullable |
| resolved_by | null | object | nullable |
| resolution_notes | null | object | nullable |
| created_at | "2025-10-30T18:07:36.746362" | string | has value |
| updated_at | "2025-10-30T18:07:38.901593" | string | has value |
| branch_id | null | object | nullable |
| department_id | null | object | nullable |
| severity_level | "high" | string | has value |
| follow_up_required | true | boolean | has value |
| follow_up_date | null | object | nullable |
| warning_reference | "WRN-20251030-0044" | string | has value |
| warning_document_url | "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/warning-documents/2025/10/abdhusathar_WRN-20251030-0044_86cd4137_1761847658359.png" | string | has value |
| is_deleted | false | boolean | has value |
| deleted_at | null | object | nullable |
| deleted_by | null | object | nullable |
| fine_paid_at | null | object | nullable |
| frontend_save_id | null | object | nullable |
| fine_payment_note | null | object | nullable |
| fine_payment_method | "cash" | string | has value |
| fine_payment_reference | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "3f344550-81fa-46a3-bacc-0647cc2fccbf",
  "user_id": "807af948-0f5f-4f36-8925-747b152513c1",
  "employee_id": "86cd4137-aecd-43c7-bd85-c200944f0e52",
  "username": "Abdhusathar",
  "warning_type": "task_delay_no_fine",
  "has_fine": false,
  "fine_amount": null,
  "fine_currency": "USD",
  "fine_status": null,
  "fine_due_date": null,
  "fine_paid_date": null,
  "fine_paid_amount": null,
  "warning_text": "This serves as a formal warning regarding the task \"New Delivery Arrived – Price Check\" assigned at Urban Market (Abu Arish) with a deadline of 2/11/2025. Timely completion is crucial to avoid any delays in the process. Failure to meet the deadline may result in further consequences.",
  "language_code": "en",
  "task_id": null,
  "task_title": "New Delivery Arrived – Price Check",
  "task_description": "🧾 Task for Purchasing Manager\r\n\r\nPerform price verification for this receiving record.\r\n\r\nBranch: Urban Market (Araidah)\r\nVendor: -EMDAD مؤسسة امداد الجنوبيه للتجارة (قهوة الدلة) (ID: 1187)\r\nBill Amount: 500.00\r\nBill Number: 12345\r\nReceived Date: 2025-10-30\r\nReceived By: shamsu\r\nDeadline: 2025-11-02 15:40:53 (72 hours from assignment)\r\n\r\nVerify pricing accuracy and update any discrepancies in the system.",
  "assignment_id": "30b042f9-eb1f-46ab-bbe1-499cc52174fc",
  "total_tasks_assigned": 0,
  "total_tasks_completed": 0,
  "total_tasks_overdue": 0,
  "completion_rate": 0,
  "issued_by": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
  "issued_by_username": "madmin",
  "issued_at": "2025-10-30T18:07:36.746362",
  "warning_status": "active",
  "acknowledged_at": null,
  "acknowledged_by": null,
  "resolved_at": null,
  "resolved_by": null,
  "resolution_notes": null,
  "created_at": "2025-10-30T18:07:36.746362",
  "updated_at": "2025-10-30T18:07:38.901593",
  "branch_id": null,
  "department_id": null,
  "severity_level": "high",
  "follow_up_required": true,
  "follow_up_date": null,
  "warning_reference": "WRN-20251030-0044",
  "warning_document_url": "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/warning-documents/2025/10/abdhusathar_WRN-20251030-0044_86cd4137_1761847658359.png",
  "is_deleted": false,
  "deleted_at": null,
  "deleted_by": null,
  "fine_paid_at": null,
  "frontend_save_id": null,
  "fine_payment_note": null,
  "fine_payment_method": "cash",
  "fine_payment_reference": null
}
```

## EXPENSE Tables

### `expense_parent_categories`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | 1 | number | has value |
| name_en | "Employee Benefits" | string | has value |
| name_ar | "مزايا الموظفين" | string | has value |
| created_at | "2025-10-26T12:07:35.416967+00:00" | string | has value |
| updated_at | "2025-10-26T12:07:35.416967+00:00" | string | has value |
| is_active | true | boolean | has value |

**Sample Data Structure:**
```json
{
  "id": 1,
  "name_en": "Employee Benefits",
  "name_ar": "مزايا الموظفين",
  "created_at": "2025-10-26T12:07:35.416967+00:00",
  "updated_at": "2025-10-26T12:07:35.416967+00:00",
  "is_active": true
}
```

### `expense_requisitions`

*📋 Table exists but is currently empty*

### `expense_scheduler`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | 48 | number | has value |
| branch_id | 1 | number | has value |
| branch_name | "Urban Market (Abu Arish)" | string | has value |
| expense_category_id | 10 | number | has value |
| expense_category_name_en | "Staff Meals" | string | has value |
| expense_category_name_ar | "وجبات الموظفين" | string | has value |
| requisition_id | null | object | nullable |
| requisition_number | null | object | nullable |
| co_user_id | "bc3d6349-8237-407a-aeef-96dab9d51adf" | string | has value |
| co_user_name | "Ramshad" | string | has value |
| bill_type | "no_vat" | string | has value |
| bill_number | "04096" | string | has value |
| bill_date | "2025-10-30" | string | has value |
| payment_method | "cash" | string | has value |
| due_date | "2025-10-30" | string | has value |
| credit_period | null | object | nullable |
| amount | 540 | number | has value |
| bill_file_url | "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/expense-scheduler-bills/1/1761837161776_bill1.pdf" | string | has value |
| description | "KUBZ FOR MESS" | string | has value |
| notes | null | object | nullable |
| is_paid | true | boolean | has value |
| paid_date | "2025-10-30T15:18:47.951+00:00" | string | has value |
| status | "paid" | string | has value |
| created_by | "bc3d6349-8237-407a-aeef-96dab9d51adf" | string | has value |
| created_at | "2025-10-30T15:15:42.804268+00:00" | string | has value |
| updated_by | "bc3d6349-8237-407a-aeef-96dab9d51adf" | string | has value |
| updated_at | "2025-10-30T15:26:13.633162+00:00" | string | has value |
| bank_name | null | object | nullable |
| iban | null | object | nullable |
| payment_reference | "CP#9605" | string | has value |
| schedule_type | "multiple_bill" | string | has value |
| recurring_type | null | object | nullable |
| recurring_metadata | null | object | nullable |
| approver_id | "ee47e425-0a10-40c3-aa7d-268efd4264a2" | string | has value |
| approver_name | "Sadham" | string | has value |

**Sample Data Structure:**
```json
{
  "id": 48,
  "branch_id": 1,
  "branch_name": "Urban Market (Abu Arish)",
  "expense_category_id": 10,
  "expense_category_name_en": "Staff Meals",
  "expense_category_name_ar": "وجبات الموظفين",
  "requisition_id": null,
  "requisition_number": null,
  "co_user_id": "bc3d6349-8237-407a-aeef-96dab9d51adf",
  "co_user_name": "Ramshad",
  "bill_type": "no_vat",
  "bill_number": "04096",
  "bill_date": "2025-10-30",
  "payment_method": "cash",
  "due_date": "2025-10-30",
  "credit_period": null,
  "amount": 540,
  "bill_file_url": "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/expense-scheduler-bills/1/1761837161776_bill1.pdf",
  "description": "KUBZ FOR MESS",
  "notes": null,
  "is_paid": true,
  "paid_date": "2025-10-30T15:18:47.951+00:00",
  "status": "paid",
  "created_by": "bc3d6349-8237-407a-aeef-96dab9d51adf",
  "created_at": "2025-10-30T15:15:42.804268+00:00",
  "updated_by": "bc3d6349-8237-407a-aeef-96dab9d51adf",
  "updated_at": "2025-10-30T15:26:13.633162+00:00",
  "bank_name": null,
  "iban": null,
  "payment_reference": "CP#9605",
  "schedule_type": "multiple_bill",
  "recurring_type": null,
  "recurring_metadata": null,
  "approver_id": "ee47e425-0a10-40c3-aa7d-268efd4264a2",
  "approver_name": "Sadham"
}
```

### `expense_sub_categories`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | 1 | number | has value |
| parent_category_id | 1 | number | has value |
| name_en | "Salaries & Wages" | string | has value |
| name_ar | "الرواتب والأجور" | string | has value |
| created_at | "2025-10-26T12:07:35.416967+00:00" | string | has value |
| updated_at | "2025-10-26T12:07:35.416967+00:00" | string | has value |
| is_active | true | boolean | has value |

**Sample Data Structure:**
```json
{
  "id": 1,
  "parent_category_id": 1,
  "name_en": "Salaries & Wages",
  "name_ar": "الرواتب والأجور",
  "created_at": "2025-10-26T12:07:35.416967+00:00",
  "updated_at": "2025-10-26T12:07:35.416967+00:00",
  "is_active": true
}
```

## HR Tables

### `hr_departments`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "e653f26f-f60d-46d9-8101-ab9580c57768" | string | has value |
| department_name_en | "Executive Leadership" | string | has value |
| department_name_ar | "القيادة التنفيذية" | string | has value |
| is_active | true | boolean | has value |
| created_at | "2025-09-25T19:49:59.686096+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "e653f26f-f60d-46d9-8101-ab9580c57768",
  "department_name_en": "Executive Leadership",
  "department_name_ar": "القيادة التنفيذية",
  "is_active": true,
  "created_at": "2025-09-25T19:49:59.686096+00:00"
}
```

### `hr_document_categories_summary`

*📋 Table exists but is currently empty*

### `hr_employee_contacts`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "8d464f13-956a-4947-ba59-0b97915014bb" | string | has value |
| employee_id | "62822d10-b910-4713-965f-63bd249b8b09" | string | has value |
| email | "vshamsudheen804@gmail.com" | string | has value |
| is_active | true | boolean | has value |
| created_at | "2025-09-29T14:21:12.853+00:00" | string | has value |
| whatsapp_number | "+966545616619" | string | has value |
| contact_number | "+966545616619" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "8d464f13-956a-4947-ba59-0b97915014bb",
  "employee_id": "62822d10-b910-4713-965f-63bd249b8b09",
  "email": "vshamsudheen804@gmail.com",
  "is_active": true,
  "created_at": "2025-09-29T14:21:12.853+00:00",
  "whatsapp_number": "+966545616619",
  "contact_number": "+966545616619"
}
```

### `hr_employee_documents`

*📋 Table exists but is currently empty*

### `hr_employee_main_documents`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| employee_id | "003d2e27-6003-4053-87c2-fe200f6c53c8" | string | has value |
| employee_code | "94" | string | has value |
| employee_name | "ISSAM MOHAMMED MAQBOUL MAASHI" | string | has value |
| health_card_number | null | object | nullable |
| health_card_expiry | null | object | nullable |
| health_card_file | null | object | nullable |
| resident_id_number | null | object | nullable |
| resident_id_expiry | null | object | nullable |
| resident_id_file | null | object | nullable |
| passport_number | null | object | nullable |
| passport_expiry | null | object | nullable |
| passport_file | null | object | nullable |
| driving_license_number | null | object | nullable |
| driving_license_expiry | null | object | nullable |
| driving_license_file | null | object | nullable |
| resume_file | null | object | nullable |
| resume_uploaded | false | boolean | has value |
| main_documents_count | 0 | number | has value |
| other_documents_count | 0 | number | has value |
| expiring_soon_count | 0 | number | has value |
| expired_count | 0 | number | has value |

**Sample Data Structure:**
```json
{
  "employee_id": "003d2e27-6003-4053-87c2-fe200f6c53c8",
  "employee_code": "94",
  "employee_name": "ISSAM MOHAMMED MAQBOUL MAASHI",
  "health_card_number": null,
  "health_card_expiry": null,
  "health_card_file": null,
  "resident_id_number": null,
  "resident_id_expiry": null,
  "resident_id_file": null,
  "passport_number": null,
  "passport_expiry": null,
  "passport_file": null,
  "driving_license_number": null,
  "driving_license_expiry": null,
  "driving_license_file": null,
  "resume_file": null,
  "resume_uploaded": false,
  "main_documents_count": 0,
  "other_documents_count": 0,
  "expiring_soon_count": 0,
  "expired_count": 0
}
```

### `hr_employees`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "ce2972f7-dce4-429a-a879-9e6fc036fa39" | string | has value |
| employee_id | "109" | string | has value |
| branch_id | 1 | number | has value |
| hire_date | null | object | nullable |
| status | "active" | string | has value |
| created_at | "2025-09-26T14:35:22.746+00:00" | string | has value |
| name | "Ibrahim" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "ce2972f7-dce4-429a-a879-9e6fc036fa39",
  "employee_id": "109",
  "branch_id": 1,
  "hire_date": null,
  "status": "active",
  "created_at": "2025-09-26T14:35:22.746+00:00",
  "name": "Ibrahim"
}
```

### `hr_fingerprint_transactions`

*📋 Table exists but is currently empty*

### `hr_levels`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "1a1ac603-61ae-4e7c-bd13-a26e6f9acc79" | string | has value |
| level_name_en | "Executive Leadership" | string | has value |
| level_name_ar | "القيادة التنفيذية" | string | has value |
| level_order | 1 | number | has value |
| is_active | true | boolean | has value |
| created_at | "2025-09-25T19:49:59.686096+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "1a1ac603-61ae-4e7c-bd13-a26e6f9acc79",
  "level_name_en": "Executive Leadership",
  "level_name_ar": "القيادة التنفيذية",
  "level_order": 1,
  "is_active": true,
  "created_at": "2025-09-25T19:49:59.686096+00:00"
}
```

### `hr_position_assignments`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "02529375-55e5-4b76-ad75-ef7d295b3e19" | string | has value |
| employee_id | "064d0cf8-9315-4706-b179-899945867cac" | string | has value |
| position_id | "67f683e4-a0b4-47bb-9b24-7ffcbb08874f" | string | has value |
| department_id | "a24f9bb5-4269-40df-87f3-23ddfa83fadb" | string | has value |
| level_id | "1f170b0b-9f8a-4e1e-b00d-0a4ee141a195" | string | has value |
| branch_id | 2 | number | has value |
| effective_date | "2025-09-26" | string | has value |
| is_current | true | boolean | has value |
| created_at | "2025-09-26T16:18:20.583+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "02529375-55e5-4b76-ad75-ef7d295b3e19",
  "employee_id": "064d0cf8-9315-4706-b179-899945867cac",
  "position_id": "67f683e4-a0b4-47bb-9b24-7ffcbb08874f",
  "department_id": "a24f9bb5-4269-40df-87f3-23ddfa83fadb",
  "level_id": "1f170b0b-9f8a-4e1e-b00d-0a4ee141a195",
  "branch_id": 2,
  "effective_date": "2025-09-26",
  "is_current": true,
  "created_at": "2025-09-26T16:18:20.583+00:00"
}
```

### `hr_position_reporting_template`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "a02baf11-7ab0-4b95-9338-93244bd309dd" | string | has value |
| subordinate_position_id | "eeaa430c-8613-4403-b1c2-45fde9842db5" | string | has value |
| manager_position_1 | null | object | nullable |
| manager_position_2 | null | object | nullable |
| manager_position_3 | null | object | nullable |
| manager_position_4 | null | object | nullable |
| manager_position_5 | null | object | nullable |
| is_active | true | boolean | has value |
| created_at | "2025-09-25T19:49:59.686096+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "a02baf11-7ab0-4b95-9338-93244bd309dd",
  "subordinate_position_id": "eeaa430c-8613-4403-b1c2-45fde9842db5",
  "manager_position_1": null,
  "manager_position_2": null,
  "manager_position_3": null,
  "manager_position_4": null,
  "manager_position_5": null,
  "is_active": true,
  "created_at": "2025-09-25T19:49:59.686096+00:00"
}
```

### `hr_positions`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "eeaa430c-8613-4403-b1c2-45fde9842db5" | string | has value |
| position_title_en | "Owner / Chairman" | string | has value |
| position_title_ar | "المالك / رئيس مجلس الإدارة" | string | has value |
| department_id | "e653f26f-f60d-46d9-8101-ab9580c57768" | string | has value |
| level_id | "1a1ac603-61ae-4e7c-bd13-a26e6f9acc79" | string | has value |
| is_active | true | boolean | has value |
| created_at | "2025-09-25T19:49:59.686096+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "eeaa430c-8613-4403-b1c2-45fde9842db5",
  "position_title_en": "Owner / Chairman",
  "position_title_ar": "المالك / رئيس مجلس الإدارة",
  "department_id": "e653f26f-f60d-46d9-8101-ab9580c57768",
  "level_id": "1a1ac603-61ae-4e7c-bd13-a26e6f9acc79",
  "is_active": true,
  "created_at": "2025-09-25T19:49:59.686096+00:00"
}
```

### `hr_salary_components`

*📋 Table exists but is currently empty*

### `hr_salary_wages`

*📋 Table exists but is currently empty*

## NON Tables

### `non_approved_payment_scheduler`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | 78 | number | has value |
| schedule_type | "multiple_bill" | string | has value |
| branch_id | 1 | number | has value |
| branch_name | "Urban Market (Abu Arish)" | string | has value |
| expense_category_id | 10 | number | has value |
| expense_category_name_en | "Staff Meals" | string | has value |
| expense_category_name_ar | "وجبات الموظفين" | string | has value |
| co_user_id | "133cc9e1-2720-4789-af8f-75516e702c1b" | string | has value |
| co_user_name | "Mansoor" | string | has value |
| bill_type | "vat_applicable" | string | has value |
| bill_number | "7323" | string | has value |
| bill_date | "2025-10-30" | string | has value |
| payment_method | "cash" | string | has value |
| due_date | "2025-10-30" | string | has value |
| credit_period | null | object | nullable |
| amount | 80.33 | number | has value |
| bill_file_url | "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/expense-scheduler-bills/1/1761817768504_bill1.pdf" | string | has value |
| bank_name | null | object | nullable |
| iban | null | object | nullable |
| description | "MAINTENANCE TOOLS FOR MESS TABLE" | string | has value |
| notes | null | object | nullable |
| recurring_type | null | object | nullable |
| recurring_metadata | null | object | nullable |
| approver_id | "ee47e425-0a10-40c3-aa7d-268efd4264a2" | string | has value |
| approver_name | "Sadham" | string | has value |
| approval_status | "rejected" | string | has value |
| approved_at | null | object | nullable |
| approved_by | null | object | nullable |
| rejection_reason | null | object | nullable |
| expense_scheduler_id | null | object | nullable |
| created_by | "bc3d6349-8237-407a-aeef-96dab9d51adf" | string | has value |
| created_at | "2025-10-30T09:49:30.53531+00:00" | string | has value |
| updated_by | null | object | nullable |
| updated_at | "2025-10-30T10:15:33.371999+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": 78,
  "schedule_type": "multiple_bill",
  "branch_id": 1,
  "branch_name": "Urban Market (Abu Arish)",
  "expense_category_id": 10,
  "expense_category_name_en": "Staff Meals",
  "expense_category_name_ar": "وجبات الموظفين",
  "co_user_id": "133cc9e1-2720-4789-af8f-75516e702c1b",
  "co_user_name": "Mansoor",
  "bill_type": "vat_applicable",
  "bill_number": "7323",
  "bill_date": "2025-10-30",
  "payment_method": "cash",
  "due_date": "2025-10-30",
  "credit_period": null,
  "amount": 80.33,
  "bill_file_url": "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/expense-scheduler-bills/1/1761817768504_bill1.pdf",
  "bank_name": null,
  "iban": null,
  "description": "MAINTENANCE TOOLS FOR MESS TABLE",
  "notes": null,
  "recurring_type": null,
  "recurring_metadata": null,
  "approver_id": "ee47e425-0a10-40c3-aa7d-268efd4264a2",
  "approver_name": "Sadham",
  "approval_status": "rejected",
  "approved_at": null,
  "approved_by": null,
  "rejection_reason": null,
  "expense_scheduler_id": null,
  "created_by": "bc3d6349-8237-407a-aeef-96dab9d51adf",
  "created_at": "2025-10-30T09:49:30.53531+00:00",
  "updated_by": null,
  "updated_at": "2025-10-30T10:15:33.371999+00:00"
}
```

## NOTIFICATION Tables

### `notification_attachments`

*📋 Table exists but is currently empty*

### `notification_queue`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "45862fff-aeb1-4e0d-af1c-ed78bbdbcc07" | string | has value |
| notification_id | "b2dd21ff-8935-437a-8162-653bc22a7395" | string | has value |
| user_id | "b658eca1-3cc1-48b2-bd3c-33b81fab5a0f" | string | has value |
| device_id | "1761826981752-db7bdaiua" | string | has value |
| push_subscription_id | "d9ad10be-9e34-4868-8446-2a19fcaba5a0" | string | has value |
| status | "sent" | string | has value |
| payload | [object Object] | object | has value |
| scheduled_at | "2025-10-30T13:27:11.286788+00:00" | string | has value |
| sent_at | "2025-10-30T13:28:01.776+00:00" | string | has value |
| delivered_at | null | object | nullable |
| error_message | null | object | nullable |
| retry_count | 0 | number | has value |
| max_retries | 3 | number | has value |
| created_at | "2025-10-30T13:27:11.286788+00:00" | string | has value |
| updated_at | "2025-10-30T13:28:01.794082+00:00" | string | has value |
| next_retry_at | null | object | nullable |
| last_attempt_at | "2025-10-30T13:28:01.109+00:00" | string | has value |
| renotification_at | null | object | nullable |
| notification_priority | "normal" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "45862fff-aeb1-4e0d-af1c-ed78bbdbcc07",
  "notification_id": "b2dd21ff-8935-437a-8162-653bc22a7395",
  "user_id": "b658eca1-3cc1-48b2-bd3c-33b81fab5a0f",
  "device_id": "1761826981752-db7bdaiua",
  "push_subscription_id": "d9ad10be-9e34-4868-8446-2a19fcaba5a0",
  "status": "sent",
  "payload": {
    "body": "TEST 1",
    "data": {
      "url": "/mobile",
      "type": "info",
      "recipientId": "1467dc64-5f96-4f11-b83c-58849bd1796e",
      "notificationId": "b2dd21ff-8935-437a-8162-653bc22a7395"
    },
    "icon": "/favicon.ico",
    "badge": "/favicon.ico",
    "title": "TEST 1"
  },
  "scheduled_at": "2025-10-30T13:27:11.286788+00:00",
  "sent_at": "2025-10-30T13:28:01.776+00:00",
  "delivered_at": null,
  "error_message": null,
  "retry_count": 0,
  "max_retries": 3,
  "created_at": "2025-10-30T13:27:11.286788+00:00",
  "updated_at": "2025-10-30T13:28:01.794082+00:00",
  "next_retry_at": null,
  "last_attempt_at": "2025-10-30T13:28:01.109+00:00",
  "renotification_at": null,
  "notification_priority": "normal"
}
```

### `notification_read_states`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "a77cda9a-24d4-48f5-af25-74e8d9a5c318" | string | has value |
| notification_id | "1ffcb299-3d1f-4609-856f-fa5dcb71b11e" | string | has value |
| user_id | "yousafali" | string | has value |
| read_at | "2025-10-30T12:34:42.795399+00:00" | string | has value |
| created_at | "2025-10-30T12:34:42.795399+00:00" | string | has value |
| is_read | false | boolean | has value |

**Sample Data Structure:**
```json
{
  "id": "a77cda9a-24d4-48f5-af25-74e8d9a5c318",
  "notification_id": "1ffcb299-3d1f-4609-856f-fa5dcb71b11e",
  "user_id": "yousafali",
  "read_at": "2025-10-30T12:34:42.795399+00:00",
  "created_at": "2025-10-30T12:34:42.795399+00:00",
  "is_read": false
}
```

### `notification_recipients`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "a58994f0-577c-4b60-a89d-36f69e214062" | string | has value |
| notification_id | "1ffcb299-3d1f-4609-856f-fa5dcb71b11e" | string | has value |
| role | null | object | nullable |
| branch_id | null | object | nullable |
| is_read | false | boolean | has value |
| read_at | null | object | nullable |
| is_dismissed | false | boolean | has value |
| dismissed_at | null | object | nullable |
| created_at | "2025-10-30T12:34:42.795399+00:00" | string | has value |
| updated_at | "2025-10-30T12:52:15.555012+00:00" | string | has value |
| delivery_status | "delivered" | string | has value |
| delivery_attempted_at | "2025-10-30T12:52:15.54+00:00" | string | has value |
| error_message | null | object | nullable |
| user_id | "b658eca1-3cc1-48b2-bd3c-33b81fab5a0f" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "a58994f0-577c-4b60-a89d-36f69e214062",
  "notification_id": "1ffcb299-3d1f-4609-856f-fa5dcb71b11e",
  "role": null,
  "branch_id": null,
  "is_read": false,
  "read_at": null,
  "is_dismissed": false,
  "dismissed_at": null,
  "created_at": "2025-10-30T12:34:42.795399+00:00",
  "updated_at": "2025-10-30T12:52:15.555012+00:00",
  "delivery_status": "delivered",
  "delivery_attempted_at": "2025-10-30T12:52:15.54+00:00",
  "error_message": null,
  "user_id": "b658eca1-3cc1-48b2-bd3c-33b81fab5a0f"
}
```

## NOTIFICATIONS Tables

### `notifications`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "1ffcb299-3d1f-4609-856f-fa5dcb71b11e" | string | has value |
| title | "test" | string | has value |
| message | "test" | string | has value |
| created_by | "shamsu" | string | has value |
| created_by_name | "shamsu" | string | has value |
| created_by_role | "Admin" | string | has value |
| target_users | b658eca1-3cc1-48b2-bd3c-33b81fab5a0f | object | has value |
| target_roles | null | object | nullable |
| target_branches | null | object | nullable |
| scheduled_for | null | object | nullable |
| sent_at | "2025-10-30T12:34:42.795399+00:00" | string | has value |
| expires_at | null | object | nullable |
| has_attachments | false | boolean | has value |
| read_count | 0 | number | has value |
| total_recipients | 0 | number | has value |
| created_at | "2025-10-30T12:34:42.795399+00:00" | string | has value |
| updated_at | "2025-10-30T12:34:42.795399+00:00" | string | has value |
| deleted_at | null | object | nullable |
| metadata | null | object | nullable |
| task_id | null | object | nullable |
| task_assignment_id | null | object | nullable |
| priority | "medium" | string | has value |
| status | "published" | string | has value |
| target_type | "specific_users" | string | has value |
| type | "info" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "1ffcb299-3d1f-4609-856f-fa5dcb71b11e",
  "title": "test",
  "message": "test",
  "created_by": "shamsu",
  "created_by_name": "shamsu",
  "created_by_role": "Admin",
  "target_users": [
    "b658eca1-3cc1-48b2-bd3c-33b81fab5a0f"
  ],
  "target_roles": null,
  "target_branches": null,
  "scheduled_for": null,
  "sent_at": "2025-10-30T12:34:42.795399+00:00",
  "expires_at": null,
  "has_attachments": false,
  "read_count": 0,
  "total_recipients": 0,
  "created_at": "2025-10-30T12:34:42.795399+00:00",
  "updated_at": "2025-10-30T12:34:42.795399+00:00",
  "deleted_at": null,
  "metadata": null,
  "task_id": null,
  "task_assignment_id": null,
  "priority": "medium",
  "status": "published",
  "target_type": "specific_users",
  "type": "info"
}
```

## POSITION Tables

### `position_roles_view`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| role_id | "491c4ba1-064b-4143-b635-09756d8df0bb" | string | has value |
| role_name | "Admin" | string | has value |
| role_code | "ADMIN" | string | has value |
| role_description | "Administrative access with most permissions" | string | has value |
| is_system_role | true | boolean | has value |
| position_id | null | object | nullable |
| position_title_en | null | object | nullable |
| position_title_ar | null | object | nullable |
| department_id | null | object | nullable |
| department_name_en | null | object | nullable |
| department_name_ar | null | object | nullable |
| level_id | null | object | nullable |
| level_name_en | null | object | nullable |
| level_name_ar | null | object | nullable |
| level_order | null | object | nullable |

**Sample Data Structure:**
```json
{
  "role_id": "491c4ba1-064b-4143-b635-09756d8df0bb",
  "role_name": "Admin",
  "role_code": "ADMIN",
  "role_description": "Administrative access with most permissions",
  "is_system_role": true,
  "position_id": null,
  "position_title_en": null,
  "position_title_ar": null,
  "department_id": null,
  "department_name_en": null,
  "department_name_ar": null,
  "level_id": null,
  "level_name_en": null,
  "level_name_ar": null,
  "level_order": null
}
```

## PUSH Tables

### `push_subscriptions`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "8e1076ae-fab3-4229-ab61-06a3e6d79f65" | string | has value |
| user_id | "807af948-0f5f-4f36-8925-747b152513c1" | string | has value |
| device_id | "1761849385334-4ema1wflv" | string | has value |
| endpoint | "https://web.push.apple.com/QK0pu64kG-oRlF7gCWQjmywV6ZdNl-y6kt2sGZulAGTUIn_qmSs-N79nGVgDtXrudal75oHCr06VIW98nOstAj5m32d-uZ8xq5uyjLeuI73rQrGL2c3MbmMEvG-kWs00VGI75yUpG_QEwNUP-PERASPH2IFL0x8aYDAs7sZdH3E" | string | has value |
| p256dh | "BNqkJSCgyVFyRbONzmedpDHvakiMBa4plZYaFwes7gOyXOwiUZhE5cHPKuOwr6Y4G+Co8ioQqBiJUOKI4r1mTVs=" | string | has value |
| auth | "mR4zZ4Iv6NVHH6Vjfo1QEg==" | string | has value |
| device_type | "mobile" | string | has value |
| browser_name | "Safari" | string | has value |
| user_agent | "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1" | string | has value |
| is_active | true | boolean | has value |
| last_seen | "2025-10-30T18:36:54.715+00:00" | string | has value |
| created_at | "2025-10-30T18:36:35.698345+00:00" | string | has value |
| updated_at | "2025-10-30T18:36:54.981677+00:00" | string | has value |
| session_id | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "8e1076ae-fab3-4229-ab61-06a3e6d79f65",
  "user_id": "807af948-0f5f-4f36-8925-747b152513c1",
  "device_id": "1761849385334-4ema1wflv",
  "endpoint": "https://web.push.apple.com/QK0pu64kG-oRlF7gCWQjmywV6ZdNl-y6kt2sGZulAGTUIn_qmSs-N79nGVgDtXrudal75oHCr06VIW98nOstAj5m32d-uZ8xq5uyjLeuI73rQrGL2c3MbmMEvG-kWs00VGI75yUpG_QEwNUP-PERASPH2IFL0x8aYDAs7sZdH3E",
  "p256dh": "BNqkJSCgyVFyRbONzmedpDHvakiMBa4plZYaFwes7gOyXOwiUZhE5cHPKuOwr6Y4G+Co8ioQqBiJUOKI4r1mTVs=",
  "auth": "mR4zZ4Iv6NVHH6Vjfo1QEg==",
  "device_type": "mobile",
  "browser_name": "Safari",
  "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1",
  "is_active": true,
  "last_seen": "2025-10-30T18:36:54.715+00:00",
  "created_at": "2025-10-30T18:36:35.698345+00:00",
  "updated_at": "2025-10-30T18:36:54.981677+00:00",
  "session_id": null
}
```

## QUICK Tables

### `quick_task_assignments`

*📋 Table exists but is currently empty*

### `quick_task_comments`

*📋 Table exists but is currently empty*

### `quick_task_completion_details`

*📋 Table exists but is currently empty*

### `quick_task_completions`

*📋 Table exists but is currently empty*

### `quick_task_files`

*📋 Table exists but is currently empty*

### `quick_task_files_with_details`

*📋 Table exists but is currently empty*

### `quick_task_user_preferences`

*📋 Table exists but is currently empty*

### `quick_tasks`

*📋 Table exists but is currently empty*

### `quick_tasks_with_details`

*📋 Table exists but is currently empty*

## RECEIVING Tables

### `receiving_records`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "73e653c4-7fb6-4e1a-9655-add21fa33017" | string | has value |
| user_id | "6f883b06-13a8-476b-86ce-a7a79553a4bd" | string | has value |
| branch_id | 3 | number | has value |
| vendor_id | 2238 | number | has value |
| bill_date | "2025-10-23" | string | has value |
| bill_amount | 496.5 | number | has value |
| bill_number | "25171704006127" | string | has value |
| payment_method | "Cash on Delivery" | string | has value |
| credit_period | null | object | nullable |
| due_date | "2025-10-23" | string | has value |
| bank_name | "N/A" | string | has value |
| iban | "N/A" | string | has value |
| vendor_vat_number | "300917305600003" | string | has value |
| bill_vat_number | "300917305600003" | string | has value |
| vat_numbers_match | true | boolean | has value |
| vat_mismatch_reason | null | object | nullable |
| branch_manager_user_id | "590601e9-af35-4ccb-9d80-323268e847bd" | string | has value |
| shelf_stocker_user_ids | 31eb78e3-bf56-40dd-8f23-52b9c525167c | object | has value |
| accountant_user_id | "9fe9e217-6953-4d0f-99dd-a8fd8bfded9d" | string | has value |
| purchasing_manager_user_id | "807af948-0f5f-4f36-8925-747b152513c1" | string | has value |
| expired_return_amount | 0 | number | has value |
| near_expiry_return_amount | 0 | number | has value |
| over_stock_return_amount | 0 | number | has value |
| damage_return_amount | 0 | number | has value |
| total_return_amount | 0 | number | has value |
| final_bill_amount | 496.5 | number | has value |
| expired_erp_document_type | null | object | nullable |
| expired_erp_document_number | null | object | nullable |
| expired_vendor_document_number | null | object | nullable |
| near_expiry_erp_document_type | null | object | nullable |
| near_expiry_erp_document_number | null | object | nullable |
| near_expiry_vendor_document_number | null | object | nullable |
| over_stock_erp_document_type | null | object | nullable |
| over_stock_erp_document_number | null | object | nullable |
| over_stock_vendor_document_number | null | object | nullable |
| damage_erp_document_type | null | object | nullable |
| damage_erp_document_number | null | object | nullable |
| damage_vendor_document_number | null | object | nullable |
| has_expired_returns | false | boolean | has value |
| has_near_expiry_returns | false | boolean | has value |
| has_over_stock_returns | false | boolean | has value |
| has_damage_returns | false | boolean | has value |
| created_at | "2025-10-23T06:55:09.616814+00:00" | string | has value |
| inventory_manager_user_id | "6f883b06-13a8-476b-86ce-a7a79553a4bd" | string | has value |
| night_supervisor_user_ids | efa4aedd-867f-4223-b9e6-220375892c2d | object | has value |
| warehouse_handler_user_ids | 62b05d1a-57b8-4481-a071-3de2386bf46a | object | has value |
| certificate_url | "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/clearance-certificates/clearance-certificate-73e653c4-7fb6-4e1a-9655-add21fa33017-1761202663033.png" | string | has value |
| certificate_generated_at | "2025-10-23T06:57:44.196+00:00" | string | has value |
| certificate_file_name | "clearance-certificate-73e653c4-7fb6-4e1a-9655-add21fa33017-1761202663033.png" | string | has value |
| original_bill_url | "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/original-bills/73e653c4-7fb6-4e1a-9655-add21fa33017_original_bill_1761205290081.pdf" | string | has value |
| erp_purchase_invoice_reference | "2128" | string | has value |
| updated_at | "2025-10-23T14:33:51.214935+00:00" | string | has value |
| pr_excel_file_url | "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/pr-excel-files/73e653c4-7fb6-4e1a-9655-add21fa33017_pr_excel_1761230138064.xlsx" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "73e653c4-7fb6-4e1a-9655-add21fa33017",
  "user_id": "6f883b06-13a8-476b-86ce-a7a79553a4bd",
  "branch_id": 3,
  "vendor_id": 2238,
  "bill_date": "2025-10-23",
  "bill_amount": 496.5,
  "bill_number": "25171704006127",
  "payment_method": "Cash on Delivery",
  "credit_period": null,
  "due_date": "2025-10-23",
  "bank_name": "N/A",
  "iban": "N/A",
  "vendor_vat_number": "300917305600003",
  "bill_vat_number": "300917305600003",
  "vat_numbers_match": true,
  "vat_mismatch_reason": null,
  "branch_manager_user_id": "590601e9-af35-4ccb-9d80-323268e847bd",
  "shelf_stocker_user_ids": [
    "31eb78e3-bf56-40dd-8f23-52b9c525167c"
  ],
  "accountant_user_id": "9fe9e217-6953-4d0f-99dd-a8fd8bfded9d",
  "purchasing_manager_user_id": "807af948-0f5f-4f36-8925-747b152513c1",
  "expired_return_amount": 0,
  "near_expiry_return_amount": 0,
  "over_stock_return_amount": 0,
  "damage_return_amount": 0,
  "total_return_amount": 0,
  "final_bill_amount": 496.5,
  "expired_erp_document_type": null,
  "expired_erp_document_number": null,
  "expired_vendor_document_number": null,
  "near_expiry_erp_document_type": null,
  "near_expiry_erp_document_number": null,
  "near_expiry_vendor_document_number": null,
  "over_stock_erp_document_type": null,
  "over_stock_erp_document_number": null,
  "over_stock_vendor_document_number": null,
  "damage_erp_document_type": null,
  "damage_erp_document_number": null,
  "damage_vendor_document_number": null,
  "has_expired_returns": false,
  "has_near_expiry_returns": false,
  "has_over_stock_returns": false,
  "has_damage_returns": false,
  "created_at": "2025-10-23T06:55:09.616814+00:00",
  "inventory_manager_user_id": "6f883b06-13a8-476b-86ce-a7a79553a4bd",
  "night_supervisor_user_ids": [
    "efa4aedd-867f-4223-b9e6-220375892c2d"
  ],
  "warehouse_handler_user_ids": [
    "62b05d1a-57b8-4481-a071-3de2386bf46a"
  ],
  "certificate_url": "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/clearance-certificates/clearance-certificate-73e653c4-7fb6-4e1a-9655-add21fa33017-1761202663033.png",
  "certificate_generated_at": "2025-10-23T06:57:44.196+00:00",
  "certificate_file_name": "clearance-certificate-73e653c4-7fb6-4e1a-9655-add21fa33017-1761202663033.png",
  "original_bill_url": "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/original-bills/73e653c4-7fb6-4e1a-9655-add21fa33017_original_bill_1761205290081.pdf",
  "erp_purchase_invoice_reference": "2128",
  "updated_at": "2025-10-23T14:33:51.214935+00:00",
  "pr_excel_file_url": "https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/pr-excel-files/73e653c4-7fb6-4e1a-9655-add21fa33017_pr_excel_1761230138064.xlsx"
}
```

### `receiving_records_pr_excel_status`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "51a460d7-eb38-479b-8fe6-860c3ff05c7b" | string | has value |
| bill_number | "12345" | string | has value |
| vendor_id | 1187 | number | has value |
| vendor_name | "-EMDAD مؤسسة امداد الجنوبيه للتجارة (قهوة الدلة)" | string | has value |
| pr_excel_file_url | null | object | nullable |
| pr_excel_status | "Not Uploaded" | string | has value |
| updated_at | "2025-10-30T15:40:53.550507+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "51a460d7-eb38-479b-8fe6-860c3ff05c7b",
  "bill_number": "12345",
  "vendor_id": 1187,
  "vendor_name": "-EMDAD مؤسسة امداد الجنوبيه للتجارة (قهوة الدلة)",
  "pr_excel_file_url": null,
  "pr_excel_status": "Not Uploaded",
  "updated_at": "2025-10-30T15:40:53.550507+00:00"
}
```

### `receiving_tasks`

*📋 Table exists but is currently empty*

## RECURRING Tables

### `recurring_assignment_schedules`

*📋 Table exists but is currently empty*

### `recurring_schedule_check_log`

*📋 Table exists but is currently empty*

## REQUESTERS Tables

### `requesters`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "f32355ab-6ec7-4256-bbdf-f2c289579601" | string | has value |
| requester_id | "2563482849" | string | has value |
| requester_name | "yousuf" | string | has value |
| contact_number | "966548357066" | string | has value |
| created_at | "2025-10-28T12:32:03.554777+00:00" | string | has value |
| updated_at | "2025-10-28T12:32:03.554777+00:00" | string | has value |
| created_by | "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b" | string | has value |
| updated_by | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "f32355ab-6ec7-4256-bbdf-f2c289579601",
  "requester_id": "2563482849",
  "requester_name": "yousuf",
  "contact_number": "966548357066",
  "created_at": "2025-10-28T12:32:03.554777+00:00",
  "updated_at": "2025-10-28T12:32:03.554777+00:00",
  "created_by": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
  "updated_by": null
}
```

## ROLE Tables

### `role_permissions`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "c122f3ca-7dc5-4606-bde2-3ac84e53e2cd" | string | has value |
| role_id | "a47e6277-c9fd-4e0e-a72a-a6b7c3d69401" | string | has value |
| function_id | "50baa859-a220-4749-8e93-b49649896de1" | string | has value |
| can_view | true | boolean | has value |
| can_add | true | boolean | has value |
| can_edit | true | boolean | has value |
| can_delete | true | boolean | has value |
| can_export | true | boolean | has value |
| created_at | "2025-09-27T09:58:52.545712+00:00" | string | has value |
| updated_at | "2025-09-27T09:58:52.545712+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "c122f3ca-7dc5-4606-bde2-3ac84e53e2cd",
  "role_id": "a47e6277-c9fd-4e0e-a72a-a6b7c3d69401",
  "function_id": "50baa859-a220-4749-8e93-b49649896de1",
  "can_view": true,
  "can_add": true,
  "can_edit": true,
  "can_delete": true,
  "can_export": true,
  "created_at": "2025-09-27T09:58:52.545712+00:00",
  "updated_at": "2025-09-27T09:58:52.545712+00:00"
}
```

## TASK Tables

### `task_assignments`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "5c60618b-c0c3-4b0c-a148-c2d1a2e588c0" | string | has value |
| task_id | "c866b9d5-d6bc-4e4f-9663-42e49b353393" | string | has value |
| assignment_type | "individual" | string | has value |
| assigned_to_user_id | "bc3d6349-8237-407a-aeef-96dab9d51adf" | string | has value |
| assigned_to_branch_id | null | object | nullable |
| assigned_by | "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b" | string | has value |
| assigned_by_name | "madmin" | string | has value |
| assigned_at | "2025-10-27T07:52:06.334338+00:00" | string | has value |
| status | "completed" | string | has value |
| started_at | null | object | nullable |
| completed_at | "2025-10-30T08:31:40.184569+00:00" | string | has value |
| schedule_date | null | object | nullable |
| schedule_time | null | object | nullable |
| deadline_date | null | object | nullable |
| deadline_time | null | object | nullable |
| deadline_datetime | null | object | nullable |
| is_reassignable | true | boolean | has value |
| is_recurring | false | boolean | has value |
| recurring_pattern | null | object | nullable |
| notes | null | object | nullable |
| priority_override | null | object | nullable |
| require_task_finished | false | boolean | has value |
| require_photo_upload | false | boolean | has value |
| require_erp_reference | false | boolean | has value |
| reassigned_from | null | object | nullable |
| reassignment_reason | null | object | nullable |
| reassigned_at | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "5c60618b-c0c3-4b0c-a148-c2d1a2e588c0",
  "task_id": "c866b9d5-d6bc-4e4f-9663-42e49b353393",
  "assignment_type": "individual",
  "assigned_to_user_id": "bc3d6349-8237-407a-aeef-96dab9d51adf",
  "assigned_to_branch_id": null,
  "assigned_by": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
  "assigned_by_name": "madmin",
  "assigned_at": "2025-10-27T07:52:06.334338+00:00",
  "status": "completed",
  "started_at": null,
  "completed_at": "2025-10-30T08:31:40.184569+00:00",
  "schedule_date": null,
  "schedule_time": null,
  "deadline_date": null,
  "deadline_time": null,
  "deadline_datetime": null,
  "is_reassignable": true,
  "is_recurring": false,
  "recurring_pattern": null,
  "notes": null,
  "priority_override": null,
  "require_task_finished": false,
  "require_photo_upload": false,
  "require_erp_reference": false,
  "reassigned_from": null,
  "reassignment_reason": null,
  "reassigned_at": null
}
```

### `task_attachments`

*📋 Table exists but is currently empty*

### `task_completion_summary`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| completion_id | "7f94e41e-64fb-433d-89a8-f8cd14e7aea6" | string | has value |
| task_id | "db84f1eb-f9de-4fc4-a152-34b65e4c0f06" | string | has value |
| task_title | "New Delivery Arrived – Confirm Product is Placed" | string | has value |
| task_priority | "high" | string | has value |
| assignment_id | "5fc32a30-f570-4778-89aa-d47e72885c22" | string | has value |
| completed_by | "efa4aedd-867f-4223-b9e6-220375892c2d" | string | has value |
| completed_by_name | "Noorudheen" | string | has value |
| completed_by_branch_id | null | object | nullable |
| branch_name | null | object | nullable |
| task_finished_completed | true | boolean | has value |
| photo_uploaded_completed | null | object | nullable |
| completion_photo_url | null | object | nullable |
| erp_reference_completed | null | object | nullable |
| erp_reference_number | null | object | nullable |
| completion_notes | null | object | nullable |
| verified_by | null | object | nullable |
| verified_at | null | object | nullable |
| verification_notes | null | object | nullable |
| completed_at | "2025-10-30T21:45:47.374+00:00" | string | has value |
| completion_percentage | 33.33 | number | has value |
| is_fully_completed | null | object | nullable |

**Sample Data Structure:**
```json
{
  "completion_id": "7f94e41e-64fb-433d-89a8-f8cd14e7aea6",
  "task_id": "db84f1eb-f9de-4fc4-a152-34b65e4c0f06",
  "task_title": "New Delivery Arrived – Confirm Product is Placed",
  "task_priority": "high",
  "assignment_id": "5fc32a30-f570-4778-89aa-d47e72885c22",
  "completed_by": "efa4aedd-867f-4223-b9e6-220375892c2d",
  "completed_by_name": "Noorudheen",
  "completed_by_branch_id": null,
  "branch_name": null,
  "task_finished_completed": true,
  "photo_uploaded_completed": null,
  "completion_photo_url": null,
  "erp_reference_completed": null,
  "erp_reference_number": null,
  "completion_notes": null,
  "verified_by": null,
  "verified_at": null,
  "verification_notes": null,
  "completed_at": "2025-10-30T21:45:47.374+00:00",
  "completion_percentage": 33.33,
  "is_fully_completed": null
}
```

### `task_completions`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "221ea5d3-3669-445b-ab33-b440fc1a04ce" | string | has value |
| task_id | "be796afd-5cef-44a6-be84-022e82d2f7e3" | string | has value |
| assignment_id | "67cbe741-402a-4dd6-b6a5-af830a9c083b" | string | has value |
| completed_by | "31eb78e3-bf56-40dd-8f23-52b9c525167c" | string | has value |
| completed_by_name | "Shareef" | string | has value |
| completed_by_branch_id | null | object | nullable |
| task_finished_completed | true | boolean | has value |
| photo_uploaded_completed | null | object | nullable |
| erp_reference_completed | null | object | nullable |
| erp_reference_number | null | object | nullable |
| completion_notes | null | object | nullable |
| verified_by | null | object | nullable |
| verified_at | null | object | nullable |
| verification_notes | null | object | nullable |
| completed_at | "2025-10-24T13:06:40.516+00:00" | string | has value |
| created_at | "2025-10-24T13:06:41.200778+00:00" | string | has value |
| completion_photo_url | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "221ea5d3-3669-445b-ab33-b440fc1a04ce",
  "task_id": "be796afd-5cef-44a6-be84-022e82d2f7e3",
  "assignment_id": "67cbe741-402a-4dd6-b6a5-af830a9c083b",
  "completed_by": "31eb78e3-bf56-40dd-8f23-52b9c525167c",
  "completed_by_name": "Shareef",
  "completed_by_branch_id": null,
  "task_finished_completed": true,
  "photo_uploaded_completed": null,
  "erp_reference_completed": null,
  "erp_reference_number": null,
  "completion_notes": null,
  "verified_by": null,
  "verified_at": null,
  "verification_notes": null,
  "completed_at": "2025-10-24T13:06:40.516+00:00",
  "created_at": "2025-10-24T13:06:41.200778+00:00",
  "completion_photo_url": null
}
```

### `task_images`

*📋 Table exists but is currently empty*

## TASKS Tables

### `tasks`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "ffd6a936-dce8-41b3-afe3-bf56ac4d0cd4" | string | has value |
| title | "New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill" | string | has value |
| description | "🧾 Task for Accountant

Process payment and documentation for this receiving record.

Branch: Urban Market (Araidah)
Vendor: لوزين-LUSIN TC (ID: 2273)
Bill Amount: 800.80
Bill Number: 930221506685
Received Date: 2025-10-28
Received By: Hisham
Deadline: 2025-10-29 07:06:19 (24 hours from assignment)

Tasks Required:
1. Enter payment details into Purchase ERP system
2. Upload original bill document
3. Update ERP reference number
4. Confirm task completion in system

Clearance Certificate: https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/clearance-certificates/clearance-certificate-4e0e5d32-f98f-45af-876c-5ca7d007a871-1761635242300.png" | string | has value |
| require_task_finished | false | boolean | has value |
| require_photo_upload | false | boolean | has value |
| require_erp_reference | false | boolean | has value |
| can_escalate | false | boolean | has value |
| can_reassign | false | boolean | has value |
| created_by | "6f883b06-13a8-476b-86ce-a7a79553a4bd" | string | has value |
| created_by_name | "Hisham" | string | has value |
| created_by_role | "Position-based" | string | has value |
| status | "pending" | string | has value |
| priority | "high" | string | has value |
| created_at | "2025-10-28T07:06:19.163543+00:00" | string | has value |
| updated_at | "2025-10-28T07:06:19.163543+00:00" | string | has value |
| deleted_at | null | object | nullable |
| due_date | null | object | nullable |
| due_time | null | object | nullable |
| due_datetime | "2025-10-29T07:06:19.163543+00:00" | string | has value |
| search_vector | "'-10':43,50 '-28':44 '-29':51 '/storage/v1/object/public/clearance-certificates/clearance-certificate-4e0e5d32-f98f-45af-876c-5ca7d007a871-1761635242300.png':89 '06':53 '07':52 '1':61 '19':54 '2':69 '2025':42,49 '2273':33 '24':55 '3':74 '4':79 '800.80':36 '930221506685':39 'account':14 'amount':35 'araidah':26 'arriv':3 'assign':58 'bill':11,34,37,72 'branch':23 'certif':86 'clearanc':85 'complet':82 'confirm':80 'date':41 'deadlin':48 'deliveri':2 'detail':64 'document':18,73 'enter':4,62 'erp':7,67,76 'hisham':47 'hour':56 'id':32 'lusin':30 'market':25 'new':1 'number':38,78 'origin':10,71 'payment':16,63 'process':15 'purchas':6,66 'receiv':21,40,45 'record':22 'refer':77 'requir':60 'system':68,84 'task':12,59,81 'tc':31 'updat':75 'upload':9,70 'urban':24 'vendor':27 'vmypotfsyrvuublyddyt.supabase.co':88 'vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/clearance-certificates/clearance-certificate-4e0e5d32-f98f-45af-876c-5ca7d007a871-1761635242300.png':87 'لوزين':29 'لوزين-lusin':28" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "ffd6a936-dce8-41b3-afe3-bf56ac4d0cd4",
  "title": "New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill",
  "description": "🧾 Task for Accountant\r\n\r\nProcess payment and documentation for this receiving record.\r\n\r\nBranch: Urban Market (Araidah)\r\nVendor: لوزين-LUSIN TC (ID: 2273)\r\nBill Amount: 800.80\r\nBill Number: 930221506685\r\nReceived Date: 2025-10-28\r\nReceived By: Hisham\r\nDeadline: 2025-10-29 07:06:19 (24 hours from assignment)\r\n\r\nTasks Required:\r\n1. Enter payment details into Purchase ERP system\r\n2. Upload original bill document\r\n3. Update ERP reference number\r\n4. Confirm task completion in system\r\n\r\nClearance Certificate: https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/clearance-certificates/clearance-certificate-4e0e5d32-f98f-45af-876c-5ca7d007a871-1761635242300.png",
  "require_task_finished": false,
  "require_photo_upload": false,
  "require_erp_reference": false,
  "can_escalate": false,
  "can_reassign": false,
  "created_by": "6f883b06-13a8-476b-86ce-a7a79553a4bd",
  "created_by_name": "Hisham",
  "created_by_role": "Position-based",
  "status": "pending",
  "priority": "high",
  "created_at": "2025-10-28T07:06:19.163543+00:00",
  "updated_at": "2025-10-28T07:06:19.163543+00:00",
  "deleted_at": null,
  "due_date": null,
  "due_time": null,
  "due_datetime": "2025-10-29T07:06:19.163543+00:00",
  "search_vector": "'-10':43,50 '-28':44 '-29':51 '/storage/v1/object/public/clearance-certificates/clearance-certificate-4e0e5d32-f98f-45af-876c-5ca7d007a871-1761635242300.png':89 '06':53 '07':52 '1':61 '19':54 '2':69 '2025':42,49 '2273':33 '24':55 '3':74 '4':79 '800.80':36 '930221506685':39 'account':14 'amount':35 'araidah':26 'arriv':3 'assign':58 'bill':11,34,37,72 'branch':23 'certif':86 'clearanc':85 'complet':82 'confirm':80 'date':41 'deadlin':48 'deliveri':2 'detail':64 'document':18,73 'enter':4,62 'erp':7,67,76 'hisham':47 'hour':56 'id':32 'lusin':30 'market':25 'new':1 'number':38,78 'origin':10,71 'payment':16,63 'process':15 'purchas':6,66 'receiv':21,40,45 'record':22 'refer':77 'requir':60 'system':68,84 'task':12,59,81 'tc':31 'updat':75 'upload':9,70 'urban':24 'vendor':27 'vmypotfsyrvuublyddyt.supabase.co':88 'vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/clearance-certificates/clearance-certificate-4e0e5d32-f98f-45af-876c-5ca7d007a871-1761635242300.png':87 'لوزين':29 'لوزين-lusin':28"
}
```

## USER Tables

### `user_audit_logs`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "784d7f7b-b31d-4543-97d3-86cb597a8cfb" | string | has value |
| user_id | "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b" | string | has value |
| target_user_id | null | object | nullable |
| action | "logout" | string | has value |
| table_name | null | object | nullable |
| record_id | null | object | nullable |
| old_values | null | object | nullable |
| new_values | null | object | nullable |
| ip_address | null | object | nullable |
| user_agent | "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36" | string | has value |
| performed_by | null | object | nullable |
| created_at | "2025-10-09T15:39:12.89428+00:00" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "784d7f7b-b31d-4543-97d3-86cb597a8cfb",
  "user_id": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
  "target_user_id": null,
  "action": "logout",
  "table_name": null,
  "record_id": null,
  "old_values": null,
  "new_values": null,
  "ip_address": null,
  "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36",
  "performed_by": null,
  "created_at": "2025-10-09T15:39:12.89428+00:00"
}
```

### `user_device_sessions`

*📋 Table exists but is currently empty*

### `user_management_view`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "32eea432-7212-404a-b419-4c7a7aabe443" | string | has value |
| username | "Abbas" | string | has value |
| user_type | "branch_specific" | string | has value |
| status | "active" | string | has value |
| role_type | "Position-based" | string | has value |
| is_first_login | true | boolean | has value |
| last_login | "2025-10-29T15:27:34.464+00:00" | string | has value |
| failed_login_attempts | 0 | number | has value |
| created_at | "2025-10-11T14:19:16.914032+00:00" | string | has value |
| updated_at | "2025-10-29T15:27:36.2409+00:00" | string | has value |
| avatar | null | object | nullable |
| employee_id | "d739bb0b-2840-4c0f-87ca-f3404b59ed50" | string | has value |
| employee_code | "20" | string | has value |
| employee_name | "ABBAS" | string | has value |
| employee_status | "active" | string | has value |
| hire_date | null | object | nullable |
| branch_id | 3 | number | has value |
| branch_name | "Urban Market (Araidah)" | string | has value |
| branch_name_ar | "ايربن ماركت (العارضة)" | string | has value |
| branch_location_en | "Al-Aridhah" | string | has value |
| branch_location_ar | "العارضة" | string | has value |
| branch_active | true | boolean | has value |
| position_id | "172d87af-6224-455b-9c7c-741761ec4ac3" | string | has value |
| position_title_en | "Shelf Stockers" | string | has value |
| position_title_ar | "عمال تخزين الرفوف" | string | has value |
| department_id | "a24f9bb5-4269-40df-87f3-23ddfa83fadb" | string | has value |
| department_name_en | "Store Staff" | string | has value |
| department_name_ar | "موظفو المتجر" | string | has value |

**Sample Data Structure:**
```json
{
  "id": "32eea432-7212-404a-b419-4c7a7aabe443",
  "username": "Abbas",
  "user_type": "branch_specific",
  "status": "active",
  "role_type": "Position-based",
  "is_first_login": true,
  "last_login": "2025-10-29T15:27:34.464+00:00",
  "failed_login_attempts": 0,
  "created_at": "2025-10-11T14:19:16.914032+00:00",
  "updated_at": "2025-10-29T15:27:36.2409+00:00",
  "avatar": null,
  "employee_id": "d739bb0b-2840-4c0f-87ca-f3404b59ed50",
  "employee_code": "20",
  "employee_name": "ABBAS",
  "employee_status": "active",
  "hire_date": null,
  "branch_id": 3,
  "branch_name": "Urban Market (Araidah)",
  "branch_name_ar": "ايربن ماركت (العارضة)",
  "branch_location_en": "Al-Aridhah",
  "branch_location_ar": "العارضة",
  "branch_active": true,
  "position_id": "172d87af-6224-455b-9c7c-741761ec4ac3",
  "position_title_en": "Shelf Stockers",
  "position_title_ar": "عمال تخزين الرفوف",
  "department_id": "a24f9bb5-4269-40df-87f3-23ddfa83fadb",
  "department_name_en": "Store Staff",
  "department_name_ar": "موظفو المتجر"
}
```

### `user_password_history`

*📋 Table exists but is currently empty*

### `user_permissions_view`

*📋 Table exists but is currently empty*

### `user_roles`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "5f68055e-4b02-4e9b-87d2-fc3cf59d3120" | string | has value |
| role_name | "Owner / Chairman" | string | has value |
| role_code | "OWNER___CHAIRMAN" | string | has value |
| description | "Access level for Owner / Chairman position" | string | has value |
| is_system_role | false | boolean | has value |
| is_active | true | boolean | has value |
| created_at | "2025-09-27T09:58:52.545712+00:00" | string | has value |
| updated_at | "2025-09-27T09:58:52.545712+00:00" | string | has value |
| created_by | null | object | nullable |
| updated_by | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "5f68055e-4b02-4e9b-87d2-fc3cf59d3120",
  "role_name": "Owner / Chairman",
  "role_code": "OWNER___CHAIRMAN",
  "description": "Access level for Owner / Chairman position",
  "is_system_role": false,
  "is_active": true,
  "created_at": "2025-09-27T09:58:52.545712+00:00",
  "updated_at": "2025-09-27T09:58:52.545712+00:00",
  "created_by": null,
  "updated_by": null
}
```

### `user_sessions`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "5799967f-6e7e-49eb-98d1-7888df98fef4" | string | has value |
| user_id | "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b" | string | has value |
| session_token | "aqura_1760024379256_rzwuveqn9lb" | string | has value |
| login_method | "quick_access" | string | has value |
| ip_address | null | object | nullable |
| user_agent | null | object | nullable |
| is_active | true | boolean | has value |
| expires_at | "2025-10-09T23:39:39.256+00:00" | string | has value |
| created_at | "2025-10-09T15:39:39.056445+00:00" | string | has value |
| ended_at | null | object | nullable |

**Sample Data Structure:**
```json
{
  "id": "5799967f-6e7e-49eb-98d1-7888df98fef4",
  "user_id": "e1fdaee2-97f0-4fc1-872f-9d99c6bd684b",
  "session_token": "aqura_1760024379256_rzwuveqn9lb",
  "login_method": "quick_access",
  "ip_address": null,
  "user_agent": null,
  "is_active": true,
  "expires_at": "2025-10-09T23:39:39.256+00:00",
  "created_at": "2025-10-09T15:39:39.056445+00:00",
  "ended_at": null
}
```

## USERS Tables

### `users`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "efa4aedd-867f-4223-b9e6-220375892c2d" | string | has value |
| username | "Noorudheen" | string | has value |
| password_hash | "$2a$08$Z4PU0hbeI9UWghtlqI9O1OJhGaRU50glDkIcd6vf6lW6iFia021G6" | string | has value |
| salt | "$2a$08$Z4PU0hbeI9UWghtlqI9O1O" | string | has value |
| quick_access_code | "148661" | string | has value |
| quick_access_salt | "$2a$08$WYwIe2tuApx3gxQkBDhvx.Tv7OxjnbpnAcaen7lIwoDOidGvKBTnW" | string | has value |
| user_type | "branch_specific" | string | has value |
| employee_id | "f0bd7ba5-e783-4700-8a40-458d981e9d5b" | string | has value |
| branch_id | 3 | number | has value |
| role_type | "Position-based" | string | has value |
| position_id | "a27a28e1-a99d-4d10-bb9f-931cbcd30c11" | string | has value |
| avatar | null | object | nullable |
| avatar_small_url | null | object | nullable |
| avatar_medium_url | null | object | nullable |
| avatar_large_url | null | object | nullable |
| is_first_login | true | boolean | has value |
| failed_login_attempts | 0 | number | has value |
| locked_at | null | object | nullable |
| locked_by | null | object | nullable |
| last_login_at | "2025-10-30T08:57:37.578+00:00" | string | has value |
| password_expires_at | "2026-01-05T07:16:33.560558+00:00" | string | has value |
| last_password_change | "2025-10-07T07:16:33.560558+00:00" | string | has value |
| created_by | null | object | nullable |
| updated_by | null | object | nullable |
| created_at | "2025-10-07T07:16:33.560558+00:00" | string | has value |
| updated_at | "2025-10-30T08:57:36.629337+00:00" | string | has value |
| status | "active" | string | has value |
| ai_translation_enabled | false | boolean | has value |
| can_approve_payments | false | boolean | has value |
| approval_amount_limit | 0 | number | has value |

**Sample Data Structure:**
```json
{
  "id": "efa4aedd-867f-4223-b9e6-220375892c2d",
  "username": "Noorudheen",
  "password_hash": "$2a$08$Z4PU0hbeI9UWghtlqI9O1OJhGaRU50glDkIcd6vf6lW6iFia021G6",
  "salt": "$2a$08$Z4PU0hbeI9UWghtlqI9O1O",
  "quick_access_code": "148661",
  "quick_access_salt": "$2a$08$WYwIe2tuApx3gxQkBDhvx.Tv7OxjnbpnAcaen7lIwoDOidGvKBTnW",
  "user_type": "branch_specific",
  "employee_id": "f0bd7ba5-e783-4700-8a40-458d981e9d5b",
  "branch_id": 3,
  "role_type": "Position-based",
  "position_id": "a27a28e1-a99d-4d10-bb9f-931cbcd30c11",
  "avatar": null,
  "avatar_small_url": null,
  "avatar_medium_url": null,
  "avatar_large_url": null,
  "is_first_login": true,
  "failed_login_attempts": 0,
  "locked_at": null,
  "locked_by": null,
  "last_login_at": "2025-10-30T08:57:37.578+00:00",
  "password_expires_at": "2026-01-05T07:16:33.560558+00:00",
  "last_password_change": "2025-10-07T07:16:33.560558+00:00",
  "created_by": null,
  "updated_by": null,
  "created_at": "2025-10-07T07:16:33.560558+00:00",
  "updated_at": "2025-10-30T08:57:36.629337+00:00",
  "status": "active",
  "ai_translation_enabled": false,
  "can_approve_payments": false,
  "approval_amount_limit": 0
}
```

## VENDOR Tables

### `vendor_payment_schedule`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| id | "a1f5706f-6065-4676-96c5-bfb2a42f6368" | string | has value |
| receiving_record_id | null | object | nullable |
| bill_number | "1862" | string | has value |
| vendor_id | "2309" | string | has value |
| vendor_name | "شركة الصافي دانون المحدودة SAFI TC" | string | has value |
| branch_id | 3 | number | has value |
| branch_name | "Urban Market (Araidah)" | string | has value |
| bill_date | "2025-09-18" | string | has value |
| bill_amount | 490.45 | number | has value |
| final_bill_amount | 490.45 | number | has value |
| payment_method | "Cash Credit" | string | has value |
| bank_name | "" | string | has value |
| iban | "" | string | has value |
| due_date | "2025-10-18" | string | has value |
| credit_period | 30 | number | has value |
| vat_number | "300048685510003" | string | has value |
| scheduled_date | "2025-10-27T17:49:17.502" | string | has value |
| paid_date | null | object | nullable |
| notes | "Manually created on 10/27/2025" | string | has value |
| created_at | "2025-10-27T17:49:18.57419" | string | has value |
| updated_at | "2025-10-27T17:49:18.57419" | string | has value |
| original_due_date | null | object | nullable |
| original_bill_amount | null | object | nullable |
| original_final_amount | null | object | nullable |
| is_paid | false | boolean | has value |
| payment_reference | null | object | nullable |
| task_id | null | object | nullable |
| task_assignment_id | null | object | nullable |
| receiver_user_id | null | object | nullable |
| accountant_user_id | null | object | nullable |
| verification_status | "pending" | string | has value |
| verified_by | null | object | nullable |
| verified_date | null | object | nullable |
| transaction_date | null | object | nullable |
| original_bill_url | null | object | nullable |
| created_by | null | object | nullable |
| pr_excel_verified | false | boolean | has value |
| pr_excel_verified_by | null | object | nullable |
| pr_excel_verified_date | null | object | nullable |
| discount_amount | 0 | number | has value |
| discount_notes | null | object | nullable |
| grr_amount | 0 | number | has value |
| grr_reference_number | null | object | nullable |
| grr_notes | null | object | nullable |
| pri_amount | 0 | number | has value |
| pri_reference_number | null | object | nullable |
| pri_notes | null | object | nullable |
| last_adjustment_date | null | object | nullable |
| last_adjusted_by | null | object | nullable |
| adjustment_history |  | object | has value |

**Sample Data Structure:**
```json
{
  "id": "a1f5706f-6065-4676-96c5-bfb2a42f6368",
  "receiving_record_id": null,
  "bill_number": "1862",
  "vendor_id": "2309",
  "vendor_name": "شركة الصافي دانون المحدودة SAFI TC",
  "branch_id": 3,
  "branch_name": "Urban Market (Araidah)",
  "bill_date": "2025-09-18",
  "bill_amount": 490.45,
  "final_bill_amount": 490.45,
  "payment_method": "Cash Credit",
  "bank_name": "",
  "iban": "",
  "due_date": "2025-10-18",
  "credit_period": 30,
  "vat_number": "300048685510003",
  "scheduled_date": "2025-10-27T17:49:17.502",
  "paid_date": null,
  "notes": "Manually created on 10/27/2025",
  "created_at": "2025-10-27T17:49:18.57419",
  "updated_at": "2025-10-27T17:49:18.57419",
  "original_due_date": null,
  "original_bill_amount": null,
  "original_final_amount": null,
  "is_paid": false,
  "payment_reference": null,
  "task_id": null,
  "task_assignment_id": null,
  "receiver_user_id": null,
  "accountant_user_id": null,
  "verification_status": "pending",
  "verified_by": null,
  "verified_date": null,
  "transaction_date": null,
  "original_bill_url": null,
  "created_by": null,
  "pr_excel_verified": false,
  "pr_excel_verified_by": null,
  "pr_excel_verified_date": null,
  "discount_amount": 0,
  "discount_notes": null,
  "grr_amount": 0,
  "grr_reference_number": null,
  "grr_notes": null,
  "pri_amount": 0,
  "pri_reference_number": null,
  "pri_notes": null,
  "last_adjustment_date": null,
  "last_adjusted_by": null,
  "adjustment_history": []
}
```

## VENDORS Tables

### `vendors`

**Columns:**

| Column | Sample Value | Type | Notes |
|--------|-------------|------|-------|
| erp_vendor_id | 1298 | number | has value |
| vendor_name | "ABNA UMAR SAID BAFEEL AL MAHDOODA شركة ابناء عمر سعيد بافيل المحدودة" | string | has value |
| salesman_name | "N/A" | string | has value |
| salesman_contact | "N/A" | string | has value |
| supervisor_name | "N/A" | string | has value |
| supervisor_contact | "N/A" | string | has value |
| vendor_contact_number | "N/A" | string | has value |
| payment_method | "N/A" | string | has value |
| credit_period | null | object | nullable |
| bank_name | "N/A" | string | has value |
| iban | "N/A" | string | has value |
| status | "Active" | string | has value |
| last_visit | null | object | nullable |
| categories | null | object | nullable |
| delivery_modes | null | object | nullable |
| place | null | object | nullable |
| location_link | null | object | nullable |
| return_expired_products | null | object | nullable |
| return_expired_products_note | null | object | nullable |
| return_near_expiry_products | null | object | nullable |
| return_near_expiry_products_note | null | object | nullable |
| return_over_stock | null | object | nullable |
| return_over_stock_note | null | object | nullable |
| return_damage_products | null | object | nullable |
| return_damage_products_note | null | object | nullable |
| no_return | false | boolean | has value |
| no_return_note | null | object | nullable |
| vat_applicable | "VAT Applicable" | string | has value |
| vat_number | null | object | nullable |
| no_vat_note | null | object | nullable |
| created_at | "2025-10-20T14:01:59.906092" | string | has value |
| updated_at | "2025-10-20T14:01:59.906092" | string | has value |
| branch_id | 2 | number | has value |
| payment_priority | "Normal" | string | has value |

**Sample Data Structure:**
```json
{
  "erp_vendor_id": 1298,
  "vendor_name": "ABNA UMAR SAID BAFEEL AL MAHDOODA شركة ابناء عمر سعيد بافيل المحدودة",
  "salesman_name": "N/A",
  "salesman_contact": "N/A",
  "supervisor_name": "N/A",
  "supervisor_contact": "N/A",
  "vendor_contact_number": "N/A",
  "payment_method": "N/A",
  "credit_period": null,
  "bank_name": "N/A",
  "iban": "N/A",
  "status": "Active",
  "last_visit": null,
  "categories": null,
  "delivery_modes": null,
  "place": null,
  "location_link": null,
  "return_expired_products": null,
  "return_expired_products_note": null,
  "return_near_expiry_products": null,
  "return_near_expiry_products_note": null,
  "return_over_stock": null,
  "return_over_stock_note": null,
  "return_damage_products": null,
  "return_damage_products_note": null,
  "no_return": false,
  "no_return_note": null,
  "vat_applicable": "VAT Applicable",
  "vat_number": null,
  "no_vat_note": null,
  "created_at": "2025-10-20T14:01:59.906092",
  "updated_at": "2025-10-20T14:01:59.906092",
  "branch_id": 2,
  "payment_priority": "Normal"
}
```

## Storage Buckets

### `employee-documents`

- **ID**: employee-documents
- **Public**: Yes
- **Created**: 2025-09-27T06:44:19.983Z
- **Updated**: 2025-09-27T06:44:19.983Z
- **File Count**: 0

### `user-avatars`

- **ID**: user-avatars
- **Public**: Yes
- **Created**: 2025-09-27T09:37:55.546Z
- **Updated**: 2025-09-27T09:37:55.546Z
- **File Count**: 0

### `documents`

- **ID**: documents
- **Public**: Yes
- **Created**: 2025-09-29T21:07:24.977Z
- **Updated**: 2025-09-29T21:07:24.977Z
- **File Count**: 0

### `original-bills`

- **ID**: original-bills
- **Public**: Yes
- **Created**: 2025-10-16T09:39:29.747Z
- **Updated**: 2025-10-16T09:39:29.747Z
- **File Count**: 1
- **Sample Files**: 
  - 00ad8cf8-cff4-4dc3-8d54-1cb5d5a90273_original_bill_1761570591589.pdf (256134)
  - 00cdf681-f02c-4b2e-b55f-935b67b3d207_original_bill_1761458249984.pdf (301223)
  - 01606783-122e-45d1-8abd-5e571f5a904f_original_bill_1760791212218.pdf (40894)
  - 04ae5d05-35a4-4bc5-ad89-9e17aa06eea3_original_bill_1761561461713.pdf (544761)
  - 04bc2c9f-5c7a-4d9c-8793-aeeca1ff2386_original_bill_1761545944729.pdf (173541)

### `vendor-contracts`

- **ID**: vendor-contracts
- **Public**: Yes
- **Created**: 2025-09-20T10:53:24.356Z
- **Updated**: 2025-09-20T10:53:24.356Z
- **File Count**: 0

### `pr-excel-files`

- **ID**: pr-excel-files
- **Public**: Yes
- **Created**: 2025-10-18T19:05:27.954Z
- **Updated**: 2025-10-18T19:05:27.954Z
- **File Count**: 1
- **Sample Files**: 
  - 00ad8cf8-cff4-4dc3-8d54-1cb5d5a90273_pr_excel_1761577725969.xlsx (46789)
  - 00cdf681-f02c-4b2e-b55f-935b67b3d207_pr_excel_1761465354796.xlsx (40883)
  - 04ae5d05-35a4-4bc5-ad89-9e17aa06eea3_pr_excel_1761571631458.xlsx (39179)
  - 04bc2c9f-5c7a-4d9c-8793-aeeca1ff2386_pr_excel_1761569325036.xlsx (44176)
  - 05262d70-2dac-442a-9279-c4b8fe484c0b_pr_excel_1761395018752.xlsx (45452)

### `requisition-images`

- **ID**: requisition-images
- **Public**: Yes
- **Created**: 2025-10-26T15:56:44.886Z
- **Updated**: 2025-10-26T15:56:44.886Z
- **File Count**: 1
- **Sample Files**: 
  - REQ-20251026-1513.png (307390)
  - REQ-20251026-2059.png (310059)
  - REQ-20251026-3178.png (323437)
  - REQ-20251026-3751.png (309022)
  - REQ-20251026-7712.png (323312)

### `expense-scheduler-bills`

- **ID**: expense-scheduler-bills
- **Public**: No
- **Created**: 2025-10-27T17:17:54.351Z
- **Updated**: 2025-10-27T17:17:54.351Z
- **File Count**: 1
- **Sample Files**: 
  - 1 (unknown size)

### `notification-images`

- **ID**: notification-images
- **Public**: Yes
- **Created**: 2025-10-05T08:21:22.199Z
- **Updated**: 2025-10-05T08:21:22.199Z
- **File Count**: 1
- **Sample Files**: 
  - .emptyFolderPlaceholder (unknown size)

### `task-images`

- **ID**: task-images
- **Public**: Yes
- **Created**: 2025-09-29T21:07:24.977Z
- **Updated**: 2025-09-29T21:07:24.977Z
- **File Count**: 1
- **Sample Files**: 
  - .emptyFolderPlaceholder (unknown size)
  - file-1760096993793-3hwjv2x4jb.jpg (147698)
  - file-1760108062123-zb2xk6kzz6.png (2432793)

### `warning-documents`

- **ID**: warning-documents
- **Public**: Yes
- **Created**: 2025-10-30T17:22:56.189Z
- **Updated**: 2025-10-30T17:22:56.189Z
- **File Count**: 1
- **Sample Files**: 
  - 2025 (unknown size)

### `quick-task-files`

- **ID**: quick-task-files
- **Public**: Yes
- **Created**: 2025-10-06T11:32:05.112Z
- **Updated**: 2025-10-06T11:32:05.112Z
- **File Count**: 1
- **Sample Files**: 
  - .emptyFolderPlaceholder (unknown size)
  - quick-task-1760097684032-qkcnfyr8m6i.jpg (56605)
  - quick-task-1760101943817-q7jc3ravee.jpg (1111659)
  - quick-task-1760102796805-grxeo40pu2.jpg (4448020)
  - quick-task-1760107259037-52b0fc8rejr.png (2432793)

### `completion-photos`

- **ID**: completion-photos
- **Public**: Yes
- **Created**: 2025-09-29T21:07:24.977Z
- **Updated**: 2025-09-29T21:07:24.977Z
- **File Count**: 1
- **Sample Files**: 
  - quick-task-completion-0cef9d38-3cb3-4c77-a34a-6010bbae154d-1760186327172.jpg (2449215)
  - quick-task-completion-afad0b88-e458-47da-9e27-df949fd44d29-1760259874252.jpg (3900959)
  - quick-task-completion-bda0b915-b197-4d97-9789-9a5585f65102-1760112977141.png (9895)
  - quick-task-completion-e5ab6536-2ddf-4283-bf33-f9b7063c9e8b-1760260513385.jpg (3689866)
  - quick-task-completion-e5ab6536-2ddf-4283-bf33-f9b7063c9e8b-1760260636184.jpg (3689866)

### `clearance-certificates`

- **ID**: clearance-certificates
- **Public**: Yes
- **Created**: 2025-10-16T07:51:17.889Z
- **Updated**: 2025-10-16T07:51:17.889Z
- **File Count**: 1
- **Sample Files**: 
  - .emptyFolderPlaceholder (unknown size)
  - clearance-certificate-00441dfb-6fab-437f-9e12-57cabe1421b8-1761573566878.png (278418)
  - clearance-certificate-00ad8cf8-cff4-4dc3-8d54-1cb5d5a90273-1761558142473.png (283993)
  - clearance-certificate-00cdf681-f02c-4b2e-b55f-935b67b3d207-1761456664719.png (283491)
  - clearance-certificate-01606783-122e-45d1-8abd-5e571f5a904f-1760778531851.png (268810)

## Edge Functions

### `process-push-queue`

- **Path**: \supabase\functions\process-push-queue
- **Has Index**: Yes
- **Files**: index.ts

**Code Preview:**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import webpush from 'npm:web-push@3.6.6'

const VAPID_PUBLIC_KEY = "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIq...
```

### `send-push-notification`

- **Path**: \supabase\functions\send-push-notification
- **Has Index**: Yes
- **Files**: index.ts

**Code Preview:**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const VAPID_PUBLIC_KEY = "BExwv7hh64Fkg6RRzkzueFm8MQn0NkdtImUf5q2X1UUwLKyGw3RtLqgj-MixTecmRaePJSxNva9J0Y5CMZIqzS8"
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY') || "hCYjM5B0-NDNyZB7AjB--fe3G2SShDY4LClmhFCZry8"

...
```

### `test-queue`

- **Path**: \supabase\functions\test-queue
- **Has Index**: Yes
- **Files**: index.ts

**Code Preview:**
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_RO...
```


---

*This enhanced reference was automatically generated from the Aqura database schema on 2025-10-30T21:47:43.113Z and enhanced on 2025-10-30T21:49:42.479Z*
